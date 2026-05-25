#!/usr/bin/env bash
# =============================================================================
# rain_lastNdays.sh — MeteoSwiss precipitation sum over last N days
# =============================================================================
#
# DIAGNOSTIC SCRIPT — not used by the irrigation decision rule itself.
#
# Outputs the sum of precipitation over the last N calendar days (default 7)
# as a single number [mm]. Useful for dashboards and sanity checks.
#
# The irrigation decision uses rain_yesterday.sh (single-day value).
#
# Usage:
#   bash rain_lastNdays.sh
#   → outputs e.g. "12.3"
#
# Configuration:
#   METEO_STATION=opf METEO_DAYS=7 bash rain_lastNdays.sh
# =============================================================================

STATION="${METEO_STATION:-opf}"
DAYS="${METEO_DAYS:-7}"

BASE_URL="https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip"
CSV_URL="${BASE_URL}/${STATION}/ogd-smn-precip_${STATION}_d_recent.csv"

result=$(curl -sf --max-time 15 "$CSV_URL" \
  | tail -n +2 \
  | awk -F';' '
      NF >= 3 && $3 != "" && $3 ~ /^[0-9]/ {
        vals[++count] = $3 + 0
      }
      END {
        if (count == 0) { print "0.0"; exit }
        sum = 0
        days = '"$DAYS"'
        start = count - days + 1
        if (start < 1) start = 1
        for (i = start; i <= count; i++) sum += vals[i]
        printf "%.1f\n", sum
      }
    ')

if [ -z "$result" ]; then
  echo "0.0"
else
  echo "$result"
fi
