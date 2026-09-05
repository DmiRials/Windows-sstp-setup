# SSTP VPN Setup

[🇬🇧 English](README.en.md) | [🇷🇺 Русский](README.md)

A single-file tool for quickly setting up an **SSTP VPN** client on Windows. It installs a root certificate into the trusted store and creates a VPN connection for the current user.

> This template is intended for personal PCs. Before distributing it, change the settings in the `Settings` block and place your own root certificate next to the script.

## Files

- `SSTP-Setup.cmd` - the whole tool: a `cmd` loader plus an embedded PowerShell body in one file.
- `Cert.crt` - an example root certificate for the VPN server.

## Quick start

1. Put `SSTP-Setup.cmd` and the root certificate file into the **same folder**.
2. Make sure the certificate file name matches `$CertFileName` in the settings (default: `Cert.crt`).
3. Run `SSTP-Setup.cmd` by **double-clicking** it.
4. Click **Yes** on the UAC prompt to install the certificate.
5. The VPN connection is created automatically for your account.
6. Open *Windows Settings > VPN* and connect using your username and password.

## Run scenarios

| Action | Result |
| --- | --- |
| Double-click | One UAC prompt appears, the root certificate is installed, and the VPN connection is created for the current user |
| Run as administrator | Only the certificate is installed. Double-click the file again to create the profile |
| UAC dismissed | Setup stops and no VPN profile is created |
| Certificate file missing | A clear error is shown and no UAC prompt appears |

## Settings

Open `SSTP-Setup.cmd` and edit the block at the start of the PowerShell body:

```powershell
$VpnName      = 'VPN'           # VPN connection name
$VpnServer    = '1.1.1.1'       # SSTP server address (domain or IP)
$IdleTimeout  = 1800            # Idle disconnect timeout, in seconds
$CertFileName = 'Cert.crt'      # Root certificate file name next to the script
```

To make a copy for another server, change only this block. Do not modify the `RUNNER` line or the `__PS_START__` marker line.

The whole file is plain English text (ASCII), so there are no encoding issues: you can save it in any encoding, UTF-8 is fine.

## Certificate

- Keep the **root certificate** that signed your SSTP server certificate next to the script.
- The certificate is installed to `LocalMachine\Root` (Trusted Root Certification Authorities). Keep the root certificate's private key only with the server administrator.
- The server must present a **leaf** certificate issued by this root.
- The `Cert.crt` file in this repository is only an example.

## How it works

- The script is a single file: a `cmd` part plus a PowerShell body after the `__PS_START__` marker.
- Double-clicking launches an elevated copy to install the certificate with `certutil -addstore -f Root`, then creates the profile as the current user with `Add-VpnConnection` or `Set-VpnConnection`. The profile belongs to that user and does not require administrator rights.

## Troubleshooting

| Message or symptom | Cause and fix |
| --- | --- |
| Certificate not found | The certificate file is missing or its name differs from `$CertFileName`. Place the file next to the script and try again |
| Error installing the certificate | UAC was dismissed or the certificate is invalid. Check the file and try again |
| VPN does not connect | Check the server address, confirm the server presents a leaf certificate from this root, and verify your username and password |
