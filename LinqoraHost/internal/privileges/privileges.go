package privileges

import (
	"os/exec"
	"os/user"
	"runtime"
	"strings"
)

// Checks if is running with administrator rights (sudo/admin)
func CheckAdminPrivileges() bool {
	switch runtime.GOOS {
	case "linux", "darwin":
		// In Linux/macOS, we check if we are the root user (ID = 0)
		currentUser, err := user.Current()
		if err != nil {
			return false
		}
		return currentUser.Uid == "0"

	case "windows":
		// In Windows, run the PowerShell cmdlet to verify administrator privileges
		cmd := exec.Command("powershell", "-Command",
			"([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)")

		output, err := cmd.Output()
		if err != nil {
			return false
		}

		// If the command returns ‘True’, then we have administrator privileges
		return strings.TrimSpace(string(output)) == "True"

	default:
		return false
	}
}

// CanExecuteSudo checks whether the current user can execute commands with sudo
// This is useful for deciding whether to try to use sudo in commands
func CanExecuteSudo() bool {
	if runtime.GOOS != "linux" && runtime.GOOS != "darwin" {
		return false
	}

	// Если мы уже root, нам не нужен sudo
	if CheckAdminPrivileges() {
		return true
	}

	// Проверяем sudo без запроса пароля
	cmd := exec.Command("sudo", "-n", "true")
	err := cmd.Run()

	return err == nil
}
