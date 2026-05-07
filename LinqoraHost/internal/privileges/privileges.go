package privileges

import (
	"os/exec"
	"os/user"
	"runtime"
	"strings"
)

// CheckAdminPrivileges determines if the process is running with elevated
// administrative rights (root on Unix, Administrator on Windows).
func CheckAdminPrivileges() bool {
	switch runtime.GOOS {
	case "linux", "darwin":
		// In Linux/macOS, we check if the current user ID is 0 (root).
		currentUser, err := user.Current()
		if err != nil {
			return false
		}
		return currentUser.Uid == "0"

	case "windows":
		// In Windows, we query the current identity's membership in the Administrator role.
		cmd := exec.Command("powershell", "-Command",
			"([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)")

		output, err := cmd.Output()
		if err != nil {
			return false
		}

		return strings.TrimSpace(string(output)) == "True"

	default:
		return false
	}
}

// CanExecuteSudo checks whether the current user has non-interactive sudo permissions.
func CanExecuteSudo() bool {
	if runtime.GOOS != "linux" && runtime.GOOS != "darwin" {
		return false
	}

	// If already running as root, sudo is not required.
	if CheckAdminPrivileges() {
		return true
	}

	// Check sudo accessibility without prompting for a password (-n flag).
	cmd := exec.Command("sudo", "-n", "true")
	err := cmd.Run()

	return err == nil
}
