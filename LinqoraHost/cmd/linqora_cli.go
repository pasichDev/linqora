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
	authChan     = make(chan interfaces.PendingAuthRequest, 10)
	stopCh       = make(chan struct{})
	restart      = make(chan struct{})
	serverMu     sync.Mutex
	cfg          *config.ServerConfig

	// Головна команда
	rootCmd = &cobra.Command{
		Use:   "linqorahost",
		Short: "Linqora Host is a server that provides API endpoints for Linqora Remote.",
		Long:  `Linqora is a comprehensive system for monitoring and future remote control of computers through a mobile application. The project consists of two main components: Linqora Host and Linqora Remote.`,
		Run:   runServer,
	}
)

func init() {
	// Додаємо флаги
	rootCmd.Flags().IntVarP(&port, "port", "p", 8070, "Port for LinqoraHost server")
	rootCmd.Flags().BoolP("notls", "s", false, "Disable TLS/SSL for LinqoraHost server")
	rootCmd.Flags().String("cert", "./certs/dev-certs/cert.pem", "Path to the TLS certificate file")
	rootCmd.Flags().String("key", "./certs/dev-certs/key.pem", "Path to the TLS key file")
}

func startCommandProcessor() {
	scanner := bufio.NewScanner(os.Stdin)
	authRequests := make(map[string]interfaces.PendingAuthRequest)

	// Запускаем горутину для обработки запросов авторизации
	go func() {
		for {
			select {
			case req := <-authChan:
				consoleMutex.Lock()
				fmt.Printf("\n\n===> AUTHORIZATION REQUEST <===\n")
				fmt.Printf("Device:  %s\n", req.DeviceName)
				fmt.Printf("ID:      %s\n", req.DeviceID)
				fmt.Printf("IP:      %s\n", req.IP)
				fmt.Printf("Time:    %s\n\n", req.RequestTime.Format("15:04:05"))
				fmt.Printf("Allow connection? (y/n): ")

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
				fmt.Printf("Authorization for device %s approved\n", latestReq.DeviceName)
			} else {
				fmt.Printf("Authorization for device %s rejected\n", latestReq.DeviceName)
			}

			// Удаляем обработанный запрос
			delete(authRequests, latestDeviceID)
			fmt.Print("> ")
			continue
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
			fmt.Printf("Warning: Certificate file %s not found\n", certFile)
		}

		if _, err := os.Stat(keyFile); os.IsNotExist(err) {
			keyExists = false
			fmt.Printf("Warning: Key file %s not found\n", keyFile)
		}

		// Если файлов нет, автоматически выключаем TLS
		if !certExists || !keyExists {
			enableTLS = false
		}
	}

	// Загружаем конфигурацию
	var err error
	cfg, err = config.LoadConfig()
	if err != nil {
		fmt.Printf("Error loading configuration: %v\n", err)
		fmt.Println("Default configuration will be used.")
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
		fmt.Printf("Error saving configuration: %v\n", err)
	}

	// Выводим основную информацию о сервере
	fmt.Printf("TLS:         %t\n", enableTLS)
	fmt.Printf("Хост IP:     %s\n", deviceInfo.IP)
	fmt.Printf("Порт:        %d\n", cfg.Port)
	fmt.Printf("ОС:          %s\n", deviceInfo.OS)
	fmt.Println("====================================================")

	// Инициализируем канал для запросов авторизации
	authChan = make(chan interfaces.PendingAuthRequest, 10)

	// Инициализируем менеджер авторизации
	authManager = auth.NewAuthManager(cfg, authChan)

	// Запускаем сервер mDNS
	mdnsServer, err = mdns.NewMDNSServer(cfg)
	if err != nil {
		fmt.Printf("Error creating mDNS server: %v\n", err)
	}

	// Запускаем mDNS сервер
	if err := mdnsServer.Start(); err != nil {
		fmt.Printf("Error starting mDNS server: %v\n", err)
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
		if err := server.Start(ctx); err != nil {
			log.Printf("WebSocket server error: %v", err)
			close(stopCh)
		}
	}()

	// Настройка обработчика сигналов для graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)

	// Ожидаем сигнала завершения
	select {
	case <-stopCh:
		fmt.Println("Server stop signal received...")
	case sig := <-sigCh:
		fmt.Printf("Signal %v received...\n", sig)
	}

	fmt.Println("Stopping server...")
	cancel()

	// Останавливаем mDNS сервер
	if mdnsServer != nil {
		mdnsServer.Stop()
	}

	// Даем время на завершение всех подключений
	shutdownTimeout := time.NewTimer(5 * time.Second)
	shutdownDone := make(chan struct{})

	go func() {
		// Закрываем канал остановки обработчика команд консоли
		close(stopCh)

		// Закрываем логи и выполняем финальное логирование
		log.Println("All connections closed, resources released")

		// Сигнализируем о завершении процедуры shutdown
		close(shutdownDone)
	}()

	// Ожидаем завершения всех операций или таймаута
	select {
	case <-shutdownDone:
		fmt.Println("Server successfully stopped")
	case <-shutdownTimeout.C:
		fmt.Println("Timeout while stopping the server")
	}
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
