# Bulk-Mailer-Admin-Panel

## Utilities

If your PC becomes slow after staying on for a long time, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\slow-fix.ps1
```

Useful switches:

```powershell
# Also close browsers/WebView processes
powershell -ExecutionPolicy Bypass -File .\scripts\slow-fix.ps1 -CloseBrowsers

# Also close known heavy apps like RGB tools or chat apps
powershell -ExecutionPolicy Bypass -File .\scripts\slow-fix.ps1 -CloseKnownHeavyApps

# Show the top memory-hungry processes after cleanup
powershell -ExecutionPolicy Bypass -File .\scripts\slow-fix.ps1 -ShowTopProcesses
```

The default mode is designed to be safer: it resets Windows shell/input/search processes and restarts Explorer without force-closing your browsers.

If you want to disable a conservative list of heavy startup apps and keep a restore backup:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\startup-cleanup.ps1
```

To restore a previous backup:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\startup-restore.ps1 -BackupFile D:\StartupBackups\startup-cleanup-YYYYMMDD-HHMMSS\startup-backup.json
```
