# Linqora Host

<div align="center">
<img src="../docs/assets/logo_linqora.png" alt="Linqora Logo" width="200"/>

**Server component of Linqora — smart interaction with your computer.**

</div>

---

## About

Linqora Host is a server application that runs on your computer and enables remote interaction with your device from the Linqora Remote mobile application.

### Features

- 🔒 **End-to-End Encryption (E2EE)**: All communication is encrypted with AES-256-GCM.
- 🖥️ **Multi-Monitor Management**: Enumerate and control your displays remotely.
- 📁 **Remote File Browser**: Browse and download files from your computer securely.
- 🐚 **Modular CLI**: Powerful command-line interface for configuration and management.
- 🔒 **Secure Auth**: Token-based authentication with mDNS discovery.
- 🔌 **WebSocket API**: High-performance real-time communication.

### Requirements

- **Windows**: Full support for all features (including monitor control).
- **Linux**: Supported (some hardware-specific features like monitors may vary).
- **macOS**: Supported.

### Installation

#### Pre-built binaries

1. Download the latest release for your platform from the [Releases](https://github.com/pasichDev/linqora/releases) page.
2. Extract the archive.
3. Run the `linqora` executable.

#### Building from source

```bash
# Clone the repository
git clone https://github.com/pasichDev/linqora.git

# Navigate to the host directory
cd linqora/LinqoraHost

# Build the CLI
go build -o linqora ./cmd/linqora_cli.go
```

### Usage

The application uses a modular CLI. Run `linqora --help` to see all options.

#### Start the server
```bash
linqora serve
```

#### Configuration
```bash
# Show current config
linqora config show

# Set a value
linqora config set server.port 8081
```

#### Authorization management
```bash
# List authorized devices
linqora auth list

# Revoke a device
linqora auth revoke <device_id>
```

## API Documentation

See [API.md](./docs/API.md) for detailed WebSocket protocol information.

## License

MIT © [pasichDev](https://github.com/pasichDev)
