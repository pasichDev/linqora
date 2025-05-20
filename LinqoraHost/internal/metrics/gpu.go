package metrics

import (
	"fmt"
	"io/ioutil"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
)

// GPUInfo содержит информацию о графическом процессоре
type GPUInfo struct {
	Model  string // Модель GPU
	Memory int    // Объем памяти в МБ
}

// GetGPUInfo возвращает информацию о GPU
func GetGPUInfo() (GPUInfo, error) {
	info := GPUInfo{
		Model:  "Unknown",
		Memory: 0,
	}

	switch runtime.GOOS {
	case "linux":
		// Пробуем получить информацию через nvidia-smi (для NVIDIA GPU)
		cmd := exec.Command("nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader")
		output, err := cmd.Output()
		if err == nil && len(output) > 0 {
			outputStr := string(output)
			parts := strings.Split(strings.TrimSpace(outputStr), ", ")
			if len(parts) >= 2 {
				info.Model = parts[0]
				memStr := strings.TrimSuffix(parts[1], " MiB")
				if mem, err := parseInt(memStr); err == nil {
					info.Memory = mem
				}
			}
		} else {
			// Проверяем наличие AMD/Intel GPU через lspci
			cmd := exec.Command("lspci", "-v")
			output, err := cmd.Output()
			if err == nil {
				outputStr := string(output)
				lines := strings.Split(outputStr, "\n")

				for _, line := range lines {
					if strings.Contains(line, "VGA") || strings.Contains(line, "3D controller") {
						if strings.Contains(line, "AMD") || strings.Contains(line, "ATI") {
							info.Model = extractAMDGPUModel(line)
							// Пытаемся получить память AMD GPU через файловую систему
							getAMDMemoryInfo(&info)
						} else if strings.Contains(line, "Intel") {
							info.Model = extractGPUModel(line)
							// Для Intel обычно сложно получить информацию о памяти через файлы
						} else {
							info.Model = extractGPUModel(line)
						}
						break
					}
				}
			}
		}

	case "windows":
		// Для Windows используем WMI запрос
		cmd := exec.Command("powershell", "-Command", "Get-WmiObject Win32_VideoController | Select-Object Name, AdapterRAM | Format-List")
		output, err := cmd.Output()
		if err == nil {
			outputStr := string(output)

			if nameLines := strings.Split(outputStr, "Name : "); len(nameLines) > 1 {
				info.Model = strings.TrimSpace(strings.Split(nameLines[1], "\n")[0])
			}

			if memLines := strings.Split(outputStr, "AdapterRAM : "); len(memLines) > 1 {
				memStr := strings.TrimSpace(strings.Split(memLines[1], "\n")[0])
				if memVal, err := strconv.ParseInt(memStr, 10, 64); err == nil {
					info.Memory = int(memVal / (1024 * 1024)) // Переводим в МБ
				}
			}
		}
	}

	return info, nil
}

// Получаем информацию о памяти AMD GPU
func getAMDMemoryInfo(info *GPUInfo) {
	cardPath := "/sys/class/drm/card0/device/"

	// Пытаемся прочитать объем памяти из файловой системы
	if memData, err := ioutil.ReadFile(cardPath + "mem_info_vram_total"); err == nil {
		memBytes, _ := strconv.ParseInt(strings.TrimSpace(string(memData)), 10, 64)
		info.Memory = int(memBytes / (1024 * 1024)) // Переводим байты в МБ
	}
}

// Улучшенный экстрактор модели AMD GPU
func extractAMDGPUModel(line string) string {
	parts := strings.Split(line, ": ")
	if len(parts) < 2 {
		return "Unknown AMD GPU"
	}

	model := parts[1]

	// Очищаем строку от лишних идентификаторов для лучшей читаемости
	model = strings.TrimPrefix(model, "Advanced Micro Devices, Inc. [AMD/ATI] ")
	model = strings.TrimPrefix(model, "Advanced Micro Devices [AMD/ATI] ")
	model = strings.TrimPrefix(model, "AMD ")

	// Проверяем наличие кодового имени архитектуры и добавляем маркетинговое название
	cardType := determineCardType()
	if cardType != "" {
		model = cardType
	}

	return model
}

// Определяет тип карты на основе строки модели
func determineCardType() string {
	// Пытаемся получить информацию из другого источника - более надежный метод
	cmd := exec.Command("glxinfo", "-B")
	output, err := cmd.Output()
	if err == nil {
		outputStr := string(output)

		// Проверяем строку с открытым драйвером Mesa
		if strings.Contains(outputStr, "Device: ") {
			deviceLines := strings.Split(outputStr, "Device: ")
			if len(deviceLines) > 1 {
				deviceName := strings.Split(deviceLines[1], " (")[0]
				if deviceName != "" {
					return deviceName
				}
			}
		}
	}

	return "" // Если не удалось определить маркетинговое название
}

// Вспомогательная функция для извлечения модели GPU
func extractGPUModel(line string) string {
	parts := strings.Split(line, ": ")
	if len(parts) < 2 {
		return "Unknown"
	}

	return parts[1]
}

// Вспомогательная функция для парсинга строки в int
func parseInt(s string) (int, error) {
	var result int
	_, err := fmt.Sscanf(s, "%d", &result)
	return result, err
}
