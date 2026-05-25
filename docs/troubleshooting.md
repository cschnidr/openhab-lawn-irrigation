# Troubleshooting

---

## Shell script returns empty or 0

**Symptoms:** `IrrigationRainYesterday` always shows 0 or NULL.

**Check 1:** Run the script manually from the openHAB server:
```bash
sudo -u openhab bash /etc/openhab/scripts/rain_station.sh
```

**Check 2:** Test if the URL is reachable:
```bash
curl -s "https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn-precip/opf/ogd-smn-precip_opf_d_recent.csv" | head -5
```

**Check 3:** Verify the station abbreviation is lowercase in the script. `OPF` will fail; `opf` is correct.

**Check 4:** Check Exec binding permissions. The openHAB user must be able to run the script:
```bash
sudo -u openhab /etc/openhab/scripts/rain_station.sh
```
If permission denied: `chmod +x /etc/openhab/scripts/rain_station.sh`

---

## HTTP Thing for MeteoSwiss API shows OFFLINE

**Check 1:** Test the URL directly:
```bash
curl -s "https://app-prod-ws.meteoswiss-app.ch/v2/plzDetail?plz=830400" | head -c 200
```

**Check 2:** Verify the PLZ format — it must be 4-digit PLZ followed by `00`, e.g. `830400` not `8304`.

**Check 3:** The MeteoSwiss app API is unofficial. If it goes offline, switch to the Open-Meteo forecast API (see [configuration.md](configuration.md) for alternatives).

---

## Soil store drifts to 0 and stays there

**Cause:** Persistence is not configured for `IrrigationSoilStore`. Without persistence, the value resets to `STORE_INITIAL_MM` on every openHAB restart and the rule may not update it correctly.

**Fix:** Add to your persistence configuration:
```
IrrigationSoilStore : strategy = everyChange, restoreOnStartup
```

Restart openHAB and verify the item has a numeric value (not NULL).

---

## Irrigation runs every day despite rain

**Check 1:** Is `IrrigationRainYesterday` updating correctly? Check the item state in the openHAB UI.

**Check 2:** Is the soil store persisting between restarts? (see above)

**Check 3:** Is `STORE_CAPACITY_MM` set too low for your soil? If capacity is 20 mm and ET₀ is 5 mm/day, even 10 mm of rain only fills the store for 2 days.

**Check 4:** Check the `IrrigationDecisionReason` item — it will explain why the rule decided to irrigate.

---

## Irrigation never runs despite dry conditions

**Check 1:** Is `IrrigationRainMorgenMax` showing a high value? The forecast uncertainty check (`RAIN_TOMORROW_MAX_SKIP`) may be triggering. Lower it from 10 to 15 mm.

**Check 2:** Is the valve switch item correctly linked to your hardware? Test by sending ON directly:
```
openhab-cli send IrrigationValveSwitch ON
```

**Check 3:** Check `IrrigationSoilStore` — if it shows 40 (full capacity), either the rain values are too high or the store was manually reset too high.

---

## Rule runs but logs show errors

**View rule logs:**
```bash
grep -i "Irrigation" /var/log/openhab/openhab.log | tail -30
```

**Common errors:**
- `NULL` state on an item → persistence not configured, or Things not yet online
- `ClassCastException` → state type mismatch; check that Number items have numeric states
- Script timeout → the shell script is taking too long; check network connectivity

---

## Resetting the soil store

If the model gets out of sync (e.g. you manually irrigated, or had a dry spell without openHAB running), reset the store via the openHAB console or REST API:

```bash
# Set store to 25 mm (roughly half capacity)
curl -s http://localhost:8080/rest/items/IrrigationSoilStore/state \
  -X PUT -H "Content-Type: text/plain" -d "25.0"
```

Or use the openHAB UI to manually update the item state.

---

## Checking what happened

The following items are useful for debugging:

| Item | What it shows |
|------|--------------|
| `IrrigationSoilStore` | Current soil water content [mm] |
| `IrrigationET0Today` | Estimated evapotranspiration today [mm] |
| `IrrigationRainYesterday` | Measured rain from station [mm] |
| `IrrigationRainTomorrow` | Forecast rain tomorrow [mm] |
| `IrrigationDurationMinutes` | Calculated irrigation duration [min] |
| `IrrigationDecisionReason` | Plain-text explanation of today's decision |
