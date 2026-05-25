# Example: Wallisellen / Zurich Area

This example documents the concrete configuration used for a garden in **Wallisellen (PLZ 8304)**, using the **Opfikon (OPF)** MeteoSwiss precipitation station.

---

## Station: OPF — Opfikon

| Property | Value |
|----------|-------|
| Abbreviation | `OPF` |
| Full name | Opfikon |
| Canton | ZH |
| Altitude | 424 m ü.M. |
| Exposition | Ebene (flat) |
| Data since | 1973 |
| Coordinates | 47.4376° N, 8.5603° E |
| Distance to Wallisellen | ~3 km |

The station is ideal for Wallisellen, Dübendorf, Kloten, and the Glattal area.

---

## Forecast: PLZ 8304 → `plz=830400`

The MeteoSwiss App API parameter for PLZ 8304 (Wallisellen/Gockhausen) is:
```
https://app-prod-ws.meteoswiss-app.ch/v2/plzDetail?plz=830400
```

---

## Soil assumptions (Glattal)

The Glattal area has predominantly **sandy loam** soil (influenced by post-glacial lake deposits). Suggested parameters:

```javascript
val Number STORE_CAPACITY_MM   = 35.0   // Sandy loam: 30–40 mm
val Number STORE_IRRIGATE_MM   = 15.0   // ~43% of capacity
val Number STORE_CRITICAL_MM   =  8.0   // ~23% of capacity
val Number STORE_TARGET_MM     = 28.0   // 80% of capacity
```

---

## Scripts

In `rain_station.sh` and `rain_yesterday.sh`:
```bash
STATION="opf"
```

---

## Things file excerpt

```java
Thing http:url:meteoSwissForecast "MeteoSwiss Forecast Wallisellen" [
    baseURL="https://app-prod-ws.meteoswiss-app.ch/v2/plzDetail?plz=830400",
    refresh=1800,
    timeout=10000,
    headers="User-Agent=openHAB"
]
```

---

## Typical seasonal ET₀ values (Zurich area)

| Month | Avg Tmax | Avg Tmin | ET₀ estimate |
|-------|----------|----------|-------------|
| April | 14°C | 5°C | 1.5 mm/day |
| May | 19°C | 9°C | 2.8 mm/day |
| June | 22°C | 13°C | 4.0 mm/day |
| July | 25°C | 15°C | 4.8 mm/day |
| August | 24°C | 14°C | 4.5 mm/day |
| September | 20°C | 11°C | 3.0 mm/day |

At 4–5 mm/day ET₀ in July, the soil store (35 mm) lasts ~7 days without rain — which matches the actual experience of Zurich summers.

---

## Nearby alternative stations

If OPF data is unavailable, these stations are also close:

| Station | Location | Distance |
|---------|----------|----------|
| `bue` | Bülach | ~10 km north |
| `kue` | Küsnacht ZH | ~12 km south |
| `dit` | Dietikon | ~15 km west |
| `hiw` | Hinwil | ~20 km east |
