#!/bin/bash

TARGET_IP="1.2.3.4"         # 外部サーバIP
TARGET_DOMAIN="example.com" # 外部サーバドメイン
LOG_DIR="/var/log/commcheck"
mkdir -p $LOG_DIR

CAPTURE_FILE="$LOG_DIR/pcap_capture_$(date +%Y%m%d%H%M%S).pcap"
CAPTURE_PID_FILE="/var/run/pcap_capture.pid"
RECOVERY_COUNT_FILE="/var/run/recovery_count"
RECOVERY_LIMIT=5

while true; do
    DATE=$(date '+%Y-%m-%d %H:%M:%S')
    LOG_FILE="$LOG_DIR/check_$(date +%Y%m%d%H).log"   # 1時間ごとに切り替え

    {
        echo "===== $DATE ====="
        ping -c 4 $TARGET_IP
        traceroute $TARGET_IP
        nslookup $TARGET_DOMAIN
        curl -o /dev/null -s -w "HTTP:%{http_code}\n" https://$TARGET_DOMAIN
    } >> "$LOG_FILE" 2>&1

    # 疎通判定: curlのHTTPコードで判定
    STATUS=$(curl -o /dev/null -s -w "%{http_code}" https://$TARGET_DOMAIN)
    if [ "$STATUS" -ne 200 ]; then
        echo "$DATE NG ($STATUS)" >> "$LOG_FILE"
        if [ ! -f "$CAPTURE_PID_FILE" ]; then
            tcpdump -i eth0 -w "$CAPTURE_FILE" &
            echo $! > "$CAPTURE_PID_FILE"
            echo 0 > "$RECOVERY_COUNT_FILE"
            echo "$DATE >>> tcpdump started ($CAPTURE_FILE)" >> "$LOG_FILE"
        fi
    else
        echo "$DATE OK ($STATUS)" >> "$LOG_FILE"
        if [ -f "$CAPTURE_PID_FILE" ]; then
            COUNT=$(cat "$RECOVERY_COUNT_FILE")
            COUNT=$((COUNT+1))
            echo $COUNT > "$RECOVERY_COUNT_FILE"
            if [ "$COUNT" -ge "$RECOVERY_LIMIT" ]; then
                PID=$(cat "$CAPTURE_PID_FILE")
                kill $PID
                rm -f "$CAPTURE_PID_FILE" "$RECOVERY_COUNT_FILE"
                echo "$DATE >>> tcpdump stopped after recovery" >> "$LOG_FILE"
            fi
        fi
    fi

    sleep 60   # 1分間隔で繰り返し
done
