//go:build windows

package monitors

import (
	"fmt"
	"os/exec"
	"strconv"
)

var (
	procSendMessageBrt = user32.NewProc("SendMessageW")
)

const (
	wmSyscommand   = uintptr(0x0112)
	scMonitorpower = uintptr(0xF170)
	hwndBroadcast  = uintptr(0xFFFF)
	monitorOff     = uintptr(2)
)

func platformSleepDisplay() error {
	procSendMessageBrt.Call(hwndBroadcast, wmSyscommand, scMonitorpower, monitorOff)
	return nil
}

func platformWakeDisplay() error {
	procSendMessageBrt.Call(hwndBroadcast, wmSyscommand, scMonitorpower, ^uintptr(0))
	return nil
}

func platformSetBrightness(level int) error {
	if level < 0 || level > 100 {
		return fmt.Errorf("brightness: level %d out of range [0,100]", level)
	}
	script := fmt.Sprintf(
		`(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1,%s)`,
		strconv.Itoa(level),
	)
	out, err := exec.Command("powershell", "-NoProfile", "-Command", script).CombinedOutput()
	if err != nil {
		return fmt.Errorf("brightness: powershell: %w: %s", err, out)
	}
	return nil
}
