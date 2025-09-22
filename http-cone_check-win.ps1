$TargetIP = "1.2.3.4"
$TargetDomain = "example.com"
$LogDir = "C:\CommCheck"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$CaptureFile = "$LogDir\pcap_capture_$(Get-Date -Format yyyyMMddHHmmss).etl"
$PidFile = "$LogDir\pcap_capture.pid"
$RecoveryCountFile = "$LogDir\recovery_count.txt"
$RecoveryLimit = 5

while ($true) {
    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogFile = "$LogDir\check_$(Get-Date -Format yyyyMMddHH).log"

    Add-Content $LogFile "===== $Date ====="
    ping $TargetIP | Out-File -Append $LogFile
    tracert $TargetIP | Out-File -Append $LogFile
    nslookup $TargetDomain | Out-File -Append $LogFile
    Test-NetConnection -ComputerName $TargetIP -Port 443 | Out-File -Append $LogFile
    Test-NetConnection -ComputerName $TargetDomain -Port 443 | Out-File -Append $LogFile
    try {
        $Response = Invoke-WebRequest -Uri "https://$TargetDomain" -UseBasicParsing -TimeoutSec 10
        Add-Content $LogFile "HTTP:$($Response.StatusCode)"
        $Status = $Response.StatusCode
    } catch {
        Add-Content $LogFile "HTTP:ERROR $($_.Exception.Message)"
        $Status = 0
    }

    # 判定
    if ($Status -ne 200) {
        Add-Content $LogFile "$Date NG ($Status)"
        if (-not (Test-Path $PidFile)) {
            Start-Process -FilePath "netsh" -ArgumentList "trace start capture=yes tracefile=$CaptureFile" -WindowStyle Hidden
            Set-Content $PidFile "netsh"
            Set-Content $RecoveryCountFile "0"
            Add-Content $LogFile "$Date >>> netsh trace started ($CaptureFile)"
        }
    } else {
        Add-Content $LogFile "$Date OK ($Status)"
        if (Test-Path $PidFile) {
            $Count = 0
            if (Test-Path $RecoveryCountFile) {
                $Count = [int](Get-Content $RecoveryCountFile)
            }
            $Count++
            Set-Content $RecoveryCountFile $Count
            if ($Count -ge $RecoveryLimit) {
                Start-Process -FilePath "netsh" -ArgumentList "trace stop" -WindowStyle Hidden
                Remove-Item $PidFile, $RecoveryCountFile -Force
                Add-Content $LogFile "$Date >>> netsh trace stopped after recovery"
            }
        }
    }

    Start-Sleep -Seconds 60   # 1分間隔
}
