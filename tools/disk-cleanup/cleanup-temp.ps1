# cleanup-temp.ps1 — Analyze (and optionally clean) temp/cache on C:\
# Usage: .\cleanup-temp.ps1              — report only (dry run)
#        .\cleanup-temp.ps1 -Clean       — actually delete

param(
    [switch]$Clean
)

$locations = @(
    @{ Name = "Windows Temp";        Path = "C:\Windows\Temp" }
    @{ Name = "User Temp";           Path = $env:TEMP }
    @{ Name = "Windows Update Cache"; Path = "C:\Windows\SoftwareDistribution\Download" }
    @{ Name = "Windows Logs";        Path = "C:\Windows\Logs" }
    @{ Name = "Crash Dumps";         Path = "$env:LOCALAPPDATA\CrashDumps" }
    @{ Name = "Windows Minidumps";   Path = "C:\Windows\Minidump" }
    @{ Name = "Prefetch";            Path = "C:\Windows\Prefetch" }
    @{ Name = "Recycle Bin data";     Path = "C:\`$Recycle.Bin" }
    @{ Name = "NVIDIA DXCache";      Path = "$env:LOCALAPPDATA\NVIDIA\DXCache" }
    @{ Name = "NVIDIA GLCache";      Path = "$env:LOCALAPPDATA\NVIDIA\GLCache" }
    @{ Name = "npm cache";           Path = "$env:APPDATA\npm-cache" }
    @{ Name = "pip cache";           Path = "$env:LOCALAPPDATA\pip\cache" }
    @{ Name = "nuget cache";         Path = "$env:LOCALAPPDATA\NuGet\v3-cache" }
    @{ Name = "Windows.old";         Path = "C:\Windows.old" }
    @{ Name = "Thumbnails cache";    Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" }
)

$mode = if ($Clean) { "CLEAN MODE" } else { "DRY RUN (report only)" }
Write-Host "`nDisk Cleanup — $mode`n" -ForegroundColor Cyan

$totalSaved = 0

foreach ($loc in $locations) {
    if (Test-Path $loc.Path) {
        try {
            $size = (Get-ChildItem -Path $loc.Path -Recurse -File -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($null -eq $size) { $size = 0 }
            $sizeMB = [math]::Round($size / 1MB, 1)

            if ($sizeMB -gt 1) {
                Write-Host "  $($loc.Name): $sizeMB MB — $($loc.Path)" -ForegroundColor $(if ($sizeMB -gt 500) { "Red" } elseif ($sizeMB -gt 100) { "Yellow" } else { "White" })
                $totalSaved += $size

                if ($Clean -and $loc.Name -notin @("Recycle Bin data", "Windows.old", "Windows Update Cache")) {
                    Get-ChildItem -Path $loc.Path -Recurse -File -ErrorAction SilentlyContinue |
                        Remove-Item -Force -ErrorAction SilentlyContinue
                    Write-Host "    -> Cleaned" -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Host "  $($loc.Name): [ACCESS DENIED]" -ForegroundColor DarkGray
        }
    }
}

Write-Host "`nTotal reclaimable: $([math]::Round($totalSaved / 1GB, 2)) GB" -ForegroundColor Yellow

if (-not $Clean) {
    Write-Host "`nThis was a DRY RUN. To actually clean, run:" -ForegroundColor Cyan
    Write-Host "  .\cleanup-temp.ps1 -Clean" -ForegroundColor White
    Write-Host "`nFor Windows Update Cache and Windows.old, use:" -ForegroundColor Cyan
    Write-Host "  cleanmgr /d C" -ForegroundColor White
}

# Browser caches — report only, clean via browser settings
Write-Host "`n--- Browser caches (clean via browser settings) ---" -ForegroundColor Cyan
$browserCaches = @(
    @{ Name = "Chrome";  Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" }
    @{ Name = "Edge";    Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" }
    @{ Name = "Firefox"; Path = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles" }
)

foreach ($bc in $browserCaches) {
    if (Test-Path $bc.Path) {
        try {
            $size = (Get-ChildItem -Path $bc.Path -Recurse -File -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($null -eq $size) { $size = 0 }
            $sizeMB = [math]::Round($size / 1MB, 1)
            Write-Host "  $($bc.Name) cache: $sizeMB MB" -ForegroundColor White
        }
        catch {}
    }
}
