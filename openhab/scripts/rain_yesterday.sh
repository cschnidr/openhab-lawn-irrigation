#!/usr/bin/env bash
# =============================================================================
# rain_yesterday.sh — MeteoSwiss precipitation: yesterday's value
# =============================================================================
#
# Fetches the MeteoSwiss station CSV and outputs the precipitation value
# for YESTERDAY (the date before today's local date) as a single number [mm].
#
# Unlike a "last row" approach, this script parses the actual date column,
# which is robust against:
#   - CSV updates running late
#   - Multiple new rows appearing at once
#   - Missing rows for a specific day
#
# If yesterday's value is not (yet) in the CSV, the script falls back to
# the most recent available row and writes a warning to stderr.
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

# Yesterday in DD.MM.YYYY (Linux date format)
YESTERDAY=$(date -d "yesterday" '+%d.%m.%Y' 2>/dev/null || date -v-1d '+%d.%m.%Y')

result=$(curl -sf --max-time 15 "$CSV_URL" \
  | awk -F';' -v target="$YESTERDAY" '
      NR == 1 { next }   # skip header

      # Column 2 format: "DD.MM.YYYY HH:MM" — split off the date part
      {
        # Extract date (everything before the space)
        date_part = $2
        sub(/ .*$/, "", date_part)

        # Remember every valid row as fallback
        if (NF >= 3 && $3 != "" && $3 ~ /^[0-9]/) {
          last_value = $3 + 0
          last_date  = date_part
        }

        # Exact match for yesterday: capture and stop reading
        if (date_part == target && $3 != "" && $3 ~ /^[0-9]/) {
          found_value = $3 + 0
          found = 1
        }
      }
      END {
        if (found) {
          printf "%.1f\n", found_value
        } else if (last_date != "") {
          # Fallback: most recent row, warn on stderr
          printf "WARN: %s not in CSV, using last available row %s\n", target, last_date | "cat 1>&2"
          printf "%.1f\n", last_value
        } else {
          print "0.0"
        }
      }
    ')

if [ -z "$result" ]; then
  echo "0.0"
else
  echo "$result"
fi
