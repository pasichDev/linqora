package backend

import (
	sysModel "LinqoraHost/backend/model"
	"fmt"
	"math"
	"strings"

	"github.com/jaypipes/ghw"
	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/mem"
)

// GetSystemInfo повертає основну системну інформацію:
// модель процесора, кількість ядер і потоків,
// обсяг та використання оперативної памʼяті,
// а також інформацію про системний диск.
//
// Повертає структуру SystemInfoInitial та помилку, якщо щось пішло не так під час збирання інформації.
func GetSystemInfo() (sysModel.SystemInfoInitial, error) {
	// Ініціалізуємо структуру з дефолтними значеннями
	systemInf := sysModel.NewDefaultSystemInfo()

	// Отримуємо інформацію про процесор
	cpuArray, cpuError := cpu.Info()
	if cpuError != nil {
		return systemInf, cpuError
	}

	// Якщо є хоча б один процесор, заповнюємо модель, кількість ядер і потоків
	if len(cpuArray) > 0 {
		c := cpuArray[0]
		systemInf.CpuInfo = sysModel.CpuInfo{
			Model: c.ModelName,
		}
	}

	v, vMError := mem.VirtualMemory()
	if vMError != nil {
		return systemInf, vMError
	}

	// Отримуємо загальний обсяг і використання оперативної памʼяті (в ГБ, округлено до 2 знаків після коми)
	systemInf.RamInfo = sysModel.RamInfo{
		Total: math.Round((float64(v.Total)/1_000_000_000)*100) / 100,
	}

	// Отримуємо інформацію про системний диск
	systemDisk, err := GetAllSystemDisks()
	if err != nil {
		return systemInf, err
	}

	systemInf.SystemDisk = systemDisk

	return systemInf, nil
}

// GetAllSystemDisks повертає список усіх фізичних дисків (SSD або HDD),
// без флешок, CD/DVD, USB і флоппі дисків.
func GetAllSystemDisks() ([]sysModel.SystemDiskInfo, error) {
	block, err := ghw.Block()
	if err != nil {
		return nil, fmt.Errorf("failed to get block devices: %w", err)
	}

	var result []sysModel.SystemDiskInfo

	// Перебір тільки фізичних дисків
	for _, diskDevice := range block.Disks {
		// Пропускаємо флешки, USB, CD/DVD та флоппі
		if diskDevice.IsRemovable || diskDevice.StorageController.String() == "USB" || diskDevice.DriveType.String() == "Optical" {
			continue
		}
		if strings.HasPrefix(diskDevice.Name, "loop") ||
			strings.HasPrefix(diskDevice.Name, "ram") ||
			strings.Contains(diskDevice.Name, "snap") ||
			strings.Contains(diskDevice.Name, "docker") {
			continue
		}
		// Визначаємо тип диску
		var diskType string
		switch diskDevice.DriveType.String() {
		case "SSD":
			if diskDevice.StorageController.String() == "NVMe" {
				diskType = "SSD (NVMe)"
			} else {
				diskType = "SSD (SATA)"
			}
		case "HDD":
			diskType = "HDD"
		default:
			continue // Якщо тип диску невідомий, пропускаємо
		}

		// Якщо модель порожня, пропускаємо диск
		model := diskDevice.Model
		if model == "" {
			continue
		}

		// Підраховуємо використання диску (це можна зробити за допомогою додаткових бібліотек або системних викликів)
		/*	usage, err := disk.Usage(diskDevice.BusPath)
			if err != nil {
				return sysModel.NewDefaultSystemInfo().SystemDisk, err
			}

		*/

		// Формуємо структуру для фізичного диску
		info := sysModel.SystemDiskInfo{
			Total: math.Round((float64(diskDevice.SizeBytes)/1_000_000_000)*100) / 100,
			//	Usage: math.Round((float64(usage.Used)/1024/1024/1024)*100) / 100,
			Model: model,    // Модель диску
			Type:  diskType, // Тип диску (SSD або HDD)
		}

		// Додаємо диск до результату
		result = append(result, info)
	}

	return result, nil
}
