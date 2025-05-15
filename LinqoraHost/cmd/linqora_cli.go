package main

import (
	"LinqoraHost/internal/auth"
	"LinqoraHost/internal/config"
	"LinqoraHost/internal/interfaces"
	"LinqoraHost/internal/mdns"
	"LinqoraHost/internal/metrics"
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"LinqoraHost"

	"github.com/spf13/cobra"
)

var (
	port         int
	server       *LinqoraHost.Server
	mdnsServer   *mdns.MDNSServer
	authManager  *auth.AuthManager
	consoleMutex sync.Mutex
	authChan     = make(chan interfaces.PendingAuthRequest, 10) // Буфер для запросов авторизации
	stopCh       = make(chan struct{})
	restart      = make(chan struct{})
	serverMu     sync.Mutex
	cfg          *config.ServerConfig

	// Головна команда
	rootCmd = &cobra.Command{
		Use:   "linqora",
		Short: "Linqora Host Server - сервер для віддаленого керування пристроями",
		Long:  `Linqora Host Server - сервер для моніторингу та віддаленого керування пристроями.`,
		Run:   runServer,
	}
)

func init() {
	// Додаємо флаги
	rootCmd.Flags().IntVarP(&port, "port", "p", 8070, "Порт для WebSocket сервера")
	rootCmd.Flags().BoolP("notls", "s", false, "Disable TLS/SSL for WebSocket")
	rootCmd.Flags().String("cert", "./certs/dev-certs/cert.pem", "Path to the TLS certificate file")
	rootCmd.Flags().String("key", "./certs/dev-certs/key.pem", "Path to the TLS key file")
}

// startCommandProcessor запускает обработчик команд консоли
func startCommandProcessor() {
	scanner := bufio.NewScanner(os.Stdin)
	authRequests := make(map[string]interfaces.PendingAuthRequest)

	fmt.Println("\nВведите 'help' для просмотра доступных команд")
	fmt.Print("> ")

	// Запускаем горутину для обработки запросов авторизации
	go func() {
		for {
			select {
			case req := <-authChan:
				consoleMutex.Lock()
				fmt.Printf("\n\n===> ЗАПРОС АВТОРИЗАЦИИ <===\n")
				fmt.Printf("Устройство:  %s\n", req.DeviceName)
				fmt.Printf("ID:          %s\n", req.DeviceID)
				fmt.Printf("IP:          %s\n", req.IP)
				fmt.Printf("Время:       %s\n\n", req.RequestTime.Format("15:04:05"))
				fmt.Printf("Разрешить подключение? (y/n): ")

				// Сохраняем запрос для последующей обработки
				authRequests[req.DeviceID] = req
				consoleMutex.Unlock()

			case <-stopCh:
				return
			}
		}
	}()

	for scanner.Scan() {
		command := scanner.Text()

		// Проверка на ответы на запросы авторизации
		if len(authRequests) > 0 && (strings.ToLower(command) == "y" || strings.ToLower(command) == "n") {
			// Находим последний запрос авторизации
			var latestReq interfaces.PendingAuthRequest
			var latestDeviceID string
			latestTime := time.Time{}

			for id, req := range authRequests {
				if latestTime.IsZero() || req.RequestTime.After(latestTime) {
					latestReq = req
					latestDeviceID = id
					latestTime = req.RequestTime
				}
			}

			approved := strings.ToLower(command) == "y"

			// Отвечаем на запрос
			authManager.RespondToAuthRequest(latestDeviceID, approved)

			if approved {
				fmt.Printf("Авторизация для устройства %s одобрена\n", latestReq.DeviceName)
			} else {
				fmt.Printf("Авторизация для устройства %s отклонена\n", latestReq.DeviceName)
			}

			// Удаляем обработанный запрос
			delete(authRequests, latestDeviceID)
			fmt.Print("> ")
			continue
		}

		// Обработка обычных команд
		switch strings.ToLower(strings.TrimSpace(command)) {
		// ... [остальной код обработки команд] ...
		}

		fmt.Print("> ")
	}
}

