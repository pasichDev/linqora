//go:build !windows && !linux && !darwin

package startup

import "errors"

var errNotSupported = errors.New("startup management is not supported on this platform")

func isSupported() bool            { return false }
func isEnabled() (bool, error)     { return false, errNotSupported }
func enable() error                { return errNotSupported }
func disable() error               { return errNotSupported }
func listEntries() ([]Entry, error) { return nil, errNotSupported }
func setEntry(_ string, _ bool) error { return errNotSupported }
