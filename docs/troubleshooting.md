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

This is **expected behaviour**, not a bug. The MeteoSwiss CSV is updated around 02:00 CET. If the rule runs before the CSV catches up, or if MeteoSwiss has a delay, the script falls back to the most recent available row.

The fallback is safe: at worst, the soil store credits the same rain twice on consecutive days (rare), which only slightly delays irrigation. Once the CSV updates, the value is correct again.

If you see this warning **every day**, the rule is running too early — check the cron expression and the Exec Thing `interval`.

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
