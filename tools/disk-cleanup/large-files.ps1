# large-files.ps1 — Find files larger than a threshold
# Usage: .\large-files.ps1 -Path H:\ -MinSizeMB 500

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$MinSizeMB = 500,

    [int]$TopN = 100
)

if (-not (Test-Path $Path)) {
    Write-Host "Path not found: $Path" -ForegroundColor Red
    exit 1
}

$minBytes = [int64]$MinSizeMB * 1MB

Write-Host "Scanning $Path for files > $MinSizeMB MB ..." -ForegroundColor Cyan
Write-Host "(This may take a while. Access-denied folders will be skipped.)`n"

$files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
         Where-Object { $_.Length -ge $minBytes } |
         Sort-Object Length -Descending |
         Select-Object -First $TopN

$results = foreach ($f in $files) {
    [PSCustomObject]@{
        SizeGB       = [math]::Round($f.Length / 1GB, 2)
        SizeMB       = [math]::Round($f.Length / 1MB, 0)
        Extension    = $f.Extension.ToLower()
        LastAccess   = $f.LastAccessTime.ToString("yyyy-MM-dd")
        LastWrite    = $f.LastWriteTime.ToString("yyyy-MM-dd")
        FullPath     = $f.FullName
    }
}

$results | Format-Table SizeGB, SizeMB, Extension, LastAccess, FullPath -AutoSize

$totalGB = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
Write-Host "`nFound $($files.Count) files, total: $totalGB GB" -ForegroundColor Yellow

$reportsDir = Join-Path $PSScriptRoot "reports"
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }

$driveLetter = ($Path -replace '[:\\\/]', '') -replace '\s', ''
$csvPath = Join-Path $reportsDir "large-files_${driveLetter}_${MinSizeMB}MB.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "Saved to: $csvPath" -ForegroundColor Green
