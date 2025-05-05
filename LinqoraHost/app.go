package LinqoraHost

import (
	"LinqoraHost/systeminfo"
	"context"
	"log"
	"net/http"
)

type App struct {
	ctx        context.Context
	httpServer *http.Server
	shutdownCh chan struct{}
}

func NewApp() *App {
	app := &App{
		shutdownCh: make(chan struct{}),
	}

	// Запускаємо реєстрацію mDNS і WebSocket сервер асинхронно
	//	go registerMDNSService()
	//	go app.startWebSocketServer()

	return app
}

/*

func (a *App) startSimulationLoop() {
	go func() {
		for {
			time.Sleep(1 * time.Second)
			/*

				// Отримуємо метрики
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

				// Надсилаємо оновлення UI
				runtime.EventsEmit(a.ctx, "metrics-update", map[string]interface{}{
					"cpuMetrics": cpuMetrics,
					"ramMetrics": ramMetrics,
				})

		}
	}()

}
*/

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx

	//a.startSimulationLoop()
}

func (a *App) beforeClose(ctx context.Context) (prevent bool) {
	defer a.close()
	return false
}

func (a *App) close() {
	println("App is closing...")

	// Надсилаємо сигнал для зупинки веб-сервера
	close(a.shutdownCh)

	// Закриваємо HTTP сервер
	if err := a.httpServer.Shutdown(context.Background()); err != nil {
		log.Printf("Error shutting down server: %v", err)
	}

	// реалізувати закриття mDNS сервісу та вс

	println("App closed successfully.")
}

func (a *App) FetchSystemInfo() (systeminfo.SystemInfoInitial, error) {
	return systeminfo.GetSystemInfo()
}

/*
func (a *App) GetAllCPUMetrics() cpu.CPUMetrics {
	return cpu.CPUMetrics{}
}

func (a *App) GetAllRAMMetrics() ram.RAMMetrics {
	return ram.RAMMetrics{}
}
*/
