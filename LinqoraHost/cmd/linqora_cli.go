package main

import (
	"LinqoraHost/internal/config"
	"LinqoraHost/internal/metrics"
	"bufio"
	"fmt"
	"math/rand"
	"os"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"LinqoraHost"

	"github.com/mdp/qrterminal/v3"
	"github.com/spf13/cobra"
)

/**
sudo apt-get install libx11-dev xorg-dev libxtst-dev xsel xclip
реалізувати перевірку чи встановлені необхідін пакети
*/

var (
	// Глобальні змінні для флагів
	port     int
	authCode string
	server   *LinqoraHost.Server // Глобальна змінна для доступу до сервера
	stopCh   chan struct{}       // Канал для сигналу зупинки
	restart  chan struct{}       // Канал для сигналу перезапуску
	serverMu sync.Mutex          // М'ютекс для безпечного доступу до сервера

	// Головна команда
	rootCmd = &cobra.Command{
		Use:   "linqora",
		Short: "Linqora Host Server - сервер для віддаленого керування пристроями",
		Long: `Linqora Host Server - сервер для віддаленого керування пристроями.
Запускає WebSocket сервер та mDNS для виявлення пристроїв.`,
		Run: runServer,
	}
)

// Execute виконує кореневу команду
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

// init ініціалізує команди та флаги
func init() {
	// Ініціалізуємо генератор випадкових чисел
	rand.Seed(time.Now().UnixNano())

	// Додаємо флаги
	rootCmd.Flags().IntVarP(&port, "port", "p", 8070, "Порт для WebSocket сервера")
	rootCmd.Flags().StringVarP(&authCode, "code", "c", "", "Код автентифікації (6 цифр)")

	// Ініціалізуємо канали
	stopCh = make(chan struct{})
	restart = make(chan struct{})
}

// Перевіряє, чи рядок складається тільки з 6 цифр
func isValidAuthCode(code string) bool {
	match, _ := regexp.MatchString(`^\d{6}$`, code)
	return match
}

// Генерує новий код автентифікації
func generateAuthCode() string {
	// Генеруємо число в діапазоні [100000, 999999]
	code := rand.Intn(900000) + 100000
	return strconv.Itoa(code)
}

// startCommandProcessor запускає обробник команд з консолі
func startCommandProcessor() {
	scanner := bufio.NewScanner(os.Stdin)
	fmt.Println("Введіть команду (help - для списку команд):")

	for {
		if scanner.Scan() {
			command := scanner.Text()
			processCommand(command)
		} else {
			break
		}
	}
}

// processCommand обробляє введену команду
func processCommand(command string) {
	command = strings.TrimSpace(strings.ToLower(command))
	args := strings.Fields(command)

	if len(args) == 0 {
		return
	}

	switch args[0] {
	case "help", "?":
		showHelp()
	case "restart":
		restartServer()
	case "stop", "exit", "quit":
		stopServer()
	case "send":
		if len(args) > 1 {
			sendFile(args[1:])
		} else {
			fmt.Println("Використання: send <шлях_до_файлу>")
		}
	case "code", "changecode":
		if len(args) > 1 {
			changeCode(args[1])
		} else {
			fmt.Println("Використання: code <новий_код>")
		}
	case "status":
		showStatus()
	default:
		fmt.Println("Невідома команда. Введіть 'help' для списку команд.")
	}
}

// showHelp виводить список доступних команд
func showHelp() {
	fmt.Println("Доступні команди:")
	fmt.Println("  help, ?      - Показати цей список команд")
	fmt.Println("  restart      - Перезапустити сервер")
	fmt.Println("  stop, exit   - Зупинити сервер і вийти")
	fmt.Println("  send <файл>  - Передати файл")
	fmt.Println("  code <код>   - Змінити код автентифікації")
	fmt.Println("  status       - Показати статус сервера")
}

// restartServer перезапускає сервер
func restartServer() {
	fmt.Println("Перезапуск сервера...")

	// Сигнал для перезапуску сервера
	restart <- struct{}{}
}

// stopServer зупиняє сервер
func stopServer() {
	fmt.Println("Зупинення сервера...")

	// Сигнал для зупинки сервера
	close(stopCh)
}

// sendFile обробляє команду передачі файлу
func sendFile(args []string) {
	if len(args) < 1 {
		fmt.Println("Не вказано шлях до файлу")
		return
	}

	filePath := args[0]
	fmt.Printf("Підготовка до передачі файлу: %s\n", filePath)
	fmt.Println("Функція передачі файлів ще не реалізована.")
}

