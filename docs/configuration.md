# Configuration Guide

Four things to adapt for your installation. This document walks through each one.

---

## Step 1 — Find your MeteoSwiss precipitation station

Download the station list:
```
https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip/ogd-smn-precip_meta_stations.csv
```

Open in Excel/Numbers/LibreOffice and pick the station closest to your garden. Relevant columns:

| Column | Notes |
|--------|-------|
| `station_abbr` | The code you'll use everywhere (e.g. `OPF`) — **lowercase in URLs** |
| `station_name` | Human-readable name |
| `station_canton` | Filter by canton first |
| `station_coordinates_wgs84_lat/lon` | For distance calculation |

Verify the URL works:
```bash
curl -s "https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip/opf/ogd-smn-precip_opf_d_recent.csv" | head -3
```

You should see CSV rows. If it 404s, recheck the abbreviation (must be lowercase).

See [examples/find_your_station.md](../examples/find_your_station.md) for a quick lookup table per major city.

---

## Step 2 — Find your postal code (PLZ)

The MeteoSwiss forecast API uses a 4-digit Swiss PLZ, zero-padded to 6 digits:

| Your PLZ | API parameter |
|----------|---------------|
| 8304 | `plz=830400` |
| 3001 | `plz=300100` |
| 6300 | `plz=630000` |

---

## Step 3 — Edit the four places that need your values

### 3a. Shell scripts (`openhab/scripts/*.sh`)

Edit both scripts — change the default station:

```bash
STATION="${METEO_STATION:-opf}"   # ← replace "opf" with your station, lowercase
```

Test from the command line:
```bash
bash rain_yesterday.sh
# → outputs a number like "4.2"
```

### 3b. Things file (`openhab/things/irrigation_weather.things`)

Change the `baseURL` to use your PLZ:

```java
Thing http:url:meteoSwissForecast "MeteoSwiss Forecast" [
    baseURL="https://app-prod-ws.meteoswiss-app.ch/v2/plzDetail?plz=830400",
    //                                                              ^^^^^^
    //                                              your PLZ + "00"
```

Confirm the script paths match where you'll install them on your openHAB server:
```java
command="/etc/openhab/scripts/rain_yesterday.sh",
```

### 3c. Items file (`openhab/items/irrigation.items`)

The file **does not define** the irrigation trigger switch — it expects you to already have one. Make sure your existing trigger switch is named so the rule can find it.

If your switch is called e.g. `BewaesserungMorgen`, you need to either:
- Rename it to `IrrigationTrigger`, **or**
- Edit the rule file (see step 3d below)

### 3d. Rules file (`openhab/rules/irrigation.rules`)

If you didn't rename your existing trigger switch, change the two lines near the bottom of the rule:

```javascript
if (doIrrigate) {
    IrrigationTrigger.sendCommand(ON)      // ← use your switch name
} else {
    IrrigationTrigger.sendCommand(OFF)     // ← use your switch name
}
```

### 3e. Exec Binding whitelist

openHAB 4+ requires commands to be explicitly whitelisted. Add your script paths to:

```
$OPENHAB_CONF/misc/exec.whitelist
```

One command per line, exactly as configured in the Thing:
```
/etc/openhab/scripts/rain_yesterday.sh
```

Without this file, the Exec Binding will refuse to run the scripts (state stays NULL).

---

## Step 4 — Configure persistence

The soil store (`IrrigationSoilStore`) must persist across restarts.

Add to `services/persistence/mapdb.persist` (or your persistence service config):

```
Strategies {
    default = everyChange
}
Items {
    IrrigationSoilStore : strategy = everyChange, restoreOnStartup
}
```

Without this, the store resets to 20 mm on every openHAB restart and the model produces wrong decisions for several days afterwards.

---

## Step 4b — Refill the soil store after irrigation

The decision rule only **debits** the soil store (rain in, ET₀ out). After a real irrigation run, the store must be **credited** back — otherwise it drifts toward 0 and the rule triggers irrigation every single day, regardless of how much water actually fell on the lawn.

This repository ships a separate rule **"Irrigation — Refill store after run"** that reacts to `IrrigationTrigger received command OFF` and posts `STORE_REFILL_TARGET_MM` to `IrrigationSoilStore`.

For this to work, **your irrigation block must send `OFF` to the trigger when it finishes the run.** Most setups already do this. If yours doesn't, either:
- Add a `sendCommand(IrrigationTrigger, OFF)` at the end of your irrigation block, **or**
- Edit the refill rule to react to your own "irrigation done" signal.

### Calibrating `STORE_REFILL_TARGET_MM`

