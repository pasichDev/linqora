//go:build !windows && !linux && !darwin

package keyboard

import "errors"

func platformHandleKey(_ KeyCommand) error {
	return errors.New("keyboard: unsupported platform")
}

func platformTypeText(_ string) error {
	return errors.New("keyboard: TypeText not supported on this platform")
}