// changeCode змінює код автентифікації
func changeCode(newCode string) {
	if !isValidAuthCode(newCode) {
		fmt.Println("Помилка: Код автентифікації повинен складатися з 6 цифр")
		return
	}

	fmt.Printf("Зміна коду автентифікації на: %s\n", newCode)
	fmt.Println("Необхідно перезапустити сервер для застосування змін.")
	fmt.Print("Перезапустити зараз? (y/n): ")

	scanner := bufio.NewScanner(os.Stdin)
	if scanner.Scan() && strings.ToLower(scanner.Text()) == "y" {
		authCode = newCode
		restartServer()
	}
}

// showStatus показує поточний статус сервера
func showStatus() {
	fmt.Println("====================================================")
	fmt.Println("                 СТАТУС СЕРВЕРА                     ")
	fmt.Println("====================================================")
	fmt.Printf("Порт:             %d\n", port)
	fmt.Printf("Код автентифікації: %s\n", authCode)
	fmt.Println("Сервер активний: Так")
}

func runServer(cmd *cobra.Command, args []string) {
	// Виводимо заголовок
	fmt.Println("====================================================")
	fmt.Println("                 LINQORA HOST SERVER                ")
	fmt.Println("====================================================")

	// Отримуємо системну інформацію
	deviceInfo := metrics.GetDeviceInfo()

	codeStr := authCode
	if codeStr == "" {
		codeStr = generateAuthCode()
		authCode = codeStr // Зберігаємо для глобального доступу
	} else if !isValidAuthCode(codeStr) {
		fmt.Println("Помилка: Код автентифікації повинен складатися з 6 цифр")
		os.Exit(1)
	}

	// Вивід додаткової системної інформації
	fmt.Printf("Хост IP:     %s\n", deviceInfo.IP)
	fmt.Printf("Порт:        %d\n", port)
	fmt.Printf("ОС:          %s\n", deviceInfo.OS)
	fmt.Println("═════════════════════════════════════════════════")
	fmt.Printf("КОД АВТЕНТИФІКАЦІЇ:          %s\n", codeStr)
	fmt.Println("═════════════════════════════════════════════════")
	fmt.Println()

	// Налаштування та генерація QR-коду
	qrConfig := qrterminal.Config{
		Level:     qrterminal.M,
		Writer:    os.Stdout,
		BlackChar: qrterminal.BLACK,
		WhiteChar: qrterminal.WHITE,
		QuietZone: 1,
	}
	qrterminal.GenerateWithConfig(codeStr, qrConfig)

	// Лінія-розділювач після QR-коду
	fmt.Println(strings.Repeat("─", 50))
	fmt.Println()

	// Запускаємо обробник команд у окремій горутині
	go startCommandProcessor()

	// Запускаємо сервер у циклі для можливості перезапуску
	for {
		// Створюємо конфігурацію сервера
		cfg := &config.ServerConfig{
			Port:       port,
			MDNSName:   "linqora_host",
			MDNSType:   "_" + codeStr + "._tcp",
			MDNSDomain: "local.",
			ValidDeviceIDs: map[string]bool{
				codeStr: true,
			},
			MetricsInterval: 2 * 1000000000, // 2 секунди в наносекундах
		}

		// Повідомлення про підготовку до запуску
		fmt.Println("Підготовка до запуску сервера...")
		fmt.Println()

		// Створюємо новий сервер
		serverMu.Lock()
		server = LinqoraHost.NewServer(cfg)
		serverMu.Unlock()

		// Обробка сигналів для коректного завершення
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)

		// Запускаємо сервер у goroutine
		serverErrCh := make(chan error, 1)
		go func() {
			err := server.Start()
			if err != nil {
				serverErrCh <- err
			}
		}()

		fmt.Println("Сервер запущено. Очікування команд або підключень...")
		fmt.Println(strings.Repeat("─", 50))
		fmt.Println()

		// Очікуємо на сигнали
		select {
		case <-stopCh:
			fmt.Println("\nВимикання сервера...")
			serverMu.Lock()
			server.Shutdown()
			serverMu.Unlock()
			fmt.Println("Сервер зупинено")
			return // Виходимо з програми

		case <-restart:
			fmt.Println("\nПерезапуск сервера...")
			serverMu.Lock()
			server.Shutdown()
			serverMu.Unlock()
			fmt.Println("Сервер зупинено, підготовка до перезапуску...")
			continue // Продовжуємо цикл для перезапуску

		case <-sigCh:
			fmt.Println("\nОтримано сигнал переривання...")
			serverMu.Lock()
			server.Shutdown()
			serverMu.Unlock()
			fmt.Println("Сервер зупинено")
			return // Виходимо з програми

		case err := <-serverErrCh:
			fmt.Printf("\nПомилка сервера: %v\n", err)
			fmt.Println("Спроба перезапустити сервер через 5 секунд...")
			time.Sleep(5 * time.Second)
			continue // Продовжуємо цикл для перезапуску
		}
	}
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
