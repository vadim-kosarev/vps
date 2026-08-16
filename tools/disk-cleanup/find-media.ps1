# find-media.ps1 — Find media files, archives, ISOs, installers
# Usage: .\find-media.ps1 -Path H:\

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$TopN = 200
)

if (-not (Test-Path $Path)) {
    Write-Host "Path not found: $Path" -ForegroundColor Red
    exit 1
}

$categories = @{
    "Video"      = @(".mkv", ".avi", ".mp4", ".mov", ".wmv", ".flv", ".ts", ".m4v", ".webm", ".mpg", ".mpeg")
    "ISO/Image"  = @(".iso", ".img", ".vhd", ".vhdx", ".vmdk", ".bin", ".nrg", ".mdf")
    "Archive"    = @(".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz", ".tgz", ".cab")
    "Torrent"    = @(".torrent")
    "Installer"  = @(".msi")
}

Write-Host "Scanning $Path for media, archives, ISOs, installers ..." -ForegroundColor Cyan
Write-Host "(This may take a while. Access-denied folders will be skipped.)`n"

$allFiles = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue

$reportsDir = Join-Path $PSScriptRoot "reports"
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }

$driveLetter = ($Path -replace '[:\\\/]', '') -replace '\s', ''

foreach ($category in $categories.Keys) {
    $extensions = $categories[$category]
    $matched = $allFiles | Where-Object { $extensions -contains $_.Extension.ToLower() }

    if ($category -eq "Installer") {
        $matched = $matched | Where-Object { $_.Length -ge 100MB }
    }

    $sorted = $matched | Sort-Object Length -Descending | Select-Object -First $TopN

    $results = foreach ($f in $sorted) {
        [PSCustomObject]@{
            SizeGB    = [math]::Round($f.Length / 1GB, 2)
            SizeMB    = [math]::Round($f.Length / 1MB, 0)
            Extension = $f.Extension.ToLower()
            FullPath  = $f.FullName
        }
    }

    $totalGB = [math]::Round(($matched | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
    $count = ($matched | Measure-Object).Count

    Write-Host "`n=== $category === ($count files, $totalGB GB total)" -ForegroundColor Yellow
    if ($results) {
        $results | Format-Table SizeGB, SizeMB, Extension, FullPath -AutoSize

        $csvPath = Join-Path $reportsDir "media_${driveLetter}_$($category -replace '[/\s]', '_').csv"
        $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    }
    else {
        Write-Host "  (none found)"
    }
}

# Large .exe files (potential game/app installers)
$largeExe = $allFiles | Where-Object { $_.Extension -eq ".exe" -and $_.Length -ge 100MB } |
            Sort-Object Length -Descending | Select-Object -First 50

if ($largeExe) {
    $exeResults = foreach ($f in $largeExe) {
        [PSCustomObject]@{
            SizeGB   = [math]::Round($f.Length / 1GB, 2)
            SizeMB   = [math]::Round($f.Length / 1MB, 0)
            FullPath = $f.FullName
        }
    }
    $totalExeGB = [math]::Round(($largeExe | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
    Write-Host "`n=== Large EXE (>100MB) === ($($largeExe.Count) files, $totalExeGB GB total)" -ForegroundColor Yellow
    $exeResults | Format-Table SizeGB, SizeMB, FullPath -AutoSize

    $csvPath = Join-Path $reportsDir "media_${driveLetter}_LargeEXE.csv"
    $exeResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
}
