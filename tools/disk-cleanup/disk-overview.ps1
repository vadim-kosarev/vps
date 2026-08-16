# disk-overview.ps1 — Show disk space summary for all fixed drives

$drives = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"

$results = foreach ($d in $drives) {
    $totalGB = [math]::Round($d.Size / 1GB, 1)
    $freeGB = [math]::Round($d.FreeSpace / 1GB, 1)
    $usedGB = [math]::Round(($d.Size - $d.FreeSpace) / 1GB, 1)
    $usedPct = if ($d.Size -gt 0) { [math]::Round(($d.Size - $d.FreeSpace) / $d.Size * 100, 1) } else { 0 }

    [PSCustomObject]@{
        Drive    = $d.DeviceID
        Label    = $d.VolumeName
        TotalGB  = $totalGB
        UsedGB   = $usedGB
        FreeGB   = $freeGB
        UsedPct  = "$usedPct%"
    }
}

$results | Format-Table -AutoSize
