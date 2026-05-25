# Soil Moisture Model

This document explains the science behind the irrigation decision logic.

---

## Why not just use a rain threshold?

A simple rule like "skip irrigation if it rained more than 10 mm in the last 7 days" fails in two common situations:

- **Hot dry week after rain**: 15 mm fell 5 days ago, but 30°C heat has evaporated it all. The lawn still needs water.
- **Rain just yesterday**: 8 mm fell yesterday. The threshold says "no irrigation" — but actually 8 mm is fine for a day, not a week.

A soil moisture balance correctly handles both cases.

---

## The virtual soil store

The model tracks a single state variable: **the current water content of the soil root zone**, in mm.

This is a standard agronomic concept. 1 mm of soil water = 1 litre per m². A typical lawn root zone (top 15–20 cm) holds between 20 and 50 mm of plant-available water, depending on soil texture.

```
Store [mm]
  40 ┤████████████████████████  ← capacity (field capacity)
  30 ┤████████████████████████  ← target after irrigation
  18 ┤──────────────────────── ← irrigation threshold
  10 ┤──────────────────────── ← critical threshold
   0 ┤                          ← wilting point
```

Each day, the store is updated:

```
store_new = clamp(store_old + rain_yesterday − ET₀_today, 0, CAPACITY)
```

---

## Evapotranspiration estimation (ET₀)

Evapotranspiration (ET₀) is the combined water loss from soil evaporation and plant transpiration, in mm/day. It depends primarily on temperature, solar radiation, humidity, and wind.

Without a full weather station, we use the **simplified Hargreaves-Samani formula**, which needs only Tmax and Tmin:

```
ET₀ = 0.0023 × (Tmean + 17.8) × sqrt(Tmax − Tmin) × Ra
```

Where:
- `Tmean = (Tmax + Tmin) / 2` in °C
- `Ra` ≈ 14.3 mm/day (extraterrestrial radiation at ~47°N in summer)
- Result is clamped to 0–8 mm/day (physically plausible range for Switzerland) 

The original Hargreaves-Samani paper uses `sqrt(Tmax − Tmin)` as a proxy for solar radiation — not `Tmax` directly.

This formula is well-validated for Swiss Mittelland conditions. It underestimates ET₀ on very sunny, windy days and overestimates it on cool, overcast days — but averages out well over a week.

**Typical values for the Zurich area:**

| Condition | Tmax | Tmin | ET₀ |
|-----------|------|------|-----|
| Cool spring day | 15°C | 6°C | ~1.5 mm/day |
| Typical summer day | 25°C | 14°C | ~4.0 mm/day |
| Hot summer day | 32°C | 18°C | ~6.5 mm/day |
| Heatwave | 37°C | 22°C | ~8.0 mm/day |

---

## Decision logic

```
Every morning at 05:00:

1. Force-refresh all data sources (rain measurements + forecasts)
2. Fetch yesterday's rain from MeteoSwiss station (measured)
3. Fetch Tmax, Tmin from MeteoSwiss forecast (today)
4. Fetch rain_today and rain_tomorrow from MeteoSwiss forecast

5. Calculate ET₀ from Tmax, Tmin
6. Update store = clamp(store + rain_yesterday − ET₀, 0, capacity)

Priority-ordered decision:
7. If rain_today ≥ 3mm                       → SKIP   (already wet / will be)
8. If store < critical                       → IRRIGATE (urgent, regardless)
9. If store < threshold AND no rain tomorrow → IRRIGATE
10. If store < threshold AND rain tomorrow   → SKIP   (let rain top up)
11. If store >= threshold                    → SKIP
```

### Why "rain today" overrides everything

At 05:00, three rain values are relevant:

- **Yesterday's rain** comes from the station CSV (`rka150d0`). It only covers up to midnight last night.
- **Today's rain forecast** covers the entire current day — at 05:00, this is partly "already fallen overnight" and partly "remaining hours".
- **Tomorrow's rain forecast** covers the next day.

If 8 mm fell between 02:00 and 04:30, this is **not yet visible** in yesterday's CSV measurement — but it does appear in `forecast[0].precipitation` (today). Without the today-rain check, the rule would irrigate a freshly-soaked lawn.

The 3 mm threshold for skip is intentionally lower than the 5 mm "tomorrow" threshold. Reason: rain that has *already happened* or is *imminent* is much more certain than a 24h forecast.

---

## Model limitations

- **No wind correction**: ET₀ is slightly underestimated on windy days.
- **No shade correction**: The model assumes full sun exposure. Shaded lawns may need less irrigation.
- **Forecast uncertainty**: The "rain tomorrow" decision relies on a probabilistic forecast. Occasionally the model will irrigate before unexpected rain, or wait for rain that doesn't materialise. This is acceptable — a missed irrigation or an extra one rarely harms a lawn.
- **Initial store value**: On first run, the store starts at 50% capacity. It reaches a realistic value after 3–5 days.
- **Soil texture**: The capacity parameter must be set correctly for your soil. An incorrect capacity shifts the thresholds but doesn't break the model.

---

## Data source: which precipitation column?

The MeteoSwiss station CSVs contain two daily precipitation columns:

| Field | Time window | Available from |
|-------|-------------|----------------|
| `rka150d0` | 00 UTC to 00 UTC (calendar day) | ~02:00 local, next day |
| `rre150d0` | 06 UTC to 06 UTC next day | ~08:00 local, next day |

This project uses **`rka150d0`** (column 4 in the CSV). It matches the everyday meaning of "yesterday" and is available much earlier — important because the evening decision rule (21:00) needs yesterday's value to already be in the CSV.

In real-world data you will see rows where `rre150d0` is empty but `rka150d0` is populated. That's the data feed catching up: rka is published soon after midnight UTC, rre only after 06 UTC the following day.

---

## Further reading

- Hargreaves & Samani (1985): "Reference crop evapotranspiration from temperature" — the original paper
- FAO Irrigation and Drainage Paper 56 (Allen et al., 1998): the standard reference for ET₀ calculation
- MeteoSwiss OGD documentation: [data.geo.admin.ch](https://data.geo.admin.ch)
