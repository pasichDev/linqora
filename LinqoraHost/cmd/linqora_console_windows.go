package main

import "syscall"

// hideConsole detaches the process from its console window so no black
// terminal appears when the app is launched by double-clicking the exe.
func hideConsole() {
	syscall.NewLazyDLL("kernel32.dll").NewProc("FreeConsole").Call()
}
