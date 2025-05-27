package main

import (
	"LinqoraHost/internal/auth"
	"LinqoraHost/internal/certutils"
	"LinqoraHost/internal/config"
	"LinqoraHost/internal/deviceinfo"
	"LinqoraHost/internal/interfaces"
	"LinqoraHost/internal/mdns"
	"LinqoraHost/internal/ws"
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

	"github.com/spf13/cobra"
)

var (
	port           int
	mdnsServer     *mdns.MDNSServer
	authManager    *auth.AuthManager
	authChan       = make(chan interfaces.PendingAuthRequest, 10)
	stopCh         = make(chan struct{})
	restart        = make(chan struct{})
	serverMu       sync.Mutex
	cfg            *config.ServerConfig
	consoleHandler *auth.ConsoleAuthHandler

	rootCmd = &cobra.Command{
		Use:   "linqorahost",
		Short: "Linqora Host is a server that provides API endpoints for Linqora Remote.",
		Long:  `Linqora is a comprehensive system for monitoring and future remote control of computers through a mobile application. The project consists of two main components: Linqora Host and Linqora Remote.`,
		Run:   runServer,
	}
)

func init() {
	rootCmd.Flags().IntVarP(&port, "port", "p", 8070, "Port for LinqoraHost server")
	rootCmd.Flags().BoolP("notls", "s", false, "Disable TLS/SSL for LinqoraHost server")
	rootCmd.Flags().String("cert", "./certificates/dev_cert.pem", "Path to the TLS certificate file")
	rootCmd.Flags().String("key", "./certificates/dev_key.pem", "Path to the TLS key file")
}

// startCommandProcessor handles console input for the Linqora Host server.
func startCommandProcessor() {
	scanner := bufio.NewScanner(os.Stdin)

	// Start the console handler for processing auth requests
	go consoleHandler.ProcessAuthRequests(authChan, stopCh)

	for scanner.Scan() {
		command := scanner.Text()

		// Check if the command is empty
		if !consoleHandler.ProcessAuthResponse(strings.ToLower(command)) {
			// Else, handle the command
			handleCommand(command)
		}
	}
}

// handleCommand обробляє команди користувача
func handleCommand(command string) {
	auth.ConsoleMutex.Lock()
	fmt.Printf("command> %s\n", command)
	auth.ConsoleMutex.Unlock()
}

// gracefulShutdown handles stopping the server cleanly
func gracefulShutdown(cancel context.CancelFunc) {
	fmt.Println("Stopping server...")
	cancel()

	// Stop the WebSocket server
	if mdnsServer != nil {
		mdnsServer.Stop()
	}

	// Timeout for graceful shutdown
	shutdownTimeout := time.NewTimer(5 * time.Second)
	shutdownDone := make(chan struct{})

	go func() {
		close(stopCh)
		close(shutdownDone)
	}()

	// Pending shutdown
	select {
	case <-shutdownDone:
		fmt.Println("Server successfully stopped")
	case <-shutdownTimeout.C:
		fmt.Println("Timeout while stopping the server")
	}
}

// RunServer starts the Linqora Host server with the specified configuration.
func runServer(cmd *cobra.Command, args []string) {

	// Get device information
	deviceInfo := deviceinfo.GetDeviceInfo()

	// Get command line flags
	disableTLS, _ := cmd.Flags().GetBool("notls")
	enableTLS := !disableTLS
	certFile, _ := cmd.Flags().GetString("cert")
	keyFile, _ := cmd.Flags().GetString("key")

	// Load configuration
	var err error
	cfg, err = config.LoadConfig()
	if err != nil {
		fmt.Printf("Error loading configuration: %v\n", err)
		fmt.Println("Default configuration will be used.")
		cfg = config.DefaultConfig()
	}

	// We will check the availability of certificates to confirm the TLS status
	if enableTLS {
		if !certutils.UserCertExists(certFile, keyFile) {
			// User certificates do not exist, extract from embedded resources
			certExists, err := certutils.EnsureCertsExist()
			if err != nil {
				fmt.Printf("Error ensuring certificates exist: %v\n", err)
			}
			enableTLS = certExists

		}
	}

	// Check if the certificate is valid
	enableTLS = certutils.IsValidCertificate(certFile)

	// Update configuration with command line flags
	if port != 0 {
		cfg.Port = port
	}
	cfg.EnableTLS = enableTLS
	cfg.CertFile = certFile
	cfg.KeyFile = keyFile

	// Save the configuration if it has changed
	if err := cfg.SaveConfig(); err != nil {
		fmt.Printf("Error saving configuration: %v\n", err)
	}

	// Print server header
	fmt.Println("====================================================")
	fmt.Println("                 LINQORA HOST SERVER                ")
	fmt.Println("====================================================")

	// Print server information
	fmt.Printf("TLS:         %t\n", enableTLS)
	fmt.Printf("Хост IP:     %s\n", deviceInfo.IP)
	fmt.Printf("Порт:        %d\n", cfg.Port)
	fmt.Printf("ОС:          %s\n", deviceInfo.OS)
	fmt.Println("====================================================")

	// Initialise the channel for authorisation requests
	authChan = make(chan interfaces.PendingAuthRequest, 10)

	// Initialise the authorisation manager
	authManager = auth.NewAuthManager(cfg, authChan)

	// Initialize the console authorization handler
	consoleHandler = auth.NewConsoleAuthHandler(authManager)

	// Create mDNS server configuration && and start it
	mdnsServer = mdns.NewMDNSServer(cfg)
	if err := mdnsServer.Start(); err != nil {
		fmt.Printf("Error starting mDNS server: %v\n", err)
		os.Exit(1)
	}

	// Initialize the Linqora Host server
	server := ws.NewWSServer(cfg, authManager)

	// Run the server in a separate goroutine
	go startCommandProcessor()

	// Create a context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())

	// Start the WebSocket server
	go func() {
		if err := server.Start(ctx); err != nil {
			log.Printf("WebSocket server error: %v", err)
			close(stopCh)
		}
	}()

	// Set up signal handling for graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)

	// Wait for a signal to stop the server
	select {
	case <-stopCh:
		fmt.Println("Server stop signal received...")
	case sig := <-sigCh:
		fmt.Printf("Signal %v received...\n", sig)
	}

	gracefulShutdown(cancel)
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
