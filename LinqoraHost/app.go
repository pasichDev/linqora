package main

import (
	"LinqoraHost/cpu"
	"LinqoraHost/database"
	"LinqoraHost/ram"
	"LinqoraHost/systeminfo"

	"context"
	"log"
	"sync"
	"time"

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

			modelCpu, cpuMetricErr := cpu.GetCPUMetricsRealTime()
			modelRam, ramMetricErr := ram.GetRAMMetricsRealTime()

			// Запис у БД
			if cpuMetricErr == nil {
				_ = database.InsertCPUMetric(modelCpu)
			}
			if ramMetricErr == nil {
				_ = database.InsertRAMMetric(modelRam)
			}

			// Отримуємо всі CPU метрики
			cpuMetrics, err := database.GetCPUMetrics(20)
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
				"ramMetrics": ramMetrics,
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
	println("App is closing...")

	var wg sync.WaitGroup
	wg.Add(1)

	go func() {
		defer wg.Done()
		if err := database.ClearMetreicsTables(); err != nil {
			log.Printf("Error clearing tables: %v", err)
		}
	}()

	wg.Wait()
	database.Close()
	println("App closed successfully.")
}

func (a *App) FetchSystemInfo() (systeminfo.SystemInfoInitial, error) {
	return systeminfo.GetSystemInfo()
}

func (a *App) GetAllCPUMetrics() cpu.CPUMetrics {
	return cpu.CPUMetrics{}
}

func (a *App) GetAllRAMMetrics() ram.RAMMetrics {
	return ram.RAMMetrics{}
}
