//go:build !windows && !linux && !darwin

package clipboard

import "errors"

func platformGet() (string, error) { return "", errors.New("clipboard: unsupported platform") }
func platformSet(_ string) error   { return errors.New("clipboard: unsupported platform") }
