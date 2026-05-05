package auth

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"testing"
	"time"
)

func TestChallengeStoreGenerateAndVerify(t *testing.T) {
	cs := NewChallengeStore()
	const deviceID = "device-abc"
	const secret = "super-secret"

	token, err := cs.Generate(deviceID)
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}
	if len(token) != 64 { // 32 bytes hex-encoded
		t.Fatalf("expected 64-char token, got %d", len(token))
	}

	// Compute correct HMAC response.
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(token))
	response := hex.EncodeToString(mac.Sum(nil))

	if !cs.Verify(deviceID, token, response, secret) {
		t.Fatal("Verify should return true for correct HMAC")
	}
}

func TestChallengeStoreOneTimeUse(t *testing.T) {
	cs := NewChallengeStore()
	const deviceID = "device-xyz"
	const secret = "s3cr3t"

	token, _ := cs.Generate(deviceID)

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(token))
	response := hex.EncodeToString(mac.Sum(nil))

	cs.Verify(deviceID, token, response, secret) // consumes token

	if cs.Verify(deviceID, token, response, secret) {
		t.Fatal("second Verify should fail (token already consumed)")
	}
}

func TestChallengeStoreWrongHMAC(t *testing.T) {
	cs := NewChallengeStore()
	const deviceID = "device-123"

	token, _ := cs.Generate(deviceID)

	if cs.Verify(deviceID, token, "deadbeef", "secret") {
		t.Fatal("wrong HMAC should not verify")
	}
}

func TestChallengeStoreTTLExpiry(t *testing.T) {
	cs := NewChallengeStore()
	const deviceID = "device-ttl"
	const secret = "s"

	token, _ := cs.Generate(deviceID)

	// Manually expire the entry.
	cs.mu.Lock()
	entry := cs.challenges[deviceID]
	entry.expiresAt = time.Now().Add(-time.Second)
	cs.challenges[deviceID] = entry
	cs.mu.Unlock()

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(token))
	response := hex.EncodeToString(mac.Sum(nil))

	if cs.Verify(deviceID, token, response, secret) {
		t.Fatal("expired challenge should not verify")
	}
}
