[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupFile
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "[startup-restore] $Message" -ForegroundColor Cyan
}

if (-not (Test-Path $BackupFile)) {
    throw "Backup file not found: $BackupFile"
}

$backup = Get-Content $BackupFile -Raw | ConvertFrom-Json

foreach ($entry in $backup.RunValues) {
    if ($PSCmdlet.ShouldProcess("$($entry.Path) :: $($entry.Name)", 'Restore Run entry')) {
        if (-not (Test-Path $entry.Path)) {
            New-Item -Path $entry.Path -Force | Out-Null
        }

        New-ItemProperty -Path $entry.Path -Name $entry.Name -Value $entry.Value -PropertyType String -Force | Out-Null
        Write-Host "  restored Run entry $($entry.Name)"
    }
}

foreach ($entry in $backup.StartupApproved) {
    if ($PSCmdlet.ShouldProcess("$($entry.Path) :: $($entry.Name)", 'Restore StartupApproved entry')) {
        if (-not (Test-Path $entry.Path)) {
            New-Item -Path $entry.Path -Force | Out-Null
        }

        $bytes = [Convert]::FromBase64String($entry.ValueBase64)
        New-ItemProperty -Path $entry.Path -Name $entry.Name -Value $bytes -PropertyType Binary -Force | Out-Null
    }
}

foreach ($service in $backup.Services) {
    if ($PSCmdlet.ShouldProcess($service.Name, "Restore service startup to $($service.StartMode)")) {
        Set-Service -Name $service.Name -StartupType $service.StartMode
        Write-Host "  restored service $($service.Name) to $($service.StartMode)"
    }
}

Write-Step 'Restore complete.'
