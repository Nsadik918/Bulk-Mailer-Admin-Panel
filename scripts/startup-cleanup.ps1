[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$BackupRoot = 'D:\StartupBackups'
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "[startup-cleanup] $Message" -ForegroundColor Cyan
}

function Get-RegistryValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    $item = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
    if (-not $item) {
        return $null
    }

    $property = $item.PSObject.Properties[$Name]
    if (-not $property) {
        return $null
    }

    return $property.Value
}

function Disable-RunValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = Get-RegistryValue -Path $Path -Name $Name
    if ($null -eq $value) {
        return
    }

    $script:backup.RunValues.Add([pscustomobject]@{
        Path  = $Path
        Name  = $Name
        Value = [string]$value
    })

    if ($PSCmdlet.ShouldProcess("$Path :: $Name", 'Remove startup Run entry')) {
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        Write-Host "  removed Run entry $Name"
    }
}

function Disable-StartupApprovedValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = Get-RegistryValue -Path $Path -Name $Name
    if ($null -eq $value) {
        return
    }

    $bytes = [byte[]]$value
    $script:backup.StartupApproved.Add([pscustomobject]@{
        Path        = $Path
        Name        = $Name
        ValueBase64 = [Convert]::ToBase64String($bytes)
    })

    if ($PSCmdlet.ShouldProcess("$Path :: $Name", 'Remove StartupApproved entry')) {
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    }
}

function Disable-ServiceStartup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $service = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
    if (-not $service) {
        return
    }

    $script:backup.Services.Add([pscustomobject]@{
        Name      = $service.Name
        StartMode = $service.StartMode
        State     = $service.State
    })

    if ($PSCmdlet.ShouldProcess($service.Name, 'Disable service startup')) {
        try {
            Set-Service -Name $service.Name -StartupType Disabled
            Write-Host "  disabled service $($service.Name)"
        } catch {
            Write-Warning "Could not disable service $($service.Name): $($_.Exception.Message)"
        }
    }
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $BackupRoot "startup-cleanup-$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$script:backup = [ordered]@{
    CreatedAt       = (Get-Date).ToString('o')
    ComputerName    = $env:COMPUTERNAME
    BackupDirectory = $backupDir
    RunValues       = [System.Collections.Generic.List[object]]::new()
    StartupApproved = [System.Collections.Generic.List[object]]::new()
    Services        = [System.Collections.Generic.List[object]]::new()
}

$runEntries = @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'Opera Stable' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'Opera GX Stable' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'tawk.to' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'NZXT.CAM' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'NVIDIA Broadcast ' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'WebSocketServer23420' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'SignalRgb' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'electron.app.BlueStacks Services' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'Teams' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'Grammarly' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'MicrosoftEdgeAutoLaunch_25DA60072EA599DA62911C1F505A9551' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'AMDNoiseSuppression' },
    @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Name = 'Nearby Share' },
    @{ Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Name = 'Adobe Creative Cloud' },
    @{ Path = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Name = 'Adobe CCXProcess' },
    @{ Path = 'Registry::HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Name = 'CocCocBrowserAutoLaunch' },
    @{ Path = 'Registry::HKEY_USERS\S-1-5-18\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Name = 'CocCocBrowserAutoLaunch' }
)

$startupApprovedEntries = @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Opera Stable' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Opera GX Stable' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'tawk.to' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'NVIDIA Broadcast ' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'WebSocketServer23420' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'SignalRgb' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'electron.app.BlueStacks Services' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Teams' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Grammarly' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'MicrosoftEdgeAutoLaunch_25DA60072EA599DA62911C1F505A9551' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'AMDNoiseSuppression' },
    @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Nearby Share' }
)

$servicesToDisable = @(
    'coccoc',
    'coccocm'
)

Write-Step "Saving a backup to $backupDir"

foreach ($entry in $runEntries) {
    Disable-RunValue -Path $entry.Path -Name $entry.Name
}

foreach ($entry in $startupApprovedEntries) {
    Disable-StartupApprovedValue -Path $entry.Path -Name $entry.Name
}

foreach ($serviceName in $servicesToDisable) {
    Disable-ServiceStartup -Name $serviceName
}

$backupPath = Join-Path $backupDir 'startup-backup.json'
$script:backup | ConvertTo-Json -Depth 4 | Set-Content -Path $backupPath -Encoding ascii

Write-Step "Backup saved to $backupPath"
Write-Step 'Cleanup complete. Restart Windows to feel the full effect.'
