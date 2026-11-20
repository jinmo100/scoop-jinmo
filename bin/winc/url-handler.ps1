<#
.SYNOPSIS
Register a winc:// URL protocol that opens a folder or file in Winc.

.DESCRIPTION
Writes a small PowerShell helper under %LOCALAPPDATA%\winc-setup and points
HKCU\Software\Classes\winc at it. Links of the form
winc://open/?path=/home/user/project (or C:/Users/... ) then open in Winc.

WSL paths are mapped to \\wsl.localhost\<distro>\... using the first
distribution returned by wsl.exe -l -q. This is what DSH's better-sidebar
custom editor needs (name Winc, template winc://open/?path={path}).

.PARAMETER Uninstall
Remove the protocol registration and the helper script.

.PARAMETER DryRun
Print the planned registry writes without changing anything.
#>
[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Registry = [Microsoft.Win32.Registry]::CurrentUser
$SetupDir = Join-Path $env:LOCALAPPDATA 'winc-setup'
$HelperPath = Join-Path $SetupDir 'winc-open.ps1'

function Resolve-WincExe {
    $command = Get-Command winc -ErrorAction SilentlyContinue
    $path = if ($null -ne $command) { $command.Source } else { $null }
    if ([string]::IsNullOrEmpty($path) -and -not [string]::IsNullOrEmpty($env:SCOOP)) {
        $candidate = Join-Path $env:SCOOP 'apps\winc\current\winc.exe'
        if (Test-Path -LiteralPath $candidate) { $path = $candidate }
    }
    if ([string]::IsNullOrEmpty($path) -or -not (Test-Path -LiteralPath $path)) {
        throw 'winc.exe was not found. Install it first: scoop install jinmo/winc'
    }
    $shimPrefix = if ([string]::IsNullOrEmpty($env:SCOOP)) { $null } else { Join-Path $env:SCOOP 'shims\' }
    if ($null -ne $shimPrefix -and $path.StartsWith($shimPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $real = Join-Path $env:SCOOP 'apps\winc\current\winc.exe'
        if (Test-Path -LiteralPath $real) { $path = $real }
    }
    # Fall back to the directory layout when SCOOP is not exported in this shell.
    if ($path -match '\\shims\\[^\\]+$') {
        $scoopRoot = Split-Path -Parent (Split-Path -Parent $path)
        $real = Join-Path $scoopRoot 'apps\winc\current\winc.exe'
        if (Test-Path -LiteralPath $real) { $path = $real }
    }
    return (Resolve-Path -LiteralPath $path).Path
}

function Set-RegistryValue {
    param([string]$Path, [string]$Name, [object]$Value)
    if ($DryRun) {
        Write-Output ('set HKCU\{0} [{1}] = {2}' -f $Path, $Name, $Value)
        return
    }
    $key = $Registry.CreateSubKey($Path)
    try { $key.SetValue($Name, $Value) } finally { $key.Close() }
}

function Remove-RegistryTree {
    param([string]$Path)
    if ($DryRun) {
        Write-Output ('delete HKCU\{0}' -f $Path)
        return
    }
    $Registry.DeleteSubKeyTree($Path, $false)
}

$helper = @'
param([Parameter(Mandatory = $true)][string]$Url)
$ErrorActionPreference = 'Stop'
if ($Url -notmatch '^winc://open/?\?path=(.+)$') { exit 1 }
$path = $Matches[1]
try { $path = [Uri]::UnescapeDataString($path) } catch { }
$path = $path -replace '[?#].*$', ''
if ($path -match '^/') {
    $distro = ''
    try {
        $raw = (wsl.exe -l -q 2>$null | Where-Object { $_ -match '\S' } | Select-Object -First 1)
        if ($null -ne $raw) { $distro = $raw.Replace([string][char]0, '').Trim() }
    } catch { }
    if ([string]::IsNullOrEmpty($distro)) { $distro = 'Ubuntu' }
    $path = '\\wsl.localhost\' + $distro + ($path -replace '/', '\')
} elseif ($path -match '^[A-Za-z]:/') {
    $path = $path -replace '/', '\'
}
Start-Process -FilePath '__WINC__' -ArgumentList @('"' + $path + '"')
'@

if ($Uninstall) {
    Remove-RegistryTree 'Software\Classes\winc'
    if (-not $DryRun) {
        if (Test-Path -LiteralPath $HelperPath) { Remove-Item -LiteralPath $HelperPath -Force }
        if ((Test-Path -LiteralPath $SetupDir) -and -not (Get-ChildItem -LiteralPath $SetupDir -Force)) {
            Remove-Item -LiteralPath $SetupDir -Force
        }
    }
    $verb = if ($DryRun) { 'Would remove' } else { 'Removed' }
    Write-Output ($verb + ' the winc:// protocol handler.')
    return
}

$winc = Resolve-WincExe
$helper = $helper.Replace('__WINC__', $winc.Replace("'", "''"))
if ($DryRun) {
    Write-Output ('write {0}' -f $HelperPath)
} else {
    New-Item -ItemType Directory -Force -Path $SetupDir | Out-Null
    Set-Content -LiteralPath $HelperPath -Value $helper -Encoding UTF8
}

$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$command = '"' + $powershell + '" -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $HelperPath + '" "%1"'
Set-RegistryValue 'Software\Classes\winc' '' 'URL:Winc Protocol'
Set-RegistryValue 'Software\Classes\winc' 'URL Protocol' ''
Set-RegistryValue 'Software\Classes\winc\shell\open\command' '' $command
$verb = if ($DryRun) { 'Would register' } else { 'Registered' }
Write-Output ($verb + ' winc:// -> ' + $HelperPath)
Write-Output 'Use winc://open/?path={path} as a custom editor in DSH: Settings -> Side card -> Open with.'
