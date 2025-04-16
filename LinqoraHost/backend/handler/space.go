package handler

import (
	sysModel "LinqoraHost/backend/model"
	"fmt"
	"math"
	"path/filepath"
	"strings"

	"github.com/jaypipes/ghw"
	"github.com/shirou/gopsutil/disk"
)

// extractDiskBaseName витягує базову назву диску з повного імені пристрою.
// Для NVMe (наприклад: nvme0n1p1 → nvme0n1) функція відкидає номер розділу.
// Для інших дисків (наприклад: sda1 → sda) функція залишає лише ім'я диска без номера розділу.
// Параметри:
//   - device: повне ім'я пристрою (наприклад, "/dev/sda1").
//
// Повертає:
//   - базове ім'я пристрою (наприклад, "sda" або "nvme0n1").
func extractDiskBaseName(device string) string {
	base := filepath.Base(device)

	// Для NVMe (наприклад: nvme0n1p1 → nvme0n1)
	if strings.HasPrefix(base, "nvme") {
		if idx := strings.Index(base, "p"); idx != -1 {
			return base[:idx]
		}
	}

	// Для звичайних (наприклад: sda1 → sda)
	return strings.TrimRightFunc(base, func(r rune) bool {
		return r >= '0' && r <= '9'
	})
}

// GetSystemDisk отримує інформацію про систему диску, включаючи загальний обсяг,
// використаний простір, модель диску та тип (SSD або HDD).
// Функція аналізує всі підключені розділи, вибирає системний розділ ("/"),
// витягує базове ім'я пристрою та отримує його модель та тип з використанням бібліотеки ghw.
// Параметри:
//   - немає.
//
// Повертає:
//   - інформацію про системний диск (структура sysinfo.SystemDiskInfo),
//     включаючи: загальний обсяг, використаний обсяг, модель та тип диску.
//   - помилку, якщо сталася помилка під час отримання інформації.
func GetSystemDisk() (sysModel.SystemDiskInfo, error) {
	// Отримуємо інформацію про розділи
	partitions, err := disk.Partitions(false)
	if err != nil {
		return sysModel.NewDefaultSystemInfo().SystemDisk, err
	}

	// Знайти системний розділ ("/")
	var systemDevice string
	for _, p := range partitions {
		if p.Mountpoint == "/" {
			systemDevice = p.Device
			break
		}
	}

	if systemDevice == "" {
		return sysModel.SystemDiskInfo{}, fmt.Errorf("System device not found")
	}

	// Витягуємо базове ім’я диску (sda, nvme0n1 і т.д.)
	deviceBase := extractDiskBaseName(systemDevice)

	// Отримуємо інформацію про блокові пристрої
	block, err := ghw.Block()
	if err != nil {
		return sysModel.SystemDiskInfo{}, err
	}

	// Змінні для моделі та типу диску
	var model, diskType string
	for _, d := range block.Disks {
		if d.Name == deviceBase {
			model = d.Model

			// Визначаємо тип диску
			switch d.DriveType.String() {
			case "SSD":
				if d.StorageController.String() == "NVMe" {
					diskType = "SSD (NVMe)"
				} else {
					diskType = "SSD (SATA)"
				}

			default:
				diskType = fmt.Sprintf("%s ", d.DriveType.String())
			}
			break
		}
	}

	// Якщо модель або тип диску не знайдені, встановлюємо значення за замовчуванням
	if model == "" {
		model = "Unknown"
	}
	if diskType == "" {
		diskType = "Unknown"
	}

	// Отримуємо інформацію про використання простору на диску
	usage, err := disk.Usage("/")
	if err != nil {
		return sysModel.NewDefaultSystemInfo().SystemDisk, err
	}

	// Створюємо структуру з інформацією про системний диск
	info := sysModel.SystemDiskInfo{
		Total: math.Round((float64(usage.Total)/1024/1024/1024)*100) / 100,
		Usage: math.Round((float64(usage.Used)/1024/1024/1024)*100) / 100,
		Model: model,
		Type:  diskType,
	}

	// Повертаємо інформацію про диск
	return info, nil
}
