<#
.SYNOPSIS
Add or remove an "Open with Winc" entry in the Windows Explorer context menu.

.DESCRIPTION
The entry is registered for folders, the empty area of a folder window and
files. Everything is written under HKCU, so no elevation is required and the
change is limited to the current user.

On Windows 11 the entry appears under "Show more options" (Shift+F10), because
it is a classic registry verb rather than the new IExplorerCommand format.

.PARAMETER Uninstall
Remove the entries added by this script.

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

# %1 is the selected item; %V is the folder shown in the window, for the
# background menu of a folder view.
$entries = @(
    @{ Key = 'Software\Classes\Directory\shell\Winc'; Verb = '%1' },
    @{ Key = 'Software\Classes\Directory\Background\shell\Winc'; Verb = '%V' },
    @{ Key = 'Software\Classes\*\shell\Winc'; Verb = '%1' }
)

if ($Uninstall) {
    foreach ($entry in $entries) { Remove-RegistryTree $entry.Key }
    $verb = if ($DryRun) { 'Would remove' } else { 'Removed' }
    Write-Output ($verb + ' the "Open with Winc" context menu entries.')
    return
}

$winc = Resolve-WincExe
foreach ($entry in $entries) {
    Set-RegistryValue $entry.Key '' 'Open with Winc'
    Set-RegistryValue $entry.Key 'Icon' ($winc + ',0')
    Set-RegistryValue ($entry.Key + '\command') '' ('"' + $winc + '" "' + $entry.Verb + '"')
}
$verb = if ($DryRun) { 'Would add' } else { 'Added' }
Write-Output ($verb + ' "Open with Winc" for folders, folder backgrounds and files using ' + $winc)
Write-Output 'On Windows 11 the entry lives under "Show more options" (Shift+F10).'
