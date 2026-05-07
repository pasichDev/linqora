package ws

import (
	"testing"
	"time"
)

func TestRateLimiterAllowsBurst(t *testing.T) {
	rl := newClientRateLimiter()

	// Should allow rateLimitBurst consecutive calls immediately.
	for i := 0; i < rateLimitBurst; i++ {
		if !rl.Allow() {
			t.Fatalf("Allow returned false at call %d (expected burst of %d)", i+1, rateLimitBurst)
		}
	}
}

func TestRateLimiterBlocksAfterBurst(t *testing.T) {
	rl := newClientRateLimiter()

	for i := 0; i < rateLimitBurst; i++ {
		rl.Allow()
	}

	if rl.Allow() {
		t.Fatal("Allow should return false when burst is exhausted")
	}
}

func TestRateLimiterRefillsOverTime(t *testing.T) {
	rl := newClientRateLimiter()

	// Drain the bucket.
	for i := 0; i < rateLimitBurst; i++ {
		rl.Allow()
	}

	// Wait long enough for at least 2 tokens to refill (rate is 30/s → ~33ms/token).
	rate := rateLimitPerSec // variable prevents constant-expression conversion error
	refillFor2 := time.Duration(2 * float64(time.Second) / rate)
	time.Sleep(refillFor2 + 10*time.Millisecond)

	if !rl.Allow() {
		t.Fatal("Allow should succeed after waiting for token refill")
	}
}
