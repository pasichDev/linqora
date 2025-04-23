package systeminfo

import (
	"math"

	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/mem"
)

// SystemInfoInitial з інформацією про систему
type SystemInfoInitial struct {
	CpuInfo    CpuInfo          `json:"cpu_info"`
	RamInfo    RamInfo          `json:"ram_info"`
	SystemDisk []SystemDiskInfo `json:"system_disk"`
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
		SystemDisk: []SystemDiskInfo{
			{
				Total: 0,
				Usage: 0,
				Model: "Unknown Disk",
				Type:  "Unknown",
			},
		},
	}
}

// GetSystemInfo повертає основну системну інформацію:
// модель процесора, кількість ядер і потоків,
// обсяг та використання оперативної памʼяті,
// а також інформацію про системний диск.
//
// Повертає структуру SystemInfoInitial та помилку, якщо щось пішло не так під час збирання інформації.
func GetSystemInfo() (SystemInfoInitial, error) {
	// Ініціалізуємо структуру з дефолтними значеннями
	systemInf := NewDefaultSystemInfo()

	// Отримуємо інформацію про процесор
	cpuBase, _cpuError := GetCPUBaseInfo()
	if _cpuError == nil {
		systemInf.CpuInfo = cpuBase
	}
	// Отримуємо інформацію про системну памʼять
	v, vMError := mem.VirtualMemory()
	if vMError == nil {
		systemInf.RamInfo = RamInfo{
			Total: math.Round((float64(v.Total)/1_000_000_000)*100) / 100,
		}
	}

	return systemInf, nil
}

func GetCPUBaseInfo() (CpuInfo, error) {
	mCpuInfo := NewDefaultSystemInfo().CpuInfo

	// Отримуємо інформацію про процесор
	cpuArray, cpuError := cpu.Info()
	if cpuError != nil {
		return mCpuInfo, cpuError
	}

	// Якщо є хоча б один процесор, заповнюємо модель, кількість ядер і потоків
	if len(cpuArray) > 0 {
		c := cpuArray[0]
		mCpuInfo = CpuInfo{
			Model: c.ModelName,
		}
	}

	return mCpuInfo, nil
}
