@echo off
chcp 866 >nul
setlocal

rem ============================================================
rem                ШАБЛОН НАСТРОЙКИ SSTP VPN
rem
rem Как использовать:
rem   1. Положите этот файл рядом с корневым сертификатом.
rem   2. Заполните настройки в разделе "НАСТРОЙКИ" ниже.
rem   3. Запустите файл двойным кликом.
rem      Корневой сертификат установится с правами администратора
rem      (появится запрос UAC - нажмите "Да").
rem      VPN-подключение создастся для текущего пользователя.
rem ============================================================

title Настройка SSTP VPN

set "SSTP_SELF=%~f0"
set "RUNNER=$enc=[Text.Encoding]::GetEncoding(866);$c=[IO.File]::ReadAllText($env:SSTP_SELF,$enc);$nl=[char]10;$m=$c.IndexOf($nl+'__PS_START__');if($m -lt 0){Write-Host 'Marker not found';exit 2};Invoke-Expression $c.Substring($m+$nl.Length+'__PS_START__'.Length)"

net session >nul 2>&1
if %errorlevel% equ 0 goto elevated

goto normal

:elevated
if /i "%~1"=="cert" goto certworker
echo.
echo Файл запущен от имени администратора.
echo Чтобы VPN-подключение было создано для ВАШЕЙ учетной записи,
echo закройте это окно и запустите файл обычным двойным кликом.
echo.
echo Сейчас будет установлен только корневой сертификат.
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
echo Установка корневого сертификата...
echo Если появится запрос UAC - нажмите "Да".
echo.
powershell -NoProfile -Command "try { $p = Start-Process -FilePath '%~f0' -ArgumentList 'cert' -Verb RunAs -Wait -PassThru -ErrorAction Stop; if (-not $p) { exit 1 }; exit $p.ExitCode } catch { exit 1 }"
set CERTOK=%errorlevel%
if not "%CERTOK%"=="0" goto certfail
echo.
echo Сертификат установлен.
echo Настройка VPN-подключения для текущего пользователя...
echo.
set "SSTP_TASK="
powershell -NoProfile -ExecutionPolicy Bypass -Command "%RUNNER%"
set EXITCODE=%errorlevel%
if not "%EXITCODE%"=="0" goto vpnfail
echo.
echo Готово.
pause
exit /b 0

:certmissing
echo.
echo Сертификат из блока "НАСТРОЙКИ" не найден рядом со скриптом.
echo Настройка VPN отменена.
pause
exit /b 1

:certfail
echo.
echo Не удалось установить корневой сертификат.
echo Возможно, вы отклонили запрос UAC или файл сертификата отсутствует.
echo.
pause
exit /b 1

:vpnfail
echo.
echo Не удалось настроить VPN-подключение.
echo.
pause
exit /b 1

__PS_START__
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $env:SSTP_SELF

# -------------------- НАСТРОЙКИ --------------------
$VpnName      = 'VPN'
$VpnServer    = '1.1.1.1'
$IdleTimeout  = 1800
$CertFileName = 'Cert.crt'
# ---------------------------------------------------

$CertFile = Join-Path -Path $ScriptDir -ChildPath $CertFileName

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($env:SSTP_TASK -eq 'precheck') {
    if (-not (Test-Path -LiteralPath $CertFile)) {
        Write-Host ''
        Write-Host 'Ошибка: файл сертификата не найден рядом со скриптом:'
        Write-Host "  $CertFile"
        Write-Host ''
        Write-Host 'Проверьте, что сертификат лежит в одной папке с этим файлом'
        Write-Host 'и что его имя совпадает со значением $CertFileName'
        Write-Host 'в блоке "НАСТРОЙКИ" внутри файла.'
        exit 1
    }
    exit 0
}

if ($env:SSTP_TASK -eq 'cert') {
    try {
        if (-not (Test-Administrator)) {
            throw 'Сценарий должен быть запущен от имени администратора.'
        }
        if (-not (Test-Path -LiteralPath $CertFile)) {
            throw "Файл сертификата не найден рядом со скриптом: $CertFile"
        }
        Write-Host 'Установка корневого сертификата...'
        & certutil.exe -addstore -f Root $CertFile
        if ($LASTEXITCODE -ne 0) {
            throw "certutil завершился с кодом $LASTEXITCODE"
        }
        Write-Host 'Корневой сертификат установлен.'
        exit 0
    } catch {
        Write-Host ''
        Write-Host "Ошибка: $($_.Exception.Message)"
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
    Write-Host 'Настройка завершена.'
    Write-Host "VPN-подключение `"$VpnName`" создано или обновлено."
    Write-Host 'Откройте Параметры Windows > VPN и подключитесь, введя логин и пароль.'
} catch {
    Write-Host ''
    Write-Host "Ошибка: $($_.Exception.Message)"
    exit 1
}
