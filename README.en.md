# SSTP VPN Setup

[🇷🇺 Русский](README.md) | **🇬🇧 English**

---

A single‑file tool to quickly set up an **SSTP VPN** client on Windows: it installs a root certificate into the trusted store and creates a VPN connection for the current user.

> This is a template for end‑user PCs. Before distributing, change the settings in the `SETTINGS` block below and put your own root certificate next to the script.

## Files

- `SSTP-Setup.cmd` — the whole tool: a `cmd` loader plus an embedded PowerShell body (one file).
- `Cert.crt` — a sample root certificate of the VPN server.


## Quick start

1. Put `SSTP-Setup.cmd` and the root certificate file into **the same folder**.
2. Make sure the certificate file name matches `$CertFileName` in the settings (default: `Cert.crt`).
3. Run `SSTP-Setup.cmd` by **double‑click**.
4. Click **Yes** on the UAC prompt — the certificate will be installed.
5. The VPN connection is created automatically for your account.
6. Open *Windows Settings → VPN* and connect using your login and password.

## Run scenarios

| Action | What happens |
| --- | --- |
| Double‑click | One UAC prompt → root certificate installed, then a VPN connection is created for the current user |
| “Run as administrator” | Installs **only** the certificate. Run again by double‑click to create the profile |
| UAC dismissed (“No”) | Setup stops, no VPN profile is created |
| Certificate file missing | A clear error is shown, no UAC prompt appears |

## Settings

Open `SSTP-Setup.cmd` (encoding **cp866**) and edit the block at the start of the PowerShell body:

```powershell
$VpnName      = 'VPN'           # VPN connection name
$VpnServer    = '1.1.1.1'  # SSTP server address (domain or IP)
$IdleTimeout  = 1800             # idle disconnect, seconds
$CertFileName = 'Cert.crt'       # root certificate file name next to the script
```

To make a copy for another server, change only this block; do not touch the `RUNNER` line or the `__PS_START__` marker line.

> **Encoding — important.** `SSTP-Setup.cmd` is saved as `cp866`, `CRLF`, without BOM. Do not save it with editors that write `UTF-8`, or the Cyrillic text will break.

## Certificate

- Place the **root certificate** that signed your SSTP server certificate next to the script.
- The certificate is installed to `LocalMachine\Root` (Trusted Root Certification Authorities). Keep the private key of the root only with the server administrator.
- The server must present a **leaf** certificate issued by this root.
- `Cert.crt` in this repository is only an example.

## How it works

- The script is a single file: a `cmd` part plus a PowerShell body after the `__PS_START__` marker.
- Double‑click launches an elevated copy to install the certificate (`certutil -addstore -f Root`), then the profile is created as the current user (`Add-VpnConnection` / `Set-VpnConnection`) so it belongs to that account and does not need admin rights.

## Troubleshooting

| Message / symptom | Cause & fix |
| --- | --- |
| “Certificate not found…” | The certificate file is missing or its name differs from `$CertFileName`. Place the file and retry |
| Error while installing the certificate | You dismissed UAC or the certificate is invalid. Check the file and retry |
| VPN does not connect | Check the server address, that the server presents a leaf certificate of this root, and that you have a login/password |
