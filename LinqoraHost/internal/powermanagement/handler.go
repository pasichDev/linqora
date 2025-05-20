package powermanagement

import (
	"fmt"
	"log"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"
)

// Добавляем глобальное состояние блокировки
var (
	deviceLocked     bool
	deviceLockedTime time.Time
	lockMutex        sync.RWMutex
)

type PowerCommand struct {
	Action Action `json:"action"` // Тип действия (выключение, перезагрузка, блокировка)
}

// StartLockStateMonitor запускает мониторинг состояния блокировки
func StartLockStateMonitor() {
	log.Println("Starting lock state monitoring...")

	go func() {
		for {
			// Проверяем текущее состояние блокировки
			if IsDeviceLocked() {
				// Если внутреннее состояние - заблокировано, проверяем системное
				systemLocked, err := IsSystemLocked()
				if err != nil {
					log.Printf("Error checking system lock state: %v", err)
				} else if !systemLocked {
					// Система разблокирована, обновляем внутреннее состояние
					log.Printf("System unlock detected, updating state")
					SetDeviceLocked(false)
				}
			}

			// Уменьшаем паузу между проверками до 5 секунд для более быстрого обнаружения разблокировки
			time.Sleep(5 * time.Second)
		}
	}()
}

// IsDeviceLocked проверяет, заблокировано ли устройство
func IsDeviceLocked() bool {
	lockMutex.RLock()
	defer lockMutex.RUnlock()
	return deviceLocked
}

// SetDeviceLocked устанавливает состояние блокировки устройства
func SetDeviceLocked(locked bool) {
	lockMutex.Lock()
	defer lockMutex.Unlock()
	deviceLocked = locked
	if locked {
		deviceLockedTime = time.Now()
	}
}

// GetLockTime возвращает время, когда устройство было заблокировано
func GetLockTime() time.Time {
	lockMutex.RLock()
	defer lockMutex.RUnlock()
	return deviceLockedTime
}

// IsSystemLocked проверяет, заблокирована ли система на уровне ОС
func IsSystemLocked() (bool, error) {
	switch runtime.GOOS {
	case "windows":
		return isWindowsLocked()
	case "linux":
		return isLinuxLocked()
	case "darwin":
		return isMacOSLocked()
	default:
		return false, fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
	}
}

// Проверка блокировки в Windows
func isWindowsLocked() (bool, error) {
	// Пытаемся определить блокировку через запрос состояния сессии
	cmd := exec.Command("powershell", "-Command",
		"(Get-Process -Name LogonUI -ErrorAction SilentlyContinue) -ne $null")
	output, err := cmd.Output()
	if err != nil {
		return false, err
	}

	return strings.TrimSpace(string(output)) == "True", nil
}

// Исправленная функция проверки блокировки в Linux
func isLinuxLocked() (bool, error) {
	log.Println("Checking Linux lock state...")

	// Для GNOME
	if _, err := exec.LookPath("gnome-screensaver-command"); err == nil {
		cmd := exec.Command("gnome-screensaver-command", "--query")
		output, err := cmd.Output()
		if err == nil {
			log.Printf("gnome-screensaver-command output: %s", string(output))
			if strings.Contains(string(output), "active") {
				return true, nil
			}
			return false, nil
		}
		log.Printf("gnome-screensaver-command error: %v", err)
	}

	// Получаем текущую сессию пользователя
	if _, err := exec.LookPath("loginctl"); err == nil {
		// Сначала получаем ID сессии
		sessionCmd := exec.Command("bash", "-c", "loginctl | grep $(whoami) | awk '{print $1}'")
		sessionID, err := sessionCmd.Output()
		if err == nil && len(sessionID) > 0 {
			// Теперь проверяем состояние блокировки для этой сессии
			id := strings.TrimSpace(string(sessionID))
			cmd := exec.Command("loginctl", "show-session", id, "--property=LockedHint")
			output, err := cmd.Output()
			if err == nil {
				log.Printf("loginctl lock check output: %s", string(output))
				if strings.Contains(string(output), "LockedHint=yes") {
					return true, nil
				}
				return false, nil
			}
			log.Printf("loginctl error: %v", err)
		}
	}

	// Альтернативный способ проверки блокировки через dbus
	if _, err := exec.LookPath("dbus-send"); err == nil {
		cmd := exec.Command("bash", "-c",
			"dbus-send --session --dest=org.gnome.ScreenSaver --type=method_call --print-reply "+
				"/org/gnome/ScreenSaver org.gnome.ScreenSaver.GetActive | grep 'boolean true'")
		if err := cmd.Run(); err == nil {
			// Если команда выполнилась без ошибок и нашла 'boolean true', экран заблокирован
			return true, nil
		}
		// Если команда выполнилась с ошибкой или не нашла 'boolean true', экран не заблокирован
		return false, nil
	}

	// Общий метод для многих DE через xdg-screensaver status
	if _, err := exec.LookPath("xdg-screensaver"); err == nil {
		cmd := exec.Command("xdg-screensaver", "status")
		output, err := cmd.Output()
		if err == nil {
			log.Printf("xdg-screensaver output: %s", string(output))
			return strings.Contains(string(output), "on"), nil
		}
	}

	// Если все методы проверки не сработали, выводим отладочную информацию
	log.Println("All lock check methods failed, falling back to internal state")
	return IsDeviceLocked(), nil
}

