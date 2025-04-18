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
	//Usage float64 `json:"usage"`
}

type CpuInfo struct {
	Model string `json:"model"`
	Cores int64  `json:"cores"`
	// Threads int64  `json:"theads"`
}

func NewDefaultSystemInfo() SystemInfoInitial {
	return SystemInfoInitial{
		CpuInfo: CpuInfo{
			Model: "Unknown CPU",
			Cores: 0,
			//	Threads: 0,
		},
		RamInfo: RamInfo{
			Total: 0,
			//	Usage: 0,
		},
		SystemDisk: SystemDiskInfo{
			Total: 0,
			Usage: 0,
			Model: "Unknown Disk",
			Type:  "Unknown",
		},
	}
}
