# dir-sizes.ps1 — Show directory sizes sorted by size
# Usage: .\dir-sizes.ps1 -Path H:\ -Depth 1

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$Depth = 1,

    [int]$TopN = 30
)

if (-not (Test-Path $Path)) {
    Write-Host "Path not found: $Path" -ForegroundColor Red
    exit 1
}

$dirs = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue

$results = foreach ($dir in $dirs) {
    try {
        $size = (Get-ChildItem -Path $dir.FullName -Recurse -File -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($null -eq $size) { $size = 0 }

        [PSCustomObject]@{
            SizeBytes = $size
            SizeGB    = [math]::Round($size / 1GB, 2)
            SizeMB    = [math]::Round($size / 1MB, 0)
            Path      = $dir.FullName
        }
    }
    catch {
        [PSCustomObject]@{
            SizeBytes = 0
            SizeGB    = 0
            SizeMB    = 0
            Path      = "$($dir.FullName) [ACCESS DENIED]"
        }
    }
}

$sorted = $results | Sort-Object SizeBytes -Descending | Select-Object -First $TopN

$sorted | Format-Table SizeGB, SizeMB, Path -AutoSize

$reportsDir = Join-Path $PSScriptRoot "reports"
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }

$driveLetter = ($Path -replace '[:\\\/]', '') -replace '\s', ''
$csvPath = Join-Path $reportsDir "dir-sizes_$driveLetter.csv"
$sorted | Select-Object SizeGB, SizeMB, Path | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "`nSaved to: $csvPath" -ForegroundColor Green

if ($Depth -gt 1) {
    Write-Host "`nLargest subdirectories (depth $Depth):" -ForegroundColor Cyan
    foreach ($topDir in ($sorted | Select-Object -First 5)) {
        if ($topDir.Path -notlike "*ACCESS DENIED*" -and $topDir.SizeGB -gt 0.1) {
            Write-Host "`n--- $($topDir.Path) ($($topDir.SizeGB) GB) ---" -ForegroundColor Yellow
            $subDirs = Get-ChildItem -Path $topDir.Path -Directory -ErrorAction SilentlyContinue
            $subResults = foreach ($sub in $subDirs) {
                try {
                    $subSize = (Get-ChildItem -Path $sub.FullName -Recurse -File -ErrorAction SilentlyContinue |
                                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($null -eq $subSize) { $subSize = 0 }
                    [PSCustomObject]@{
                        SizeGB = [math]::Round($subSize / 1GB, 2)
                        SizeMB = [math]::Round($subSize / 1MB, 0)
                        Path   = $sub.FullName
                    }
                }
                catch {}
            }
            $subResults | Sort-Object { $_.SizeGB } -Descending | Select-Object -First 10 | Format-Table SizeGB, SizeMB, Path -AutoSize
        }
    }
}
