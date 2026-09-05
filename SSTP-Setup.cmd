@echo off
setlocal

rem ============================================================
rem                  SSTP VPN Setup
rem
rem  How to use:
rem    1. Place this file in the same folder as the certificate.
rem    2. Run the script, then approve the UAC prompt.
rem    3. Wait until the setup completes.
rem ============================================================

title SSTP VPN Setup

set "SSTP_SELF=%~f0"
set "RUNNER=$t=[IO.File]::ReadAllText($env:SSTP_SELF);$i=$t.IndexOf([string][char]10+'__PS_START__');if($i -lt 0){Write-Host 'Marker not found';exit 2};Invoke-Expression $t.Substring($i+14)"

net session >nul 2>&1
if %errorlevel% equ 0 goto elevated

goto normal

:elevated
if /i "%~1"=="cert" goto certworker
echo.
echo This window is running with administrator privileges.
echo To create the VPN connection for the current user,
echo run this file by double-clicking it instead.
echo.
echo Only the root certificate will be installed now.
echo.
set "SSTP_TASK=cert"
powershell -NoProfile -ExecutionPolicy Bypass -Command "%RUNNER%"
set EXITCODE=%errorlevel%
echo.
pause
exit /b %EXITCODE%

:certworker
set "SSTP_TASK=cert"
powershell -NoProfile -ExecutionPolicy Bypass -Command "%RUNNER%"
set EXITCODE=%errorlevel%
exit /b %EXITCODE%

:normal
set "SSTP_TASK=precheck"
powershell -NoProfile -ExecutionPolicy Bypass -Command "%RUNNER%"
if not "%errorlevel%"=="0" goto certmissing
set "SSTP_TASK="
echo Installing the root certificate...
echo Click "Yes" if the UAC prompt appears.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $p = Start-Process -FilePath '%~f0' -ArgumentList 'cert' -Verb RunAs -Wait -PassThru -ErrorAction Stop; if (-not $p) { exit 1 }; exit $p.ExitCode } catch { exit 1 }"
set CERTOK=%errorlevel%
if not "%CERTOK%"=="0" goto certfail
echo.
echo The certificate has been installed.
echo Creating the VPN connection for the current user...
echo.
set "SSTP_TASK="
powershell -NoProfile -ExecutionPolicy Bypass -Command "%RUNNER%"
set EXITCODE=%errorlevel%
if not "%EXITCODE%"=="0" goto vpnfail
echo.
echo Done.
pause
exit /b 0

:certmissing
echo.
echo The certificate was not found in the same folder as the script.
echo VPN setup has been canceled.
pause
exit /b 1

:certfail
echo.
echo Failed to install the root certificate.
echo Make sure you approve the UAC prompt and that the certificate file is valid.
echo.
pause
exit /b 1

:vpnfail
echo.
echo Failed to create the VPN connection.
echo.
pause
exit /b 1

__PS_START__
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $env:SSTP_SELF

# -------------------- Settings --------------------
$VpnName      = 'VPN'
$VpnServer    = '1.1.1.1'
$IdleTimeout  = 1800
$CertFileName = 'Cert.crt'
# -------------------------------------------------

$CertFile = Join-Path -Path $ScriptDir -ChildPath $CertFileName

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($env:SSTP_TASK -eq 'precheck') {
    if (-not (Test-Path -LiteralPath $CertFile)) {
        Write-Host ''
        Write-Host 'Error: the certificate file was not found in the same folder as the script:'
        Write-Host "  $CertFile"
        Write-Host ''
        Write-Host 'Make sure the certificate is placed in the same folder as this file'
        Write-Host 'and that its name matches the value of the $CertFileName variable'
        Write-Host 'in the settings block of this file.'
        exit 1
    }
    exit 0
}

if ($env:SSTP_TASK -eq 'cert') {
    try {
        if (-not (Test-Administrator)) {
            throw 'The certificate step must be run with administrator privileges.'
        }
        if (-not (Test-Path -LiteralPath $CertFile)) {
            throw "The certificate file was not found in the same folder as the script: $CertFile"
        }
        Write-Host 'Installing the root certificate...'
        & certutil.exe -addstore -f Root $CertFile
        if ($LASTEXITCODE -ne 0) {
            throw "certutil failed with exit code $LASTEXITCODE"
        }
        Write-Host 'The root certificate has been installed.'
        exit 0
    } catch {
        Write-Host ''
        Write-Host "Error: $($_.Exception.Message)"
        exit 1
    }
}

try {
    $existing = Get-VpnConnection -Name $VpnName -ErrorAction SilentlyContinue
    if ($existing) {
        Set-VpnConnection -Name $VpnName -ServerAddress $VpnServer -TunnelType SSTP -EncryptionLevel Required -AuthenticationMethod MSChapv2 -SplitTunneling $true -IdleDisconnectSeconds $IdleTimeout -RememberCredential $true -Force
    } else {
        Add-VpnConnection -Name $VpnName -ServerAddress $VpnServer -TunnelType SSTP -EncryptionLevel Required -AuthenticationMethod MSChapv2 -SplitTunneling -IdleDisconnectSeconds $IdleTimeout -RememberCredential -Force
    }

    Write-Host ''
    Write-Host 'The connection has been configured.'
    Write-Host "VPN connection `"$VpnName`" has been created for the current user."
    Write-Host 'Open Windows Settings > VPN and connect using your login and password.'
} catch {
    Write-Host ''
    Write-Host "Error: $($_.Exception.Message)"
    exit 1
}