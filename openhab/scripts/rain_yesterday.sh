#!/usr/bin/env bash
# =============================================================================
# rain_yesterday.sh — MeteoSwiss precipitation: yesterday's value only
# =============================================================================
#
# Fetches the MeteoSwiss station CSV and outputs ONLY the most recent
# complete daily value (yesterday) as a single number [mm].
#
# This is used to update IrrigationRainYesterday in the soil store balance.
# The companion script rain_station.sh returns the 7-day sum for diagnostics.
#
# Usage (called by openHAB Exec Binding):
#   bash rain_yesterday.sh
#   → outputs e.g. "4.2"
#
# Configuration:
#   Set STATION below, or override via environment variable:
#     METEO_STATION=bue bash rain_yesterday.sh
# =============================================================================

STATION="${METEO_STATION:-opf}"   # Station abbreviation, lowercase

BASE_URL="https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip"
CSV_URL="${BASE_URL}/${STATION}/ogd-smn-precip_${STATION}_d_recent.csv"

result=$(curl -sf --max-time 15 "$CSV_URL" \
  | tail -n +2 \
  | awk -F';' '
      NF >= 3 && $3 != "" && $3 ~ /^[0-9]/ {
        last = $3 + 0
      }
      END {
        printf "%.1f\n", last+0
      }
    ')

if [ -z "$result" ]; then
  echo "0.0"
else
  echo "$result"
fi
