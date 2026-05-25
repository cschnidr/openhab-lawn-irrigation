# Configuration Guide

This document explains every parameter you need to adapt for your location and setup.

---

## Step 1 — Find your MeteoSwiss precipitation station

Download the station list and find the station closest to your garden:

```
https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip/ogd-smn-precip_meta_stations.csv
```

The file is semicolon-separated. Relevant columns:

| Column | Description |
|--------|-------------|
| `station_abbr` | Short code used in all URLs (e.g. `OPF`) |
| `station_name` | Human-readable name (e.g. `Opfikon`) |
| `station_canton` | Canton abbreviation |
| `station_coordinates_wgs84_lat/lon` | For distance calculation |
| `station_height_masl` | Altitude in metres |

**Tip:** Open the CSV in Excel or Numbers, sort by canton, and pick the geographically closest station. Alternatively, use [map.geo.admin.ch](https://map.geo.admin.ch) and search for "SwissMetNet".

The station abbreviation appears **lowercase** in URLs (e.g. `OPF` → `opf`).

See also: [examples/find_your_station.md](../examples/find_your_station.md)

---

## Step 2 — Find your postal code (PLZ)

The MeteoSwiss forecast API uses a 4-digit Swiss postal code, zero-padded to 6 digits:

```
PLZ 8304 → URL parameter: plz=830400
PLZ 3001 → URL parameter: plz=300100
```

---

## Step 3 — Adapt the shell script

Edit `openhab/scripts/rain_station.sh` and set:

```bash
STATION="opf"   # ← your station abbreviation, lowercase
```

Verify it works by running the script manually:
```bash
bash openhab/scripts/rain_station.sh
# Expected output: a single number like 3.2
```

---

## Step 4 — Adapt the Things file

Edit `openhab/things/irrigation_weather.things`:

```java
// MeteoSwiss App API — change PLZ here
Thing http:url:meteoSwissForecast "MeteoSwiss Forecast" [
    baseURL="https://app-prod-ws.meteoswiss-app.ch/v2/plzDetail?plz=830400",
    //                                                              ^^^^^^
    //                                              Replace with your PLZ + "00"
    ...
]
```

---

## Step 5 — Tune the irrigation model

All tunable parameters are at the top of `openhab/rules/irrigation.rules`:

```javascript
// ── CONFIGURATION ──────────────────────────────────────────────────
val STORE_CAPACITY_MM    = 40.0  // Max soil water store [mm]
val STORE_INITIAL_MM     = 20.0  // Starting value if no history [mm]
val STORE_IRRIGATE_MM    = 18.0  // Irrigate when store falls below this
val STORE_CRITICAL_MM    = 10.0  // Critical level (irrigate even if uncertain)
val RAIN_TOMORROW_SKIP   =  5.0  // Skip irrigation if this much rain forecast [mm]
val RAIN_TOMORROW_MAX_SKIP = 10.0 // Skip if max forecast exceeds this [mm]
val SPRINKLER_RATE_MM_H  =  8.0  // Your sprinkler output in mm/hour
val STORE_TARGET_MM      = 30.0  // Irrigate up to this level
// ───────────────────────────────────────────────────────────────────
```

### Parameter guide

**`STORE_CAPACITY_MM`** — Maximum water the soil can hold in the root zone.
- Sandy soil: 20–25 mm
- Loamy soil (typical Swiss Mittelland): 35–45 mm
- Clay-rich soil: 50–60 mm

**`STORE_IRRIGATE_MM`** — Threshold below which irrigation starts.
- A value of ~45% of capacity is a good starting point (18 mm for 40 mm capacity).
- Lower value = more drought-tolerant behaviour.

**`RAIN_TOMORROW_SKIP`** — Forecast rain amount that causes irrigation to be skipped.
- 5 mm is conservative (typical light rain). For lawns that need more water, raise to 8 mm.

**`SPRINKLER_RATE_MM_H`** — How much water your sprinkler delivers per hour.
- Measure it: place a flat container (e.g. a tuna tin) in the sprinkler zone, run for 30 min, measure depth, multiply by 2.

**`STORE_TARGET_MM`** — Target level after irrigation.
- Should be less than STORE_CAPACITY_MM to leave room for incoming rain.
- 30 mm (75% of 40 mm) is a reasonable default.

---

## Step 6 — Configure persistence

The soil store value (`IrrigationSoilStore`) must persist across openHAB restarts.

In `services/persistence/mapdb.persist` (or your chosen persistence service):

```
Strategies {
    default = everyChange
}
Items {
    IrrigationSoilStore : strategy = everyChange, restoreOnStartup
}
```

Without persistence, the store resets to `STORE_INITIAL_MM` after every restart.

---

## Step 7 — Connect your irrigation switch

The rule sends `ON`/`OFF` to the item `IrrigationValveSwitch`. Wire this to whatever controls your valve:

```java
// In irrigation.items — replace with your actual binding:
Switch IrrigationValveSwitch "Irrigation Valve" { channel="..." }

// Examples:
// Z-Wave switch:     { channel="zwave:device:xxx:switch_binary" }
// Shelly:            { channel="http:url:shelly:switch" }
// MQTT:              { channel="mqtt:topic:broker:irrigation:command" }
// Exec (GPIO script):{ channel="exec:command:valve:run" }
```

---

## Example configurations

| Location | Station | PLZ |
|----------|---------|-----|
| Wallisellen / Zurich | OPF (Opfikon) | 8304 |
| Bern | BEP (Belp) | 3001 |
| Basel | — use KAI (Kaiserstuhl) or OED (Ehrendingen) | 4001 |
| Winterthur | BUE (Bülach) | 8400 |
| St. Gallen | FLW (Flawil) | 9000 |
| Lucerne | ENT (Entlebuch) | 6000 |

See [examples/station_zurich_opfikon.md](../examples/station_zurich_opfikon.md) for a complete worked example.
