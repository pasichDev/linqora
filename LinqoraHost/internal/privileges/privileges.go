package privileges

import (
	"os/exec"
	"os/user"
	"runtime"
	"strings"
)

// CheckAdminPrivileges проверяет, запущена ли программа с правами администратора (sudo/admin)
func CheckAdminPrivileges() bool {
	switch runtime.GOOS {
	case "linux", "darwin":
		// В Linux/macOS проверяем, являемся ли мы root пользователем (ID = 0)
		currentUser, err := user.Current()
		if err != nil {
			return false
		}

		// Uid = "0" означает root пользователя
		return currentUser.Uid == "0"

	case "windows":
		// В Windows запускаем PowerShell команду для проверки прав администратора
		cmd := exec.Command("powershell", "-Command",
			"([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)")

		output, err := cmd.Output()
		if err != nil {
			return false
		}

		// Если команда вернула "True", значит у нас права администратора
		return strings.TrimSpace(string(output)) == "True"

	default:
		return false
	}
}

// CanExecuteSudo проверяет, может ли текущий пользователь выполнять команды с sudo
// Это полезно для решения, стоит ли пытаться использовать sudo в командах
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
