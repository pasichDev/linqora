package ws

import (
	"sync"
	"time"
)

const (
	// rateLimitBurst is the maximum number of messages a client may send in a
	// short burst before the limiter kicks in. Sized for mouse move streams
	// (≈30 fps) plus concurrent control messages.
	rateLimitBurst = 60

	// rateLimitPerSec is the sustained token refill rate (messages per second).
	// 30 msg/s supports smooth mouse movement at ~30 fps.
	rateLimitPerSec = 30.0
)

// clientRateLimiter implements a token-bucket algorithm to restrict client message rates.
// It allows for short bursts while maintaining a consistent long-term average rate.
type clientRateLimiter struct {
	mu       sync.Mutex
	tokens   float64
	capacity float64
	// rate in tokens per nanosecond, derived from rateLimitPerSec.
	rate     float64
	lastTime time.Time
}

// newClientRateLimiter creates a new rate limiter with default burst and rate settings.
func newClientRateLimiter() *clientRateLimiter {
	return &clientRateLimiter{
		tokens:   rateLimitBurst,
		capacity: rateLimitBurst,
		rate:     rateLimitPerSec / float64(time.Second),
		lastTime: time.Now(),
	}
}

// Allow checks if a message should be permitted, consuming one token if available.
func (r *clientRateLimiter) Allow() bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	now := time.Now()
	elapsed := now.Sub(r.lastTime)
	r.lastTime = now

	r.tokens += float64(elapsed) * r.rate
	if r.tokens > r.capacity {
		r.tokens = r.capacity
	}

	if r.tokens < 1.0 {
		return false
	}
	r.tokens--
	return true
}