// Проверка блокировки в macOS
func isMacOSLocked() (bool, error) {
	cmd := exec.Command("bash", "-c",
		"/System/Library/PrivateFrameworks/login.framework/Versions/Current/Helpers/LoginUIBundle.login/Contents/MacOS/LoginUIBundle -status | grep 'CGSSessionScreenIsLocked = true'")

	output, err := cmd.Output()
	if err != nil {
		return false, err
	}

	return strings.TrimSpace(string(output)) != "", nil
}

// Action представляет тип действия с питанием
type Action int

const (
	// Shutdown - выключение компьютера
	Shutdown Action = iota
	// Restart - перезагрузка компьютера
	Restart
	// Lock - блокировка экрана
	Lock
)

// ExecutePowerAction выполняет действие управления питанием
func ExecutePowerAction(action Action) error {
	// Для действия блокировки мы не проверяем, заблокирована ли система
	if action != Lock {
		// Проверяем состояние блокировки
		locked, err := IsSystemLocked()
		if err != nil {
			log.Printf("Warning: Failed to check system lock state: %v", err)
			// Используем наше внутреннее состояние
			locked = IsDeviceLocked()
		}

		if locked {
			return fmt.Errorf("device is locked, power action %d not permitted", action)
		}
	}

	switch runtime.GOOS {
	case "windows":
		return executeWindowsAction(action)
	case "linux":
		return executeLinuxAction(action)
	case "darwin":
		return executeMacOSAction(action)
	default:
		return fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
	}
}

// executeWindowsAction выполняет команду управления питанием в Windows
func executeWindowsAction(action Action) error {
	var cmd *exec.Cmd

	switch action {
	case Shutdown:
		cmd = exec.Command("shutdown", "/s", "/t", "0")
	case Restart:
		cmd = exec.Command("shutdown", "/r", "/t", "0")
	case Lock:
		cmd = exec.Command("rundll32.exe", "user32.dll,LockWorkStation")
	default:
		return fmt.Errorf("unknown power action: %d", action)
	}

	log.Printf("Executing Windows power command: %v", cmd.Args)
	return cmd.Run()
}

// executeLinuxAction выполняет команду управления питанием в Linux
func executeLinuxAction(action Action) error {
	var cmd *exec.Cmd

	switch action {
	case Shutdown:
		cmd = exec.Command("systemctl", "poweroff")
	case Restart:
		cmd = exec.Command("systemctl", "reboot")
	case Lock:
		// Пробуем несколько вариантов блокировки экрана для разных DE
		// Для GNOME
		if _, err := exec.LookPath("gnome-screensaver-command"); err == nil {
			cmd = exec.Command("gnome-screensaver-command", "--lock")
		} else if _, err := exec.LookPath("loginctl"); err == nil {
			// Для systemd
			cmd = exec.Command("loginctl", "lock-session")
		} else if _, err := exec.LookPath("xdg-screensaver"); err == nil {
			// Общий метод для многих DE
			cmd = exec.Command("xdg-screensaver", "lock")
		} else {
			return fmt.Errorf("no suitable screen lock command found")
		}
	default:
		return fmt.Errorf("unknown power action: %d", action)
	}

	log.Printf("Executing Linux power command: %v", cmd.Args)
	return cmd.Run()
}

// executeMacOSAction выполняет команду управления питанием в macOS
func executeMacOSAction(action Action) error {
	var cmd *exec.Cmd

	switch action {
	case Shutdown:
		cmd = exec.Command("osascript", "-e", "tell app \"System Events\" to shut down")
	case Restart:
		cmd = exec.Command("osascript", "-e", "tell app \"System Events\" to restart")
	case Lock:
		cmd = exec.Command("osascript", "-e", "tell application \"System Events\" to keystroke \"q\" using {command down, control down}")
	default:
		return fmt.Errorf("unknown power action: %d", action)
	}

	log.Printf("Executing macOS power command: %v", cmd.Args)
	return cmd.Run()
}
