# openHAB Lawn Irrigation — MeteoSwiss Integration

A smart "should I irrigate tomorrow?" decision system for openHAB, based on real measured precipitation from MeteoSwiss (SwissMetNet) and a 7-day forecast. Uses a soil moisture balance model — no soil sensor required.

This project does **one thing**: every morning at 05:00, it decides whether to set your existing irrigation trigger switch to ON or OFF — shortly before your irrigation system starts. **Your existing setup handles the actual watering** (duration, valves, etc.).

---

## How it works

```
[MeteoSwiss OGD CSV]              [MeteoSwiss App API]
  Yesterday's measured rain         Forecast: rain tomorrow,
  from nearest station              Tmax/Tmin today
         │                                  │
         └──────────────┬───────────────────┘
                        ▼
            [openHAB rule — daily 05:00]
                        │
                        │  (refresh data → wait → compute)
                        │
              ┌─────────▼──────────┐
              │ Update soil store: │
              │  + rain yesterday  │   "virtual bucket" of soil moisture,
              │  − ET₀ today       │    clamped to 0–40 mm
              └─────────┬──────────┘
                        │
              ┌─────────▼──────────┐
              │ Decision logic     │
              │                    │
              │  store < critical  │  → trigger ON  (water urgently)
              │  store < threshold │
              │  & no rain coming  │  → trigger ON
              │  store < threshold │
              │  & rain coming     │  → trigger OFF (wait for rain)
              │  store ok          │  → trigger OFF
              └─────────┬──────────┘
                        ▼
              YOUR existing trigger switch
              → your irrigation system starts shortly after
                (e.g. 05:30) for its fixed deep-watering duration
```

Instead of a naive "did it rain last week?" rule, this model:
- **Drains the store on hot days** (high ET₀) → recognises drought even after recent rain
- **Fills the store on rainy days** (measured, not forecast) → grounded in reality
- **Skips irrigation when rain is coming** → avoids watering before storms
- **Maintains a persisted state** → survives openHAB restarts

---

## What you need before deploying

1. **An existing irrigation trigger switch in openHAB**. When ON, your current setup waters the lawn the next morning for a deep-watering duration you've measured manually with a cup. This project decides whether to set that switch.

2. **A persistence service** (MapDB or RRD4J) configured for the soil store item.

3. **HTTP Binding** and **Exec Binding** installed in openHAB.

4. **Internet access** from your openHAB server to:
   - `data.geo.admin.ch` (precipitation data)
   - `app-prod-ws.meteoswiss-app.ch` (forecast)

---

## Data sources

### 1. MeteoSwiss OGD — Precipitation stations (past)

```
https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip/{station}/ogd-smn-precip_{station}_d_recent.csv
```

- Free, no authentication, CC-BY licence
- Updated daily around 02:00 CET
- Daily precipitation totals in mm (column `rre150d0`)
- ~140 automatic precipitation stations across Switzerland
- Station list: [ogd-smn-precip_meta_stations.csv](https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip/ogd-smn-precip_meta_stations.csv)

### 2. MeteoSwiss App API — Forecast (future)

```
https://app-prod-ws.meteoswiss-app.ch/v2/plzDetail?plz={PLZ}00
```

- Unofficial but stable app backend, no authentication needed
- Returns 8-day forecast per Swiss postal code
- Key fields used: `forecast[1].precipitation`, `forecast[1].precipitationMax`, `forecast[0].temperatureMax/Min`

---

## File structure

```
openhab-lawn-irrigation/
├── README.md
├── docs/
│   ├── configuration.md           ← step-by-step setup
│   ├── model.md                   ← soil moisture model explained
│   └── troubleshooting.md
├── openhab/
│   ├── things/
│   │   └── irrigation_weather.things
│   ├── items/
│   │   └── irrigation.items
│   ├── rules/
│   │   └── irrigation.rules
│   └── scripts/
│       ├── rain_yesterday.sh      ← single-value, used by the rule
│       └── rain_lastNdays.sh      ← 7-day diagnostic sum (optional)
└── examples/
    ├── station_zurich_opfikon.md  ← worked example: Wallisellen
    └── find_your_station.md
```

---

## Quick start

1. [Find your nearest MeteoSwiss station](examples/find_your_station.md)
2. [Adapt the configuration](docs/configuration.md) — 4 places to change
3. Copy files to your openHAB config directory
4. `chmod +x` the shell scripts
5. Restart openHAB or reload the rule file

---

## Licence

MIT — use freely, adapt for your location, contribute improvements.
