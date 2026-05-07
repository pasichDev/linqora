package power

import (
	"os/exec"
	"strings"
)

func isPlatformSystemLocked() (bool, error) {
	cmd := exec.Command("bash", "-c",
		"/System/Library/PrivateFrameworks/login.framework/Versions/Current/Helpers/LoginUIBundle.login/Contents/MacOS/LoginUIBundle -status | grep 'CGSSessionScreenIsLocked = true'")
	output, err := cmd.Output()
	if err != nil {
		return false, err
	}
	return strings.TrimSpace(string(output)) != "", nil
}
