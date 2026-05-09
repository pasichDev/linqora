//go:build !windows && !linux && !darwin

package monitors

import "errors"

func platformSleepDisplay() error              { return errors.New("brightness: unsupported platform") }
func platformWakeDisplay() error               { return errors.New("brightness: unsupported platform") }
func platformSetBrightness(_ int) error        { return errors.New("brightness: unsupported platform") }
