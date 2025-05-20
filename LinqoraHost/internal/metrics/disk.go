package metrics

import (
	"math"

	"github.com/shirou/gopsutil/disk"
)

// DiskInfo содержит информацию о диске
type DiskInfo struct {
	Name       string  `json:"name"`       // Имя/путь диска
	Total      float64 `json:"total"`      // Общий размер в ГБ
	Free       float64 `json:"free"`       // Свободное место в ГБ
	Used       float64 `json:"used"`       // Использовано в ГБ
	MountPath  string  `json:"mountPath"`  // Точка монтирования
	FileSystem string  `json:"fileSystem"` // Файловая система
}

// GetDiskInfo возвращает информацию обо всех дисках
func GetDiskInfo() ([]DiskInfo, error) {
	partitions, err := disk.Partitions(false)
	if err != nil {
		return nil, err
	}

	var result []DiskInfo

	for _, partition := range partitions {
		// Пропускаем специальные файловые системы, которые не являются физическими дисками
		if isSpecialFileSystem(partition.Fstype) {
			continue
		}

		usage, err := disk.Usage(partition.Mountpoint)
		if err != nil {
			continue
		}

		// Пропускаем слишком маленькие разделы (меньше 100 МБ)
		if usage.Total < 100*1024*1024 {
			continue
		}

		info := DiskInfo{
			Name:       partition.Device,
			MountPath:  partition.Mountpoint,
			FileSystem: partition.Fstype,
			Total:      roundToGB(usage.Total),
			Free:       roundToGB(usage.Free),
			Used:       roundToGB(usage.Used),
		}

		result = append(result, info)
	}

	return result, nil
}

// Проверяет, является ли файловая система специальной (не физической)
func isSpecialFileSystem(fstype string) bool {
	specialTypes := []string{
		"tmpfs", "devtmpfs", "devfs", "iso9660",
		"overlay", "aufs", "squashfs", "udf",
		"proc", "sysfs", "cgroup", "cgroup2",
		"pstore", "binfmt_misc", "debugfs", "tracefs",
	}

	for _, special := range specialTypes {
		if fstype == special {
			return true
		}
	}
	return false
}

// Округляет байты до гигабайт с двумя знаками после запятой
func roundToGB(bytes uint64) float64 {
	return math.Round((float64(bytes)/1_000_000_000)*100) / 100
}