The default is `40.0` mm (= `STORE_CAPACITY_MM`, i.e. full refill). In practice, a single irrigation run rarely saturates the soil all the way to field capacity. To calibrate:

1. Place 4–6 straight-walled cups (e.g. tuna cans) randomly on the lawn before a run.
2. Run a normal irrigation cycle.
3. Measure the average water depth in the cups in mm.
4. Set `STORE_REFILL_TARGET_MM` to that value (cap it at `STORE_CAPACITY_MM`).

Example: a 25-minute run delivering 30 mm in cups, on a soil with 40 mm capacity → set `STORE_REFILL_TARGET_MM = 30.0`. The next morning's decision rule will then start at 30 and debit ET₀ from there.

### Why a separate rule and not inline?

Keeping refill logic out of the user's irrigation block means:
- Users with different watering controls (timers, KNX, Z-Wave, scripts) only need to ensure their setup eventually sends `OFF` to the trigger.
- The model's "credit" is tied to the trigger lifecycle, not to a specific implementation.

---

## Step 5 — Tune the irrigation model (optional)

The defaults work for typical Swiss Mittelland conditions. If your soil or climate differs, adjust the values at the top of `openhab/rules/irrigation.rules`:

```javascript
val Number STORE_CAPACITY_MM      = 40.0   // Soil water capacity [mm]
val Number STORE_INITIAL_MM       = 20.0   // Starting value, first run
val Number STORE_REFILL_TARGET_MM = 40.0   // Store value after a run (≤ capacity)
val Number STORE_IRRIGATE_MM      = 18.0   // Irrigate below this
val Number STORE_CRITICAL_MM      = 10.0   // Critical: irrigate even with rain forecast
val Number RAIN_TOMORROW_SKIP_MM  =  5.0   // Skip if forecast >= this
val Number RAIN_TOMORROW_MAX_SKIP = 10.0   // Skip if max forecast >= this
val Number RAIN_TODAY_SKIP_MM     =  3.0   // Skip if today already has/will have this much
val Number ET0_MAX_MM             =  8.0   // Cap on daily evapotranspiration
```

### Tuning guide

| Parameter | Lower it if... | Raise it if... |
|-----------|---------------|----------------|
| `STORE_CAPACITY_MM` | Sandy soil (20–25) | Clay soil (50–60) |
| `STORE_IRRIGATE_MM` | You want a drier, drought-hardened lawn | Your lawn dries out before the rule triggers |
| `STORE_REFILL_TARGET_MM` | Cup test shows your run delivers less than capacity | Always leave at `STORE_CAPACITY_MM` for full refill |
| `RAIN_TODAY_SKIP_MM` | You want to skip irrigation even on light rain days | You want to water through light morning drizzle |
| `RAIN_TOMORROW_SKIP_MM` | You want to be more aggressive (water even with light rain forecast) | You want to be conservative (let any rain do the work) |

The defaults assume **loamy soil, ~40 mm root zone capacity** (typical for Glattal/Mittelland).

---

## Step 6 — When does the rule run?

**Default: every morning at 05:00.** Adjust to fit *just before* your irrigation system actually starts watering.

The rule itself force-refreshes the MeteoSwiss data at the start of each run, then waits 8 seconds for the fetch to complete before computing. So you don't need to align the Exec/HTTP poll schedule with the rule — you just need internet connectivity at rule time.

To change the time, edit the cron expression in the rule:
```javascript
Time cron "0 0 5 ? * * *"
//             ^
//             hour of day (24h format)
```

If your irrigation starts at e.g. 06:00, use `"0 30 5 ? * * *"` (05:30) to leave a 30-minute buffer.

### Why morning and not the evening before?

- The MeteoSwiss `rka150d0` value for yesterday is published ~02:00 local
- The forecast for today/tomorrow is freshest in the morning
- Minimal gap between decision and execution means no weather surprises

---

## Worked example

| Location | Station (lowercase) | PLZ | API param |
|----------|--------------------|------|------------|
| Wallisellen / Glattal | `opf` (Opfikon) | 8304 | `plz=830400` |
| Bern Stadt | `bep` (Belp) | 3001 | `plz=300100` |
| Basel | `kai` (Kaiserstuhl) | 4001 | `plz=400100` |
| Winterthur | `bue` (Bülach) | 8400 | `plz=840000` |
| St. Gallen | `flw` (Flawil) | 9000 | `plz=900000` |
| Lugano | `col` (Coldrerio) | 6900 | `plz=690000` |

See [examples/station_zurich_opfikon.md](../examples/station_zurich_opfikon.md) for a complete worked example.
