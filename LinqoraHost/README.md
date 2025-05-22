# Linqora Host

<div align="center">
<img src="../docs/logo_linqora.png" alt="Linqora Logo" width="200"/>

**Server component of Linqora — smart interaction with your computer.**

</div>

---

## About

Linqora Host is a server application that runs on your computer and enables remote interaction with your device from the Linqora Remote mobile application.

### Features

- 🔒 Secure authentication system
- 🌐 Local network discovery via mDNS
- 🔌 WebSocket-based communication


### Requirements

- **Linux**: Modern distribution with systemd (Ubuntu 20.04+, Fedora 32+, etc.)
- **Windows**: Expected
- **macOS**: Expected


### Installation

#### Pre-built binaries

1. Download the latest release for your platform from the [Releases](https://github.com/pasichDev/linqora/releases) page
2. Extract the archive
3. Run the executable

#### Building from source

```bash
# Clone the repository
git clone https://github.com/pasichDev/linqora.git

# Navigate to the host directory
cd linqora/LinqoraHost

# Build for your platform
go build ./cmd/linqora_cli.go

```

### Usage

1. Launch the Linqora Host application on your computer
2. Install and open Linqora Remote on your mobile device
3. Connect to your computer through the mobile application
4. Authenticate the connection when prompted on your computer

## API Documentation

Detailed API documentation will be provided separately.

## License

MIT © [pasichDev](https://github.com/pasichDev)
