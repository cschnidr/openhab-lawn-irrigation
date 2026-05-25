#!/usr/bin/env bash
# =============================================================================
# rain_station.sh — MeteoSwiss precipitation fetcher for openHAB
# =============================================================================
#
# Fetches the daily precipitation CSV for a SwissMetNet station and outputs
# the sum of the last N days as a single floating-point number (mm).
#
# Usage (called by openHAB Exec Binding):
#   bash rain_station.sh
#   → outputs e.g. "12.3" (mm over last DAYS days)
#
# Configuration:
#   Set STATION and DAYS below, or override via environment variables:
#     METEO_STATION=opf METEO_DAYS=7 bash rain_station.sh
#
# Station list:
#   https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip/ogd-smn-precip_meta_stations.csv
#   Note: use lowercase station abbreviation (e.g. "opf", not "OPF")
#
# Data source:
#   MeteoSwiss Open Government Data (OGD), CC-BY licence
#   https://data.geo.admin.ch/api/stac/v1/collections/ch.meteoschweiz.ogd-smn-precip
#
# =============================================================================

# ── CONFIGURATION ─────────────────────────────────────────────────────────────
STATION="${METEO_STATION:-opf}"   # Station abbreviation, lowercase (e.g. opf, bue, enk)
DAYS="${METEO_DAYS:-7}"           # Number of past days to sum
# ──────────────────────────────────────────────────────────────────────────────

BASE_URL="https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip"
CSV_URL="${BASE_URL}/${STATION}/ogd-smn-precip_${STATION}_d_recent.csv"

# Fetch CSV, skip header, filter valid rows, sum last $DAYS values
result=$(curl -sf --max-time 15 "$CSV_URL" \
  | tail -n +2 \
  | awk -F';' '
      # Column 3 (rre150d0) = precipitation total [mm]
      # Skip rows with empty or missing precipitation value
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

# Fallback to 0.0 if fetch failed or produced no output
if [ -z "$result" ]; then
  echo "0.0"
else
  echo "$result"
fi
