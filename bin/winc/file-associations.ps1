<#
.SYNOPSIS
Add Winc to the "Open with" list for common code and text formats.

.DESCRIPTION
Registers a "Winc.Text" ProgID and an application entry under HKCU, then adds
that ProgID to OpenWithProgids for every listed extension. Nothing becomes the
default unless -SetDefault is passed, and Windows may still ask the user to
confirm the choice the first time.

.PARAMETER SetDefault
Also point the listed extensions at Winc. Previous defaults are recorded under
%LOCALAPPDATA%\winc-setup\defaults.json and restored by -Uninstall.

.PARAMETER Extensions
Extra extensions to register, for example -Extensions '.foo', '.bar'.

.PARAMETER Uninstall
Remove the ProgID, the application entry and every registration this script
added, and restore the recorded defaults.

.PARAMETER DryRun
Print the planned registry writes without changing anything.
#>
[CmdletBinding()]
param(
    [switch]$SetDefault,
    [switch]$Uninstall,
    [switch]$DryRun,
    [string[]]$Extensions = @()
)

$ErrorActionPreference = 'Stop'
$Registry = [Microsoft.Win32.Registry]::CurrentUser
$ProgId = 'Winc.Text'
$SetupDir = Join-Path $env:LOCALAPPDATA 'winc-setup'
$BackupFile = Join-Path $SetupDir 'defaults.json'

$BuiltInExtensions = @(
    '.txt', '.md', '.markdown', '.rst', '.log', '.csv', '.tsv',
    '.json', '.jsonc', '.json5', '.yaml', '.yml', '.toml', '.ini', '.cfg', '.conf', '.properties', '.env',
    '.xml', '.html', '.htm', '.css', '.scss', '.sass', '.less',
    '.js', '.mjs', '.cjs', '.jsx', '.ts', '.tsx', '.vue', '.svelte',
    '.py', '.pyi', '.rs', '.go', '.java', '.kt', '.kts', '.scala',
    '.c', '.h', '.cc', '.cpp', '.hpp', '.cs', '.fs', '.vb',
    '.php', '.rb', '.pl', '.lua', '.r', '.swift', '.dart',
    '.sh', '.bash', '.zsh', '.fish', '.ps1', '.psm1', '.bat', '.cmd',
    '.sql', '.graphql', '.proto', '.tex', '.bib', '.cmake', '.gradle',
    '.editorconfig', '.gitignore', '.gitattributes', '.dockerfile'
)
$Extensions = @(@($BuiltInExtensions) + @($Extensions) | Select-Object -Unique)

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
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [Microsoft.Win32.RegistryValueKind]$Kind = [Microsoft.Win32.RegistryValueKind]::String
    )
    if ($DryRun) {
        Write-Output ('set HKCU\{0} [{1}]' -f $Path, $Name)
        return
    }
    $key = $Registry.CreateSubKey($Path)
    try { $key.SetValue($Name, $Value, $Kind) } finally { $key.Close() }
}

function Get-RegistryDefault {
    param([string]$Path)
    $key = $Registry.OpenSubKey($Path, $false)
    if ($null -eq $key) { return $null }
    try { return [string]$key.GetValue('') } finally { $key.Close() }
}

function Remove-RegistryTree {
    param([string]$Path)
    if ($DryRun) {
        Write-Output ('delete HKCU\{0}' -f $Path)
        return
    }
    $Registry.DeleteSubKeyTree($Path, $false)
}

function Remove-RegistryValue {
    param([string]$Path, [string]$Name)
    if ($DryRun) {
        Write-Output ('delete HKCU\{0} [{1}]' -f $Path, $Name)
        return
    }
    $key = $Registry.OpenSubKey($Path, $true)
    if ($null -ne $key) {
        try { $key.DeleteValue($Name, $false) } finally { $key.Close() }
    }
}

function Read-Defaults {
    if (-not (Test-Path -LiteralPath $BackupFile)) { return @{} }
    $data = Get-Content -LiteralPath $BackupFile -Raw | ConvertFrom-Json
    $map = @{}
    foreach ($property in $data.PSObject.Properties) { $map[$property.Name] = [string]$property.Value }
    return $map
}

function Write-Defaults {
    param([hashtable]$Map)
    if ($DryRun) { return }
    New-Item -ItemType Directory -Force -Path $SetupDir | Out-Null
    $object = [ordered]@{}
    foreach ($key in ($Map.Keys | Sort-Object)) { $object[$key] = $Map[$key] }
    $object | ConvertTo-Json | Set-Content -LiteralPath $BackupFile -Encoding UTF8
}

if ($Uninstall) {
    $defaults = Read-Defaults
    Remove-RegistryTree 'Software\Classes\Winc.Text'
    Remove-RegistryTree 'Software\Classes\Applications\winc.exe'
    foreach ($ext in $Extensions) {
        Remove-RegistryValue ('Software\Classes\{0}\OpenWithProgids' -f $ext) $ProgId
        if ($defaults.ContainsKey($ext) -and (Get-RegistryDefault ('Software\Classes\{0}' -f $ext)) -eq $ProgId) {
            Set-RegistryValue ('Software\Classes\{0}' -f $ext) '' $defaults[$ext]
        }
    }
    if (-not $DryRun -and (Test-Path -LiteralPath $BackupFile)) {
        Remove-Item -LiteralPath $BackupFile -Force
    }
    $verb = if ($DryRun) { 'Would remove' } else { 'Removed' }
    Write-Output ($verb + ' the Winc file associations.')
    return
}

$winc = Resolve-WincExe
$command = '"' + $winc + '" "%1"'
Set-RegistryValue 'Software\Classes\Winc.Text' '' 'Text file'
Set-RegistryValue 'Software\Classes\Winc.Text\DefaultIcon' '' ($winc + ',0')
Set-RegistryValue 'Software\Classes\Winc.Text\shell\open\command' '' $command
Set-RegistryValue 'Software\Classes\Applications\winc.exe\shell\open\command' '' $command

$defaults = Read-Defaults
foreach ($ext in $Extensions) {
    Set-RegistryValue ('Software\Classes\{0}\OpenWithProgids' -f $ext) $ProgId ([byte[]]@()) ([Microsoft.Win32.RegistryValueKind]::None)
    Set-RegistryValue 'Software\Classes\Applications\winc.exe\SupportedTypes' $ext ''
    if ($SetDefault) {
        if (-not $defaults.ContainsKey($ext)) {
            $current = Get-RegistryDefault ('Software\Classes\{0}' -f $ext)
            $defaults[$ext] = if ([string]::IsNullOrEmpty($current)) { '' } else { $current }
        }
        Set-RegistryValue ('Software\Classes\{0}' -f $ext) '' $ProgId
    }
}
if ($SetDefault) { Write-Defaults $defaults }

$suffix = if ($SetDefault) { ' and made it the default where Windows allows it' } else { '' }
$verb = if ($DryRun) { 'Would add' } else { 'Added' }
Write-Output ($verb + ' Winc to the "Open with" list for ' + $Extensions.Count + ' extensions' + $suffix + '.')
if ($SetDefault) {
    Write-Output 'Windows may ask you to confirm the default the first time; use "Choose another app" if the old default stays.'
}
