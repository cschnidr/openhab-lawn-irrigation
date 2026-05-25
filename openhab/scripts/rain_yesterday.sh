#!/usr/bin/env bash
# =============================================================================
# rain_yesterday.sh — MeteoSwiss precipitation: yesterday's value
# =============================================================================
#
# Fetches the MeteoSwiss station CSV and outputs the precipitation value
# for YESTERDAY (the date before today's local date) as a single number [mm].
#
# Column choice — IMPORTANT:
#   The CSV has TWO precipitation columns with different time windows:
#     rre150d0 (column 3): daily sum 06 UTC to 06 UTC next day
#     rka150d0 (column 4): daily sum 00 UTC to 00 UTC (calendar day)
#
#   We use rka150d0 because:
#     - It's the calendar day, which matches what "yesterday" means to humans
#     - It's available shortly after 00 UTC (~02:00 local)
#     - rre150d0 is only complete after 06 UTC the following day (~08:00 local)
#       and is often still empty when the evening decision rule runs
#
# Date-aware lookup:
#   Parses the date column and looks up yesterday's actual date.
#   If yesterday's row is not yet present (rare, e.g. data delay), falls
#   back to the most recent available row and writes a warning to stderr.
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
COLUMN="${METEO_COLUMN:-4}"        # 4 = rka150d0 (calendar day), 3 = rre150d0 (06-06)

BASE_URL="https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip"
CSV_URL="${BASE_URL}/${STATION}/ogd-smn-precip_${STATION}_d_recent.csv"

# Yesterday in DD.MM.YYYY — works on both GNU date (Linux) and BSD date (macOS)
YESTERDAY=$(date -d "yesterday" '+%d.%m.%Y' 2>/dev/null || date -v-1d '+%d.%m.%Y')

result=$(curl -sf --max-time 15 "$CSV_URL" \
  | awk -F';' -v target="$YESTERDAY" -v col="$COLUMN" '
      NR == 1 { next }   # skip header

      {
        # Column 2 format: "DD.MM.YYYY HH:MM" — split off the date part
        date_part = $2
        sub(/ .*$/, "", date_part)

        value = $col

        # Remember every valid row as fallback
        if (NF >= col && value != "" && value ~ /^[0-9]/) {
          last_value = value + 0
          last_date  = date_part
        }

        # Exact match for yesterday: capture
        if (date_part == target && value != "" && value ~ /^[0-9]/) {
          found_value = value + 0
          found = 1
        }
      }
      END {
        if (found) {
          printf "%.1f\n", found_value
        } else if (last_date != "") {
          # Fallback: most recent row, warn on stderr
          printf "WARN: %s not in CSV (col %d), using last available row %s\n", \
            target, col, last_date | "cat 1>&2"
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
