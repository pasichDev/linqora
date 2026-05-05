# Linqora Host — Setup Guide

## Requirements

| Component   | Minimum version |
|-------------|----------------|
| Go          | 1.21           |
| Flutter     | 3.19           |
| Android     | API 26 (8.0)   |
| OS (host)   | Windows 10, Ubuntu 20.04, or macOS 12 |

**Optional CLI tools** (needed for specific features on Linux/macOS):

| Tool         | Feature            | Install                          |
|--------------|--------------------|----------------------------------|
| `xdotool`    | Mouse & media keys | `sudo apt install xdotool`       |
| `playerctl`  | Media info (Linux) | `sudo apt install playerctl`     |
| `amixer`     | Volume (Linux)     | `sudo apt install alsa-utils`    |
| `cliclick`   | Mouse (macOS)      | `brew install cliclick`          |

---

## 1. Build & Run the Host (LinqoraHost)

```bash
git clone https://github.com/pasichDev/linqora.git
cd linqora/LinqoraHost
go build -o linqorahost ./cmd/
```

### First run (auto-generates TLS certificate)

```bash
./linqorahost
```

The server starts on port **8070** with TLS enabled. On first launch it generates a self-signed certificate under `./certificates/`.

### Flags

```
./linqorahost [flags]

Flags:
  -p, --port int     Listening port (default 8070)
  -s, --notls        Disable TLS (plain WebSocket — not recommended)
      --cert string  Path to TLS certificate (default ./certificates/dev_cert.pem)
      --key  string  Path to TLS private key  (default ./certificates/dev_key.pem)
```

---

## 2. Device Management Commands

These commands do **not** start the server — they only read/modify the config.

### List authorised devices

```bash
./linqorahost device-list
```

### Revoke a device

```bash
./linqorahost device-revoke <device-id>
```

### Generate a shared secret (HMAC authentication)

```bash
./linqorahost gen-secret
```

This writes a 32-byte random secret to `~/.config/linqora/linqora_config.json` and prints it. Enter the same secret in the Linqora Remote app under **Settings → Shared Secret**.

---

## 3. Scripts (Task Scheduler)

Create `~/.config/linqora/scripts.json`:

```json
[
  {
    "id": "backup",
    "name": "Daily Backup",
    "description": "Runs the backup script",
    "command": "/usr/local/bin/backup.sh",
    "args": [],
    "work_dir": "/home/user"
  }
]
```

Fields:
- `id` — unique identifier used by the remote app
- `command` — absolute path to the executable
- `args` — fixed arguments (never user-supplied)
- `work_dir` — working directory (optional)

Scripts are executed with a **30-second timeout**. Clients cannot inject arbitrary commands — they only pass a registered `id`.

---

## 4. Build & Run the Remote App (linqoraremote)

```bash
cd linqora/linqoraremote
flutter pub get
flutter run
```

Or build a release APK:

```bash
flutter build apk --release
```

The APK is at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 5. Connecting for the First Time

1. Start `linqorahost` on the PC.
2. Ensure the PC and phone are on the **same Wi-Fi network**.
3. Open the app — it auto-discovers the host via mDNS.
4. Tap the host, then tap **Connect**.
5. The host console shows:
   ```
   Auth request from "My Phone" (192.168.1.5)
   Approve? [y/n]:
   ```
   Type `y` and press Enter.
6. The app is now connected.

### Passwordless HMAC authentication

If you ran `gen-secret` and entered the secret in the app, step 5 is skipped — authentication happens automatically via HMAC challenge-response.

---

## 6. TLS Certificate

By default a self-signed certificate is used. The app uses **TOFU (Trust On First Use)**: on first connection it pins the certificate's SHA-256 fingerprint. Subsequent connections verify against the stored pin.

To use your own certificate:

```bash
./linqorahost --cert /path/to/cert.pem --key /path/to/key.pem
```

---

## 7. Running as a Service

### systemd (Linux)

Create `/etc/systemd/system/linqorahost.service`:

```ini
[Unit]
Description=Linqora Host
After=network-online.target

[Service]
ExecStart=/usr/local/bin/linqorahost
Restart=on-failure
User=youruser
Environment=HOME=/home/youruser

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable --now linqorahost
```

### Windows Task Scheduler

Create a basic task that runs `linqorahost.exe` at logon for your user account.

---

## 8. Firewall

Open TCP port **8070** (or your custom port) for inbound connections from the local network.

**Linux (ufw)**
```bash
sudo ufw allow 8070/tcp
```

**Windows**
```powershell
netsh advfirewall firewall add rule name="LinqoraHost" dir=in action=allow protocol=TCP localport=8070
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| App can't find the host | Check same Wi-Fi, firewall open, mDNS not blocked by router |
| TLS handshake error | Delete pinned cert in app Settings, reconnect to re-pin |
| Mouse not working on Linux | Install `xdotool` |
| Mouse not working on macOS | Install `cliclick` (`brew install cliclick`) |
| Media info missing on Linux | Install `playerctl` |
| High latency mouse | Reduce sensitivity in the app touchpad view |
