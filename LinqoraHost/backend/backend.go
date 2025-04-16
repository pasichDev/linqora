package backend

import (
	"LinqoraHost/backend/handler"
	sysModel "LinqoraHost/backend/model"
	"math"

	"github.com/jaypipes/ghw"
	"github.com/pbnjay/memory"
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
	cpuInfo, err := ghw.CPU()
	if err != nil {
		return systemInf, err
	}

	// Якщо є хоча б один процесор, заповнюємо модель, кількість ядер і потоків
	if len(cpuInfo.Processors) > 0 {
		systemInf.CpuInfo = sysModel.CpuInfo{
			Model:   cpuInfo.Processors[0].Model,
			Cores:   int64(cpuInfo.Processors[0].NumCores),
			Threads: int64(cpuInfo.Processors[0].NumThreads),
		}
	}

	// Отримуємо загальний обсяг і використання оперативної памʼяті (в ГБ, округлено до 2 знаків після коми)
	systemInf.RamInfo = sysModel.RamInfo{
		Total: math.Round((float64(memory.TotalMemory())/1024/1024/1024)*100) / 100,
		Usage: math.Round((float64(memory.TotalMemory()-memory.FreeMemory())/1024/1024/1024)*100) / 100,
	}

	// Отримуємо інформацію про системний диск
	systemDisk, err := handler.GetSystemDisk()
	if err != nil {
		return systemInf, err
	}

	systemInf.SystemDisk = systemDisk

	return systemInf, nil
}
