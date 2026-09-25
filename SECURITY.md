# Security Policy

## Supported Versions

None. Linqora is archived and receives no security updates.

## Known issues (will not be fixed)

- With no shared secret configured (the default), the REST API under `/api/v1` is not
  authenticated: any device on the local network can control power, processes, keyboard input,
  media and scripts.
- A paired device is recognised by its device id alone; no per-device secret is issued.
- The TLS certificate and private key shipped with the host are public, and the host falls
  back to plain `ws://` when the certificate is missing or invalid.
- The optional AES-256-GCM message encryption is off by default and not implemented in the
  mobile client.

Run Linqora only on a network you fully trust, or not at all.
