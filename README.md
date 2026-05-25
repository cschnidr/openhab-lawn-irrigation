# openHAB Lawn Irrigation — MeteoSwiss Integration

Automated lawn irrigation control for openHAB, based on real measured precipitation data from MeteoSwiss (SwissMetNet network) and a 7-day weather forecast. Uses a soil moisture balance model to decide whether and how long to irrigate — no soil sensor required.

---

## How it works

Instead of a simple "did it rain?" threshold, this solution maintains a **virtual soil moisture store** (in mm of water). Every morning it:

1. **Fetches yesterday's actual rainfall** from the nearest MeteoSwiss precipitation station (OGD open data, no API key required)
2. **Estimates evapotranspiration** (ET₀) from today's forecast temperatures using a simplified Hargreaves formula
3. **Updates the soil store**: `store = store + rain − ET₀` (clamped to 0–40 mm)
4. **Checks tomorrow's forecast**: if significant rain is coming, waits
5. **Decides**: irrigate or not, and for how long

This means the system reacts correctly to hot dry spells (store drains fast) and to heavy rain events (store fills up, irrigation pauses for days).

```
[MeteoSwiss OGD CSV]          [MeteoSwiss App API]
  Station OPF (Opfikon)         Forecast (7 days)
  Measured rain [mm/day]        Tmax, Tmin, precip tomorrow
         │                              │
         └──────────┬───────────────────┘
                    ▼
         [openHAB Rule — daily 06:00]
                    │
         ┌──────────▼──────────┐
         │  Soil Store Update  │  rain_yesterday − ET₀(Tmax,Tmin)
         │  Clamped 0–40 mm    │
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────┐
         │  Decision Logic     │  store < threshold AND no rain tomorrow?
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────┐
         │  Irrigate: ON/OFF   │  + calculated duration in minutes
         └─────────────────────┘
```

---

## Data sources

### 1. MeteoSwiss OGD — Precipitation stations (past)

**URL pattern:**
```
https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip/{station_lower}/ogd-smn-precip_{station_lower}_d_recent.csv
```

- Free, no authentication, CC-BY licence
- Updated daily around 02:00 CET
- Contains daily precipitation totals in mm (`rre150d0` column)
- ~140 automatic precipitation stations across Switzerland
- Station list: [ogd-smn-precip_meta_stations.csv](https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip/ogd-smn-precip_meta_stations.csv)

### 2. MeteoSwiss App API — Forecast (future)

**URL pattern:**
```
https://app-prod-ws.meteoswiss-app.ch/v2/plzDetail?plz={PLZ}00
```

- Unofficial but stable app backend, no authentication needed
- Returns 8-day forecast per Swiss postal code
- Key fields used: `forecast[1].precipitation`, `forecast[1].precipitationMax`, `forecast[1].temperatureMax`, `forecast[1].temperatureMin`
- Refresh every 30 minutes is sufficient

---

## File structure

```
openhab-lawn-irrigation/
├── README.md                        ← this file
├── docs/
│   ├── configuration.md             ← how to adapt for your location
│   ├── model.md                     ← soil moisture model explained
│   └── troubleshooting.md           ← common issues
├── openhab/
│   ├── things/
│   │   └── irrigation_weather.things
│   ├── items/
│   │   └── irrigation.items
│   ├── rules/
│   │   └── irrigation.rules
│   ├── scripts/
│   │   └── rain_station.sh          ← fetches + sums rain from MeteoSwiss CSV
│   └── transform/
│       └── (none required)
└── examples/
    ├── station_zurich_opfikon.md    ← example: Wallisellen/Zurich area
    └── find_your_station.md         ← how to find the nearest station
```

---

## Quick start

1. [Find your nearest MeteoSwiss station](examples/find_your_station.md)
2. [Adapt the configuration](docs/configuration.md)
3. Copy files from `openhab/` to your openHAB config directory
4. Make the script executable: `chmod +x scripts/rain_station.sh`
5. Restart openHAB or reload the rule file

---

## Requirements

- openHAB 3.x or 4.x
- HTTP Binding (`openhab-binding-http`)
- Exec Binding (`openhab-binding-exec`)
- JavaScript (GraalVM) or DSL rules support
- Persistence service (e.g. MapDB or RRD4J) for the soil store item
- Internet access from the openHAB server

---

## Licence

MIT — use freely, adapt for your location, contribute improvements.
