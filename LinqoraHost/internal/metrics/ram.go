package metrics

import (
	"LinqoraHost/internal/privileges"
	"math"
	"os/exec"
	"runtime"
	"strconv"
	"strings"

	"github.com/shirou/gopsutil/mem"
)

type RamMetrics struct {
	Timestamp   string  `json:"timestamp"`
	Usage       float64 `json:"usage"`
	LoadPercent float64 `json:"loadPercent"`
}

type RAMInfo struct {
	Type      string  // Тип памяти (DDR3, DDR4, etc)
	Frequency int     // Частота в МГц
	Slots     int     // Количество слотов
	Used      float64 // Используемая память в ГБ
	Total     float64 // Общая память в ГБ
}

func GetRamMetrics() (RamMetrics, error) {

	v, _ramErr := mem.VirtualMemory()

	if _ramErr != nil {
		return RamMetrics{}, _ramErr
	}

	ram := RamMetrics{
		LoadPercent: math.Round(v.UsedPercent),
		Usage:       math.Round((float64(v.Used)/1_000_000_000)*100) / 100,
	}
	return ram, nil
}

// GetRAMInfo возвращает информацию об оперативной памяти
func GetRAMInfo() (RAMInfo, error) {
	info := RAMInfo{
		Type:      "Unknown",
		Frequency: 0,
		Slots:     0,
	}

	// Получаем использованную память
	v, err := mem.VirtualMemory()
	if err == nil {
		info.Used = math.Round((float64(v.Used)/1_000_000_000)*100) / 100
		info.Total = math.Round((float64(v.Total)/1_000_000_000)*100) / 100
	}

	// Платформо-зависимая реализация для получения дополнительной информации
	switch runtime.GOOS {
	case "linux":
		if privileges.CheckAdminPrivileges() || privileges.CanExecuteSudo() {
			cmdPrefix := ""
			if !privileges.CheckAdminPrivileges() {
				cmdPrefix = "sudo "
			}
			cmd := exec.Command(cmdPrefix+"dmidecode", "--type", "memory")
			output, err := cmd.Output()
			if err == nil {
				outputStr := string(output)

				// Ищем тип памяти (DDR3, DDR4, etc.)
				if strings.Contains(outputStr, "DDR4") {
					info.Type = "DDR4"
				} else if strings.Contains(outputStr, "DDR3") {
					info.Type = "DDR3"
				} else if strings.Contains(outputStr, "DDR5") {
					info.Type = "DDR5"
				}

				// Подсчитываем количество слотов
				info.Slots = strings.Count(outputStr, "Memory Device")

				// Ищем частоту
				freqLines := strings.Split(outputStr, "Speed: ")
				if len(freqLines) > 1 {
					freqStr := strings.Split(freqLines[1], " ")[0]
					freq, err := strconv.Atoi(freqStr)
					if err == nil {
						info.Frequency = freq
					}
				}
			}
		} else {
			// Используем альтернативные методы без привилегий
			// ... получение ограниченной информации
		}
	case "windows":
		// На Windows можно использовать PowerShell для получения информации
		cmd := exec.Command("powershell", "-Command", "Get-WmiObject -Class Win32_PhysicalMemory | Select-Object Speed, MemoryType, DeviceLocator | Format-List")
		output, err := cmd.Output()
		if err == nil {
			outputStr := string(output)

			// Получаем количество слотов
			info.Slots = strings.Count(outputStr, "DeviceLocator")

			// Получаем частоту из первого элемента
			freqLines := strings.Split(outputStr, "Speed : ")
			if len(freqLines) > 1 {
				freqStr := strings.TrimSpace(strings.Split(freqLines[1], "\n")[0])
				freq, err := strconv.Atoi(freqStr)
				if err == nil {
					info.Frequency = freq
				}
			}

			// Определяем тип памяти по MemoryType
			if strings.Contains(outputStr, "MemoryType : 24") {
				info.Type = "DDR3"
			} else if strings.Contains(outputStr, "MemoryType : 26") {
				info.Type = "DDR4"
			} else if strings.Contains(outputStr, "MemoryType : 28") {
				info.Type = "DDR5"
			}
		}
	}

	return info, nil
}
