package main

import (
	"LinqoraHost/internal/config"
	"LinqoraHost/internal/metrics"
	"fmt"
	"log"
	"math/rand"
	"os"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
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
	} else if !isValidAuthCode(codeStr) {
		fmt.Println("Помилка: Код автентифікації повинен складатися з 6 цифр")
		os.Exit(1)
	}

	// Вивід додаткової системної інформації
	fmt.Printf("Хост IP:     %s\n", deviceInfo.IP)
	fmt.Printf("Порт:        %s\n", deviceInfo.PORT)
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
	fmt.Println("Натисніть Ctrl+C для виходу")
	fmt.Println()

	// Створюємо новий сервер
	server := LinqoraHost.NewServer(cfg)

	// Обробка сигналів для коректного завершення
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)

	// Запускаємо сервер у goroutine
	go func() {
		if err := server.Start(); err != nil {
			log.Fatalf("Server error: %v", err)
		}
	}()

	fmt.Println(strings.Repeat("─", 50))
	fmt.Println()

	// Очікуємо на сигнал завершення
	<-sigCh
	fmt.Println("\nВимикання сервера...")

	// Зупиняємо сервер
	server.Shutdown()
	fmt.Println("Сервер зупинено")
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
