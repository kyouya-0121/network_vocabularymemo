# === 設定 ===
$wiresharkPath = "C:\Program Files\Wireshark"
$targetIP = "192.168.10.50"
$inputFolder = "C:\pcap\2025-10-24"   # ← 対象フォルダをここに書く
$outputFile = "filtered_192.168.10.50.pcapng"

# === 実行ファイル ===
$mergecap = Join-Path $wiresharkPath "mergecap.exe"
$tshark   = Join-Path $wiresharkPath "tshark.exe"

# === 結合 ===
Write-Host "=== pcapng結合中... ==="
$pcapFiles = Get-ChildItem -Path $inputFolder -Filter *.pcapng
& $mergecap -w "$inputFolder\merged_all.pcapng" $pcapFiles.FullName

# === フィルタ ===
Write-Host "=== 192.168.10.50 を含む通信を抽出中... ==="
& $tshark -r "$inputFolder\merged_all.pcapng" -Y "ip.addr == $targetIP" -w "$inputFolder\$outputFile"

Write-Host "=== 完了！ ==="
Write-Host "出力：$inputFolder\$outputFile"
