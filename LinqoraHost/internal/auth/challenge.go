package auth

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"sync"
	"time"
)

const challengeTTL = 60 * time.Second

type challengeEntry struct {
	token     string
	expiresAt time.Time
}

// ChallengeStore holds one-time challenge tokens keyed by deviceID.
type ChallengeStore struct {
	mu         sync.Mutex
	challenges map[string]*challengeEntry
}

func NewChallengeStore() *ChallengeStore {
	return &ChallengeStore{
		challenges: make(map[string]*challengeEntry),
	}
}

// Generate creates a cryptographically random 32-byte challenge for deviceID
// and stores it with a TTL. Returns the hex-encoded token.
func (cs *ChallengeStore) Generate(deviceID string) (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("failed to generate challenge: %w", err)
	}
	token := hex.EncodeToString(b)

	cs.mu.Lock()
	cs.challenges[deviceID] = &challengeEntry{
		token:     token,
		expiresAt: time.Now().Add(challengeTTL),
	}
	cs.mu.Unlock()

	return token, nil
}

// Verify checks that a non-expired challenge for deviceID exists, that the
// provided token matches, and that HMAC-SHA256(token, secret) == response.
// Each challenge is consumed on the first Verify call (one-time use).
func (cs *ChallengeStore) Verify(deviceID, token, response, secret string) bool {
	cs.mu.Lock()
	entry, exists := cs.challenges[deviceID]
	if exists {
		delete(cs.challenges, deviceID)
	}
	cs.mu.Unlock()

	if !exists || time.Now().After(entry.expiresAt) || entry.token != token {
		return false
	}

	expected := computeHMAC(token, secret)
	return hmac.Equal([]byte(response), []byte(expected))
}

// computeHMAC returns hex-encoded HMAC-SHA256(message, key).
func computeHMAC(message, key string) string {
	mac := hmac.New(sha256.New, []byte(key))
	mac.Write([]byte(message))
	return hex.EncodeToString(mac.Sum(nil))
}
