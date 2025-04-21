package backend

// SystemInfoInitial з інформацією про систему
type SystemInfoInitial struct {
	CpuInfo    CpuInfo        `json:"cpu_info"`
	RamInfo    RamInfo        `json:"ram_info"`
	SystemDisk SystemDiskInfo `json:"system_disk"`
}

type SystemDiskInfo struct {
	Total float64 `json:"total"` // Total Space
	Usage float64 `json:"usage"` // Usage Space
	Model string  `json:"model"` // Name Model Vendor
	Type  string  `json:"type"`  // SSD OR HDD
}

type RamInfo struct {
	Total float64 `json:"total"`
}

type CpuInfo struct {
	Model string `json:"model"`
}

func NewDefaultSystemInfo() SystemInfoInitial {
	return SystemInfoInitial{
		CpuInfo: CpuInfo{
			Model: "Unknown CPU",
		},
		RamInfo: RamInfo{
			Total: 0,
		},
		SystemDisk: SystemDiskInfo{
			Total: 0,
			Usage: 0,
			Model: "Unknown Disk",
			Type:  "Unknown",
		},
	}
}
