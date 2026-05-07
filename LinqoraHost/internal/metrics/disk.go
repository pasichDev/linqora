package metrics

import (
	"math"

	"github.com/shirou/gopsutil/disk"
)

// DiskInfo provides metrics for a specific storage volume.
type DiskInfo struct {
	Name       string  `json:"name"`       // Device name or path
	Total      float64 `json:"total"`      // Total size in GB
	Free       float64 `json:"free"`       // Free space in GB
	Used       float64 `json:"used"`       // Used space in GB
	MountPath  string  `json:"mountPath"`  // Mount point location
	FileSystem string  `json:"fileSystem"` // Type of filesystem
}

// GetDiskInfo retrieves information for all mounted physical disks.
func GetDiskInfo() ([]DiskInfo, error) {
	partitions, err := disk.Partitions(false)
	if err != nil {
		return nil, err
	}

	var result []DiskInfo

	for _, partition := range partitions {
		// Skip virtual or pseudo filesystems.
		if isSpecialFileSystem(partition.Fstype) {
			continue
		}

		usage, err := disk.Usage(partition.Mountpoint)
		if err != nil {
			continue
		}

		// Ignore partitions smaller than 100 MB.
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

// isSpecialFileSystem checks if the filesystem type belongs to virtual or system categories.
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

// roundToGB converts bytes to gigabytes, rounded to two decimal places.
func roundToGB(bytes uint64) float64 {
	return math.Round((float64(bytes)/1_000_000_000)*100) / 100
}
