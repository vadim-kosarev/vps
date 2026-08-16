# old-files.ps1 — Find large files not accessed for a long time
# Usage: .\old-files.ps1 -Path H:\ -MonthsOld 12 -MinSizeMB 100

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$MonthsOld = 12,

    [int]$MinSizeMB = 100,

    [int]$TopN = 100
)

if (-not (Test-Path $Path)) {
    Write-Host "Path not found: $Path" -ForegroundColor Red
    exit 1
}

$cutoffDate = (Get-Date).AddMonths(-$MonthsOld)
$minBytes = [int64]$MinSizeMB * 1MB

Write-Host "Scanning $Path for files > $MinSizeMB MB, not accessed since $($cutoffDate.ToString('yyyy-MM-dd')) ..." -ForegroundColor Cyan
Write-Host "(This may take a while. Access-denied folders will be skipped.)`n"

$files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
         Where-Object { $_.Length -ge $minBytes -and $_.LastAccessTime -lt $cutoffDate } |
         Sort-Object Length -Descending |
         Select-Object -First $TopN

$results = foreach ($f in $files) {
    $ageDays = [math]::Round(((Get-Date) - $f.LastAccessTime).TotalDays, 0)
    [PSCustomObject]@{
        SizeGB     = [math]::Round($f.Length / 1GB, 2)
        SizeMB     = [math]::Round($f.Length / 1MB, 0)
        Extension  = $f.Extension.ToLower()
        LastAccess = $f.LastAccessTime.ToString("yyyy-MM-dd")
        AgeDays    = $ageDays
        FullPath   = $f.FullName
    }
}

$results | Format-Table SizeGB, SizeMB, Extension, LastAccess, AgeDays, FullPath -AutoSize

$totalGB = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
Write-Host "`nFound $($files.Count) old large files, total: $totalGB GB" -ForegroundColor Yellow

$reportsDir = Join-Path $PSScriptRoot "reports"
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }

$driveLetter = ($Path -replace '[:\\\/]', '') -replace '\s', ''
$csvPath = Join-Path $reportsDir "old-files_${driveLetter}_${MonthsOld}m_${MinSizeMB}MB.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "Saved to: $csvPath" -ForegroundColor Green
