package backend

import (
	"LinqoraHost/backend/handler"
	sysModel "LinqoraHost/backend/model"
	"math"

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
		Total: math.Round((float64(v.Total)/1024/1024/1024)*100) / 100,
	}

	// Отримуємо інформацію про системний диск
	systemDisk, err := handler.GetSystemDisk()
	if err != nil {
		return systemInf, err
	}

	systemInf.SystemDisk = systemDisk

	return systemInf, nil
}
