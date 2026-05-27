# Troubleshooting

---

## Shell script returns 0.0 or fails

**Test the script directly on the openHAB server:**
```bash
sudo -u openhab bash /etc/openhab/scripts/rain_yesterday.sh
```

**Test if the URL is reachable:**
```bash
curl -s "https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip/opf/ogd-smn-precip_opf_d_recent.csv" | head -5
```

**Check the station abbreviation is lowercase.** `OPF` will fail; `opf` works.

**Check permissions:**
```bash
chmod +x /etc/openhab/scripts/*.sh
```

---

## Script logs "WARN: <date> not in CSV, using last available row"

This is **expected behaviour**, not a bug. The MeteoSwiss CSV is updated around 02:00 CET (for the `rka150d0` calendar-day column we use). Brief delays do occur.

The fallback is safe: at worst, the soil store credits the same rain twice on consecutive days, which only slightly delays irrigation. Once the CSV updates, the value is correct again.

If you see this warning **every day**, either:
- The rule is running too early — check the cron expression
- You may have set `METEO_COLUMN=3` (rre150d0, 06–06 UTC) which is updated much later — switch back to the default (column 4, rka150d0)

---

## Why two precipitation columns?

The CSV has two columns with different time windows:

| Column | Field | Window | Available |
|--------|-------|--------|-----------|
| 3 | `rre150d0` | 06 UTC – 06 UTC next day | ~08:00 local next day |
| 4 | `rka150d0` | 00 UTC – 00 UTC (calendar day) | ~02:00 local next day |

The scripts use **column 4 (rka150d0)** by default. It matches what people mean by "yesterday" and is available much earlier. To use column 3 instead (rarely useful), set `METEO_COLUMN=3` as environment variable in the Exec Thing.

---

## HTTP Thing shows OFFLINE

**Test the URL directly:**
```bash
curl -s "https://app-prod-ws.meteoswiss-app.ch/v2/plzDetail?plz=830400" | head -c 200
```

**Check the PLZ format** — must be 4-digit PLZ + `00`, e.g. `830400` not `8304`.

The MeteoSwiss app API is unofficial. If it goes offline, you can substitute Open-Meteo:
```
https://api.open-meteo.com/v1/forecast?latitude=47.41&longitude=8.59&daily=precipitation_sum,temperature_2m_max,temperature_2m_min&timezone=Europe%2FZurich
```

---

## Soil store keeps resetting to 20 mm

**Cause:** Persistence is not configured for `IrrigationSoilStore`.

**Fix:** Add to your persistence config:
```
IrrigationSoilStore : strategy = everyChange, restoreOnStartup
```

Verify after restart: the item should have a numeric value (not NULL).

---

## Lawn gets watered every day even though store should drop slowly

**Symptom:** `IrrigationSoilStore` reaches 0 within a few days and then stays there. The trigger is `ON` every morning.

**Cause:** The decision rule debits the store with ET₀ each day but nothing credits it back after irrigation. So the store decays toward 0 even when the irrigation actually delivered water — and the rule keeps triggering "store critical" forever.

**Fix:** Make sure the refill rule (`Irrigation — Refill store after run`) is in your `irrigation.rules` and that your irrigation block sends `OFF` to `IrrigationTrigger` when it finishes its run. See [configuration.md → Step 4b](configuration.md).

**Verify:** On the day after a run, check the log:
```
Irrigation - Soil store refilled to 40.0 mm after irrigation run
```

If you only see this when the store was already at capacity (because the decision rule sent OFF on a dry, well-supplied day), the guard `if (IrrigationTrigger.state != ON) return` is doing its job — refill only happens when the trigger was actually ON before the OFF arrived.

---

## Trigger switch is never set

**Check 1:** Does the rule know the correct item name? If you didn't rename your switch to `IrrigationTrigger`, edit the rule to use your actual item name.

**Check 2:** Check the openHAB log for the rule's output:
```bash
grep -i "Irrigation" /var/log/openhab/openhab.log | tail -20
```

The rule logs every step. You should see lines like:
```
Irrigation - Decision: ON → NIEDRIG: Speicher 12 mm — bewässern, kein Regen morgen
```

**Check 3:** Read the `IrrigationDecisionReason` item state in the openHAB UI — it shows the plain-text reason for the last decision.

---

## Trigger always set to OFF

**Check `IrrigationSoilStore`** — if it shows 40 (full capacity), either:
- `STORE_CAPACITY_MM` is too high for actual conditions, or
- `IrrigationRainYesterday` reports too much rain (e.g. CSV gives a 7-day value instead of one day → check you wired the correct Exec channel)

**Check `IrrigationRainTomorrowMax`** — the forecast uncertainty check (`RAIN_TOMORROW_MAX_SKIP=10mm`) may trigger often. Raise to 15 if it's blocking too much.

---

## Manual reset of the soil store

If the model gets out of sync (you watered manually, system was offline, etc.):

```bash
curl -s http://localhost:8080/rest/items/IrrigationSoilStore/state \
  -X PUT -H "Content-Type: text/plain" -d "25.0"
```

Or update via the openHAB UI directly.

---

## Debug items

These items are useful for understanding what the model is "thinking":

| Item | Shows |
|------|-------|
| `IrrigationSoilStore` | Current soil water content [mm] |
| `IrrigationET0Today` | Estimated daily evapotranspiration [mm] |
| `IrrigationRainYesterday` | Yesterday's measured rain [mm] |
| `IrrigationRainTomorrow` | Forecast rain tomorrow [mm] |
| `IrrigationRainTomorrowMax` | Forecast upper bound for rain tomorrow [mm] |
| `IrrigationDecisionReason` | Plain-text explanation of last decision |
| `IrrigationRainLast7d` | 7-day rain sum (diagnostic, not used in model) |

A good test: log the decision item over time. Over a month, you should see:
- Hot dry weeks → store decreases day by day, trigger goes ON
- After heavy rain → store jumps up, trigger stays OFF for several days
- Cool wet periods → store stays high, trigger always OFF
