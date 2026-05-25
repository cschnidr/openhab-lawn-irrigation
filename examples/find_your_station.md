# Finding Your Nearest MeteoSwiss Station

---

## Option 1 — Download and search the station list

Download the official station metadata CSV:

```
https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip/ogd-smn-precip_meta_stations.csv
```

Open in Excel/Numbers/LibreOffice. The relevant columns are:

- `station_abbr` — the code you put in the script (e.g. `OPF`)
- `station_name` — readable name
- `station_canton` — filter by your canton first
- `station_coordinates_wgs84_lat` / `station_coordinates_wgs84_lon` — to calculate distances

The abbreviation must be **lowercase** in all URLs and script configurations.

---

## Option 2 — MeteoSwiss map

Visit the interactive station map:
```
https://www.meteoschweiz.admin.ch/service-und-publikationen/applikationen/messwerte-und-messnetze.html#param=messnetz-automatisch
```

Click on the "Niederschlag" network to see precipitation-only stations.

---

## Option 3 — STAC Browser

Browse all available stations interactively:
```
https://data.geo.admin.ch/browser/index.html#/collections/ch.meteoschweiz.ogd-smn-precip
```

---

## Verify data is available for your station

Test the CSV URL directly in your browser or with curl:

```bash
# Replace "opf" with your station abbreviation (lowercase)
curl -s "https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip/opf/ogd-smn-precip_opf_d_recent.csv" | head -5
```

Expected output:
```
station_abbr;reference_timestamp;rre150d0;rka150d0
OPF;01.01.2026 00:00;0;0
OPF;02.01.2026 00:00;1.8;1.7
...
```

---

## Quick reference — major cities

| City / Region | Nearest Station | Abbr |
|---------------|----------------|------|
| Zürich Glattal (Wallisellen, Kloten) | Opfikon | `opf` |
| Zürich Stadt | Küsnacht ZH | `kue` |
| Winterthur | Bülach | `bue` |
| Baden / Brugg | Ehrendingen | `oed` |
| Aarau | Muri AG | `mur` |
| Basel | Kaiserstuhl AG | `kai` |
| Bern | Belp | `bep` |
| Luzern | Entlebuch | `ent` |
| Zug | Sihlbrugg | `sih` |
| St. Gallen | Flawil | `flw` |
| Chur | Rothenbrunnen | `rot` |
| Lausanne | Cossonay | `cos` |
| Genf | Longirod | `lon` |
| Lugano | Coldrerio | `col` |

---

## Important notes

- **Station vs. forecast PLZ**: use the station code for measured past rain, and your own PLZ for the forecast.
- **Altitude difference**: if the nearest station is at a significantly different altitude (>300 m), precipitation amounts may differ. Choose a station in a similar topographic situation if possible.
- **Station availability**: not all stations have data for all time periods. The `recent` file covers the current year to yesterday and is always available for active stations.
