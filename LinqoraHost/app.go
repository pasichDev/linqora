package main

import (
	"LinqoraHost/cpu"
	"LinqoraHost/database"
	"LinqoraHost/ram"
	"LinqoraHost/systeminfo"
	"context"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/grandcat/zeroconf"
	"github.com/wailsapp/wails/v2/pkg/runtime"
	_ "modernc.org/sqlite"
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
	go registerMDNSService()
	go app.startWebSocketServer()

	return app
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true }, // Дозволяє підключатися з будь-якого походження
}

func (a *App) startWebSocketServer() {
	mux := http.NewServeMux()

	// Обробник WebSocket з'єднання
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		log.Println("WebSocket connection attempt from", r.RemoteAddr)
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Println("Upgrade error:", err)
			return
		}
		defer conn.Close()

		for {
			// Надсилаємо повідомлення кожну секунду
			message := "Hello from PC!"
			err := conn.WriteMessage(websocket.TextMessage, []byte(message))
			if err != nil {
				log.Println("Write error:", err)
				break
			}
			time.Sleep(1 * time.Second) // Відправка повідомлення кожну секунду
		}
	})

	a.httpServer = &http.Server{
		Addr:    ":8070",
		Handler: mux,
	}

	log.Println("WebSocket server started at :8070")
	// Запускаємо сервер на порту 8070
	err := a.httpServer.ListenAndServe()
	if err != nil && err != http.ErrServerClosed {
		log.Fatal("Server failed: ", err)
	}
}

func registerMDNSService() {
	// Реєструємо mDNS сервіс
	server, err := zeroconf.Register("monitor-test", "_222222._tcp", "local.", 8070, nil, nil)
	if err != nil {
		log.Fatal("mDNS registration failed:", err)
	}
	defer server.Shutdown()
	select {} // Блокуємо горутину, щоб сервер залишався працюючим
}

func (a *App) startSimulationLoop() {
	go func() {
		for {
			time.Sleep(1 * time.Second)

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

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
	err := database.Init()
	if err != nil {
		log.Fatalf("Failed to initialize DB: %v", err)
	}
	a.startSimulationLoop()
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
