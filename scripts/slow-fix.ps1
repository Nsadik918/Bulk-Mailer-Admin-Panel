[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$CloseBrowsers,
    [switch]$CloseKnownHeavyApps,
    [switch]$ShowTopProcesses
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[slow-fix] $Message" -ForegroundColor Cyan
}

function Stop-ProcessIfRunning {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Names,
        [switch]$WarnOnFailure
    )

    foreach ($name in $Names) {
        $processes = Get-Process -Name $name -ErrorAction SilentlyContinue
        if (-not $processes) {
            continue
        }

        foreach ($process in $processes) {
            $label = "$($process.ProcessName) (PID $($process.Id))"
            if ($PSCmdlet.ShouldProcess($label, "Stop process")) {
                try {
                    Stop-Process -Id $process.Id -Force -ErrorAction Stop
                    Write-Host "  stopped $label"
                } catch {
                    if ($WarnOnFailure) {
                        Write-Warning ("Could not stop {0}: {1}" -f $label, $_.Exception.Message)
                    }
                }
            }
        }
    }
}

function Show-MemorySummary {
    $os = Get-CimInstance Win32_OperatingSystem
    $pageFile = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue
    $commitCounter = Get-Counter '\Memory\Committed Bytes','\Memory\Commit Limit' |
        Select-Object -ExpandProperty CounterSamples

    $totalMemoryGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $freeMemoryGb = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $usedMemoryGb = [math]::Round($totalMemoryGb - $freeMemoryGb, 1)

    $committedBytes = ($commitCounter | Where-Object Path -like '*Committed Bytes').CookedValue
    $commitLimitBytes = ($commitCounter | Where-Object Path -like '*Commit Limit').CookedValue

    Write-Step "Memory snapshot"
    Write-Host ("  RAM in use : {0} GB / {1} GB" -f $usedMemoryGb, $totalMemoryGb)
    Write-Host ("  Commit     : {0} GB / {1} GB" -f `
        ([math]::Round($committedBytes / 1GB, 1)), `
        ([math]::Round($commitLimitBytes / 1GB, 1)))

    foreach ($entry in $pageFile) {
        Write-Host ("  Page file  : {0} GB used of {1} GB at {2}" -f `
            ([math]::Round($entry.CurrentUsage / 1024, 1)), `
            ([math]::Round($entry.AllocatedBaseSize / 1024, 1)), `
            $entry.Name)
    }
}

function Restart-Explorer {
    Write-Step "Restarting Windows Explorer"
    if ($PSCmdlet.ShouldProcess("Windows Explorer", "Restart Explorer")) {
        Stop-ProcessIfRunning -Names @('explorer') -WarnOnFailure
        Start-Sleep -Seconds 2
        Start-Process explorer.exe
    }
}

Write-Step "Starting safe cleanup"
Show-MemorySummary

$safeUiProcesses = @(
    'TextInputHost',
    'StartMenuExperienceHost',
    'ShellExperienceHost',
    'SearchHost',
    'SearchApp',
    'Widgets'
)

Write-Step "Resetting common UI processes that often bloat over long sessions"
Stop-ProcessIfRunning -Names $safeUiProcesses -WarnOnFailure

Restart-Explorer

if ($CloseBrowsers) {
    Write-Step "Closing browsers and WebView runtimes"
    Stop-ProcessIfRunning -Names @(
        'chrome',
        'msedge',
        'msedgewebview2',
        'brave',
        'firefox',
        'opera'
    ) -WarnOnFailure
}

if ($CloseKnownHeavyApps) {
    Write-Step "Closing optional heavy apps"
    Stop-ProcessIfRunning -Names @(
        'cam_helper',
        'SignalRgbLauncher',
        'BlueStacksServices',
        'HD-Player',
        'Telegram',
        'ms-teams',
        'Discord'
    ) -WarnOnFailure
}

if ($ShowTopProcesses) {
    Write-Step "Top processes by private memory"
    Get-Process |
        Sort-Object PM -Descending |
        Select-Object -First 12 ProcessName, Id,
            @{Name = 'PrivateMemoryGB'; Expression = { [math]::Round($_.PM / 1GB, 2) } },
            CPU |
        Format-Table -AutoSize
}

Write-Step "Cleanup complete. If the PC still feels sluggish, do a full Restart."
