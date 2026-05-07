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
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log/slog"
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
	stopOnce       sync.Once // prevents double-close panic on stopCh
	restart        = make(chan struct{})
	serverMu       sync.Mutex
	cfg            *config.ServerConfig
	consoleHandler *auth.ConsoleAuthHandler

	rootCmd = &cobra.Command{
		Use:   "linqorahost",
		Short: "Linqora Host is a server and management tool for Linqora Remote.",
		Long:  `Linqora is a comprehensive system for monitoring and remote control of computers.`,
	}

	serveCmd = &cobra.Command{
		Use:   "serve",
		Short: "Start the Linqora Host WebSocket server",
		Run:   runServer,
	}

	authCmd = &cobra.Command{
		Use:   "auth",
		Short: "Manage authorized devices and security",
	}

	configCmd = &cobra.Command{
		Use:   "config",
		Short: "Manage server configuration",
	}
)

var configShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Display current configuration",
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg, err := config.LoadConfig()
		if err != nil {
			return err
		}
		data, _ := json.MarshalIndent(cfg, "", "  ")
		fmt.Println(string(data))
		return nil
	},
}

var configSetCmd = &cobra.Command{
	Use:   "set <key> <value>",
	Short: "Update a configuration value",
	Long:  "Supported keys: port, e2ee (true/false), shared_secret",
	Args:  cobra.ExactArgs(2),
	RunE: func(cmd *cobra.Command, args []string) error {
		key := strings.ToLower(args[0])
		value := args[1]

		cfg, err := config.LoadConfig()
		if err != nil {
			return err
		}

		switch key {
		case "port":
			p, err := fmt.Sscanf(value, "%d", &cfg.Port)
			if err != nil || p != 1 {
				return fmt.Errorf("invalid port: %s", value)
			}
		case "e2ee":
			cfg.EnableE2EE = (value == "true" || value == "1" || value == "yes")
		case "shared_secret":
			cfg.SharedSecret = value
		default:
			return fmt.Errorf("unsupported configuration key: %s", key)
		}

		if err := cfg.SaveConfig(); err != nil {
			return err
		}
		fmt.Printf("Config %s updated to %s\n", key, value)
		return nil
	},
}

var deviceListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all authorized devices",
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg, err := config.LoadConfig()
		if err != nil {
			return fmt.Errorf("failed to load config: %w", err)
		}
		if len(cfg.AuthorizedDevs) == 0 {
			fmt.Println("No authorized devices.")
			return nil
		}
		fmt.Printf("%-36s  %-24s  %s\n", "Device ID", "Name", "Last Auth")
		fmt.Println(strings.Repeat("-", 80))
		for _, d := range cfg.AuthorizedDevs {
			fmt.Printf("%-36s  %-24s  %s\n", d.DeviceID, d.DeviceName, d.LastAuth)
		}
		return nil
	},
}

var deviceRevokeCmd = &cobra.Command{
	Use:   "revoke <device-id>",
	Short: "Revoke authorization for a device",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		deviceID := args[0]
		cfg, err := config.LoadConfig()
		if err != nil {
			return fmt.Errorf("failed to load config: %w", err)
		}
		if _, ok := cfg.AuthorizedDevs[deviceID]; !ok {
			return fmt.Errorf("device %q not found in authorized devices", deviceID)
		}
		delete(cfg.AuthorizedDevs, deviceID)
		if err := cfg.SaveConfig(); err != nil {
			return fmt.Errorf("failed to save config: %w", err)
		}
		fmt.Printf("Device %q revoked successfully.\n", deviceID)
		return nil
	},
}

var genSecretCmd = &cobra.Command{
	Use:   "gen-secret",
	Short: "Generate a new shared secret",
	RunE: func(cmd *cobra.Command, args []string) error {
		buf := make([]byte, 32)
		if _, err := rand.Read(buf); err != nil {
			return fmt.Errorf("failed to generate secret: %w", err)
		}
		secret := hex.EncodeToString(buf)

		cfg, err := config.LoadConfig()
		if err != nil {
			return fmt.Errorf("failed to load config: %w", err)
		}
		cfg.SharedSecret = secret
		if err := cfg.SaveConfig(); err != nil {
			return fmt.Errorf("failed to save config: %w", err)
		}

		fmt.Printf("New shared secret written to config:\n%s\n", secret)
		return nil
	},
}

func init() {
	serveCmd.Flags().IntVarP(&port, "port", "p", 0, "Port for LinqoraHost server (overrides config)")
	serveCmd.Flags().BoolP("notls", "s", false, "Disable TLS/SSL for LinqoraHost server")
	serveCmd.Flags().String("cert", "./certificates/dev_cert.pem", "Path to the TLS certificate file")
	serveCmd.Flags().String("key", "./certificates/dev_key.pem", "Path to the TLS key file")

	authCmd.AddCommand(deviceListCmd)
	authCmd.AddCommand(deviceRevokeCmd)
	authCmd.AddCommand(genSecretCmd)

	configCmd.AddCommand(configShowCmd)
	configCmd.AddCommand(configSetCmd)

	rootCmd.AddCommand(serveCmd)
	rootCmd.AddCommand(authCmd)
	rootCmd.AddCommand(configCmd)
}

// safeCloseStop closes stopCh exactly once; subsequent calls are no-ops.
func safeCloseStop() {
	stopOnce.Do(func() { close(stopCh) })
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

	// Stop the mDNS server
	if mdnsServer != nil {
		mdnsServer.Stop()
	}

	// Timeout for graceful shutdown
	shutdownTimeout := time.NewTimer(5 * time.Second)
	shutdownDone := make(chan struct{})

	go func() {
		// safeCloseStop is idempotent — safe even if the WS goroutine already closed it
		safeCloseStop()
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
	fmt.Printf("Host IP:     %s\n", deviceInfo.IP)
	fmt.Printf("Port:        %d\n", cfg.Port)
	fmt.Printf("OS:          %s\n", deviceInfo.OS)
	fmt.Println("====================================================")

	// Reinitialise stop primitives for this run
	stopCh = make(chan struct{})
	stopOnce = sync.Once{}

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
			slog.Error("WebSocket server error", "err", err)
			// Use safeCloseStop so that gracefulShutdown won't panic
			// if it also tries to close the channel.
			safeCloseStop()
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
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelInfo})))

	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
