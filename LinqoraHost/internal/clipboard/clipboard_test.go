package clipboard

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestWatchDeduplication(t *testing.T) {
	calls := 0
	getter := func() (string, error) {
		calls++
		return "same", nil
	}

	ch := make(chan string, 4)
	ctx, cancel := context.WithTimeout(context.Background(), 150*time.Millisecond)
	defer cancel()

	watchWithGetter(ctx, 20*time.Millisecond, getter, ch)

	if len(ch) != 0 {
		t.Errorf("expected no emissions for unchanged clipboard, got %d", len(ch))
	}
}

func TestWatchEmitsChange(t *testing.T) {
	values := []string{"first", "first", "second"}
	i := 0
	getter := func() (string, error) {
		v := values[i]
		if i < len(values)-1 {
			i++
		}
		return v, nil
	}

	ch := make(chan string, 4)
	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer cancel()

	watchWithGetter(ctx, 20*time.Millisecond, getter, ch)

	if len(ch) != 1 {
		t.Fatalf("expected 1 emission, got %d", len(ch))
	}
	if got := <-ch; got != "second" {
		t.Errorf("expected \"second\", got %q", got)
	}
}

func TestWatchContextCancel(t *testing.T) {
	getter := func() (string, error) { return "x", nil }

	ch := make(chan string, 4)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	done := make(chan struct{})
	go func() {
		watchWithGetter(ctx, 10*time.Millisecond, getter, ch)
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(500 * time.Millisecond):
		t.Error("watchWithGetter did not stop after context cancel")
	}
}

func TestWatchSkipsErrors(t *testing.T) {
	call := 0
	getter := func() (string, error) {
		call++
		if call%2 == 0 {
			return "", errors.New("transient error")
		}
		return "text", nil
	}

	ch := make(chan string, 4)
	ctx, cancel := context.WithTimeout(context.Background(), 150*time.Millisecond)
	defer cancel()

	watchWithGetter(ctx, 20*time.Millisecond, getter, ch)

	if len(ch) != 0 {
		t.Errorf("expected no net changes (alternating error+same), got %d", len(ch))
	}
}
