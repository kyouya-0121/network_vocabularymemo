#!/bin/bash

TARGET_IP="1.2.3.4"
TARGET_DOMAIN="example.com"
LOGDIR="/var/log/commcheck"
mkdir -p $LOGDIR

CAPTURE_DURATION=1200   # tcpdumpローテーション間隔(秒) = 20分
RECOVERY_LIMIT=5
SLEEP_INTERVAL=60       # チェック間隔(秒)

CAPTURE_PID=""
RECOVERY_COUNT=0
CAPTURE_START_TIME=0

start_capture() {
    CAPFILE="$LOGDIR/pcap_capture_$(date +%Y%m%d%H%M%S).pcap"
    tcpdump -i any -s 0 -w "$CAPFILE" &
    CAPTURE_PID=$!
    CAPTURE_START_TIME=$(date +%s)
    echo "$(date '+%F %T') >>> tcpdump started ($CAPFILE)" >> "$LOGFILE"
}

stop_capture() {
    if [ -n "$CAPTURE_PID" ]; then
        kill -2 $CAPTURE_PID 2>/dev/null
        wait $CAPTURE_PID 2>/dev/null
        echo "$(date '+%F %T') >>> tcpdump stopped" >> "$LOGFILE"
        CAPTURE_PID=""
        CAPTURE_START_TIME=0
    fi
}

rotate_capture() {
    stop_capture
    start_capture
    echo "$(date '+%F %T') >>> tcpdump rotated" >> "$LOGFILE"
}

while true; do
    DATE=$(date '+%F %T')
    LOGFILE="$LOGDIR/check_$(date +%Y%m%d%H).log"

    echo "===== $DATE =====" >> "$LOGFILE"
    ping -c 3 -W 2 $TARGET_IP >> "$LOGFILE" 2>&1
    traceroute -n $TARGET_IP >> "$LOGFILE" 2>&1
    nslookup $TARGET_DOMAIN >> "$LOGFILE" 2>&1
    curl -k -s -o /dev/null -w "HTTP:%{http_code}\n" "https://$TARGET_DOMAIN" >> "$LOGFILE" 2>&1
    STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" "https://$TARGET_DOMAIN" --max-time 10)

    if [ "$STATUS" != "200" ]; then
        echo "$DATE NG ($STATUS)" >> "$LOGFILE"
        if [ -z "$CAPTURE_PID" ]; then
            start_capture
            RECOVERY_COUNT=0
        fi
    else
        echo "$DATE OK ($STATUS)" >> "$LOGFILE"
        if [ -n "$CAPTURE_PID" ]; then
            RECOVERY_COUNT=$((RECOVERY_COUNT+1))
            if [ $RECOVERY_COUNT -ge $RECOVERY_LIMIT ]; then
                stop_capture
                RECOVERY_COUNT=0
            fi
        fi
    fi

    # ローテーションチェック
    if [ -n "$CAPTURE_PID" ]; then
        NOW=$(date +%s)
        ELAPSED=$((NOW - CAPTURE_START_TIME))
        if [ $ELAPSED -ge $CAPTURE_DURATION ]; then
            rotate_capture
        fi
    fi

    sleep $SLEEP_INTERVAL
done
