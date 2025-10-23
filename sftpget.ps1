# File: C:\scripts\GetPcapSafe.ps1
# =========================================
# PowerShell SFTPで古いPCAPのみ取得し、削除
# =========================================

# 設定
$rhelHost = "10.0.0.5"           # RHEL IP
$rhelUser = "azureuser"          # SSHユーザー
$remoteDir = "/var/log/pcap"     # RHEL保存フォルダ
$localDir = "C:\pcap"            # Windows保存先
$privateKey = "C:\keys\id_rsa"   # 鍵認証用

# ローカル保存先作成
if (!(Test-Path $localDir)) { New-Item -ItemType Directory -Path $localDir }

# まずリモートディレクトリ内のファイル一覧を取得（ls）
$remoteFiles = & ssh -i $privateKey $rhelUser@$rhelHost "ls -1t $remoteDir/*.pcap"

# 取得対象は古いファイルのみ（最新1個は除外）
if ($remoteFiles.Count -le 1) {
    Write-Output "取得対象なし（ファイル1個以下）"
    exit 0
}

# 最新以外のファイルを取得
$filesToGet = $remoteFiles | Select-Object -Skip 1

# SFTP スクリプト作成
$tmpSftpScript = "$env:TEMP\sftp_safe_cmd.txt"

$scriptContent = @()
$scriptContent += "lcd $localDir"
$scriptContent += "cd $remoteDir"
foreach ($f in $filesToGet) {
    $scriptContent += "get `"$f`""
    $scriptContent += "rm `"$f`""
}
$scriptContent += "bye"

$scriptContent | Out-File -Encoding ascii $tmpSftpScript

# SFTP 実行
& sftp -b $tmpSftpScript -i $privateKey $rhelUser@$rhelHost

# 一時スクリプト削除
Remove-Item $tmpSftpScript

Write-Output "古いファイル取得完了: $($filesToGet -join ', ')"