// Главная функция запуска сервера
func runServer(cmd *cobra.Command, args []string) {
	fmt.Println("====================================================")
	fmt.Println("                 LINQORA HOST SERVER                ")
	fmt.Println("====================================================")

	// Получаем системную информацию
	deviceInfo := metrics.GetDeviceInfo()

	// Получаем значения TLS-флагов
	disableTLS, _ := cmd.Flags().GetBool("notls")
	enableTLS := !disableTLS
	certFile, _ := cmd.Flags().GetString("cert")
	keyFile, _ := cmd.Flags().GetString("key")

	// Проверяем наличие сертификатов, если TLS включен
	if enableTLS {
		certExists := true
		keyExists := true

		if _, err := os.Stat(certFile); os.IsNotExist(err) {
			certExists = false
			fmt.Printf("Предупреждение: Файл сертификата %s не найден\n", certFile)
		}

		if _, err := os.Stat(keyFile); os.IsNotExist(err) {
			keyExists = false
			fmt.Printf("Предупреждение: Файл ключа %s не найден\n", keyFile)
		}

		// Если файлов нет, автоматически выключаем TLS
		if !certExists || !keyExists {
			fmt.Println("TLS автоматически отключен из-за отсутствия сертификатов")
			enableTLS = false
		} else {
			fmt.Println("TLS включен. Используется защищенный WebSocket (WSS).")
		}
	} else {
		fmt.Println("TLS отключен. Используется незащищенный WebSocket (WS).")
	}

	// Загружаем конфигурацию
	var err error
	cfg, err = config.LoadConfig()
	if err != nil {
		fmt.Printf("Ошибка загрузки конфигурации: %v\n", err)
		fmt.Println("Будет использована конфигурация по умолчанию.")
		cfg = config.DefaultConfig()
	}

	// Обновляем порт, если указан в аргументах
	if port != 0 {
		cfg.Port = port
	}

	// Обновляем настройки TLS
	cfg.EnableTLS = enableTLS
	cfg.CertFile = certFile
	cfg.KeyFile = keyFile

	// Сохраняем обновленную конфигурацию
	if err := cfg.SaveConfig(); err != nil {
		fmt.Printf("Ошибка сохранения конфигурации: %v\n", err)
	}

	// Выводим основную информацию о сервере
	fmt.Printf("Хост IP:     %s\n", deviceInfo.IP)
	fmt.Printf("Порт:        %d\n", cfg.Port)
	fmt.Printf("ОС:          %s\n", deviceInfo.OS)

	// Инициализируем канал для запросов авторизации
	authChan = make(chan interfaces.PendingAuthRequest, 10)

	// Инициализируем менеджер авторизации
	authManager = auth.NewAuthManager(cfg, authChan)

	// Запускаем сервер mDNS
	mdnsServer, err = mdns.NewMDNSServer(cfg)
	if err != nil {
		fmt.Printf("Ошибка создания mDNS сервера: %v\n", err)
	}

	// Вывод информации о mDNS
	fmt.Println("═════════════════════════════════════════════════")
	fmt.Printf("mDNS имя:    %s\n", mdnsServer.GetServiceName())
	fmt.Printf("mDNS тип:    %s\n", mdnsServer.GetServiceType())
	fmt.Printf("mDNS домен:  %s\n", cfg.MDNSDomain)
	fmt.Println("═════════════════════════════════════════════════")

	// Запускаем mDNS сервер
	if err := mdnsServer.Start(); err != nil {
		fmt.Printf("Ошибка запуска mDNS сервера: %v\n", err)
		os.Exit(1)
	}

	// Инициализируем основной сервер
	server = LinqoraHost.NewServer(cfg, authManager)

	// Запускаем обработчик команд в отдельной горутине
	go startCommandProcessor()

	// Создаем контекст для управляемого завершения
	ctx, cancel := context.WithCancel(context.Background())

	// Запускаем сервер в отдельной горутине
	go func() {
		log.Println("Запуск WebSocket сервера...")
		if err := server.Start(ctx); err != nil {
			log.Printf("Ошибка WebSocket сервера: %v", err)
			close(stopCh) // Сигнал для завершения программы при ошибке
		}
	}()

	// Настройка обработчика сигналов для graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)

	// Ожидаем сигнала завершения
	select {
	case <-stopCh:
		fmt.Println("Получен сигнал остановки сервера...")
	case sig := <-sigCh:
		fmt.Printf("Получен сигнал %v...\n", sig)
	}

	// Корректное завершение сервера
	fmt.Println("Останавливаем сервер...")
	cancel() // Отменяем контекст для graceful shutdown

	// Останавливаем mDNS сервер
	if mdnsServer != nil {
		mdnsServer.Stop()
	}

	// Даем время на завершение всех подключений
	shutdownTimeout := time.NewTimer(5 * time.Second)
	shutdownDone := make(chan struct{})

	go func() {
		// Здесь можно добавить дополнительную логику завершения
		close(shutdownDone)
	}()

	// Ожидаем завершения всех операций или таймаута
	select {
	case <-shutdownDone:
		fmt.Println("Сервер успешно остановлен")
	case <-shutdownTimeout.C:
		fmt.Println("Таймаут при остановке сервера")
	}
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
