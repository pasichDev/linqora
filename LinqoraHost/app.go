package main

import (
	"LinqoraHost/backend"
	"LinqoraHost/backend/database"
	sysModel "LinqoraHost/backend/model"
	"context"
	"fmt"
	"log"
	"math"
	"time"

	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/host"
	"github.com/shirou/gopsutil/mem"
	"github.com/shirou/gopsutil/process"
	"github.com/wailsapp/wails/v2/pkg/runtime"
	_ "modernc.org/sqlite"
)

// App struct
type App struct {
	ctx context.Context
}

// NewApp creates a new App application struct
func NewApp() *App {
	return &App{}
}

func (a *App) startSimulationLoop() {
	go func() {
		for {
			time.Sleep(2 * time.Second)

			load, _ := GetCPULoad()
			temp, _ := GetCPUTemperature()
			proc, thrd, _ := getProcessesAndThreads()

			cpu := database.CPUMetrics{
				Temperature: temp,
				LoadPercent: load,
				Processes:   float64(proc),
				Threads:     float64(thrd),
				Frequencies: 0,
			}

			v, _ := mem.VirtualMemory()
			ram := database.RAMMetrics{
				LoadPercent: v.UsedPercent,
				Usage:       math.Round((float64(v.Used)/1_000_000_000)*100) / 100,
			}

			// Запис у БД
			_ = database.InsertCPUMetric(cpu)
			_ = database.InsertRAMMetric(ram)

			// Отримуємо всі CPU метрики
			cpuMetrics, err := database.GetCPUMetrics(30)
			if err != nil {
				log.Fatalf("Error getting CPU metrics: %v", err)
			}

			// Отримуємо всі RAM метрики
			ramMetrics, err := database.GetRAMMetrics(20)
			if err != nil {
				log.Fatalf("Error getting RAM metrics: %v", err)
			}

			// Надсилання в UI
			runtime.EventsEmit(a.ctx, "metrics-update", map[string]interface{}{
				"cpuMetrics": cpuMetrics,
				"ram":        ramMetrics,
			})
		}
	}()
}

// startup is called when the app starts. The context is saved
// so we can call the runtime methods
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
	err := database.Init()
	if err != nil {
		log.Fatalf("Failed to initialize DB: %v", err)
	}
	a.startSimulationLoop()

}

// beforeClose is called when the application is about to quit,
// either by clicking the window close button or calling runtime.Quit.
// Returning true will cause the application to continue, false will continue shutdown as normal.
func (a *App) beforeClose(ctx context.Context) (prevent bool) {
	defer a.close()
	return false
}

func (a *App) close() {
	// Додати очистку даних бд тощо
	println("App is closing...")
	database.Close()
	ClearAllTables()
}

func (a *App) FetchSystemInfo() (sysModel.SystemInfoInitial, error) {
	return backend.GetSystemInfo()
}

func ClearAllTables() error {
	tables := []string{database.TABLE_RAM_METRIC, database.TABLE_CPU_METRIC}

	for _, table := range tables {
		err := database.ClearTable(table)
		if err != nil {
			return fmt.Errorf("failed to clear table %s: %w", table, err)
		}
	}

	return nil
}

/** MOVE **/

// GetCPULoad повертає відсоток завантаження CPU
func GetCPULoad() (float64, error) {
	// отримуємо навантаження за 1 секунду
	percentages, err := cpu.Percent(1*time.Second, false)
	if err != nil {
		return 0, err
	}
	if len(percentages) > 0 {
		return percentages[0], nil
	}
	return 0, nil
}

// GetCPUTemperature повертає температуру CPU, якщо можливо
func GetCPUTemperature() (float64, error) {
	sensors, err := host.SensorsTemperatures()
	if err != nil {
		return 0, err
	}
	for _, sensor := range sensors {
		// Спробуємо знайти щось, що схоже на температуру CPU
		if sensor.SensorKey == "Package id 0" || sensor.SensorKey == "Tdie" || sensor.SensorKey == "Core 0" {
			return sensor.Temperature, nil
		}
	}
	// Якщо не знайшли нічого специфічного — повернемо перший
	if len(sensors) > 0 {
		return sensors[0].Temperature, nil
	}
	return 0, nil
}

func getProcessesAndThreads() (int, int, error) {
	procs, err := process.Processes()
	if err != nil {
		return 0, 0, err
	}

	numProcesses := len(procs)
	totalThreads := 0

	for _, p := range procs {
		threads, err := p.NumThreads()
		if err == nil {
			totalThreads += int(threads)
		}
		// якщо треба — можна логувати/ігнорувати помилки
	}

	return numProcesses, totalThreads, nil
}

func (a *App) GetAllCPUMetrics() database.CPUMetrics {
	return database.CPUMetrics{}
}

func (a *App) GetAllRAMMetrics() database.RAMMetrics {
	return database.RAMMetrics{}
}
