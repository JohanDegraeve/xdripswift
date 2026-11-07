# Experimental features

Settings → **Experimental features**. Everything here is off by default and only changes the
main chart on the Home screen; widgets, the watch, alerts, Nightscout and AID sharing are not
affected. The models are ported from JugglucoNG (see `THIRD_PARTY_NOTICES.md`).

## Glucose on the chart

**Points** is xDrip's usual one dot per reading. **Line** joins the readings in their range
colour, as JugglucoNG does. The line breaks where two readings are more than 17 minutes apart
(JugglucoNG `GlucoseChartGap`), so missing data still looks missing.

## Glucose prediction

A dashed line to the right of the main chart, for 1–4 hours (default 2). It is JugglucoNG's
`GlucosePredictionKernel`:

- it starts at the newest reading, and only if that reading is at most 15 minutes old;
- **Follow the trend** adds the recent slope that the logged treatments do not explain
  (least squares over up to 10 readings in the last 45 minutes, at most 3 mg/dL or
  0.16 mmol/L a minute), fading as `t·e^(−t/70)`;
- a slow pull toward the middle of the low/high range: 18 % of the distance over about 4 hours;
- the effect of logged treatments from the last 36 hours:
  - carbs: `grams ÷ carb ratio × sensitivity`, absorbed along a smoothstep over
    `grams ÷ absorption rate` (30 minutes to 6 hours);
  - boluses: `units × sensitivity`, delivered along the insulin's action curve;
  - exercise: JugglucoNG's unknown-intensity drop for the logged duration;
  - basal and premixed insulins are not counted, as in JugglucoNG presets.

Defaults are JugglucoNG's: sensitivity 54 mg/dL (3.0 mmol/L) per unit, carb ratio 10 g/U,
absorption 35 g/h. It is an estimate for orientation, never a dosing tool.

## Insulins

Each insulin has its own action curve from JugglucoNG's catalogue (model version 3): Fiasp,
Lyumjev (dose-dependent), NovoRapid/NovoLog, Humalog, Apidra, regular, NPH, Lantus, Toujeo,
Levemir, Tresiba, Awiqli, U-500, Ryzodeg and the premixes. xDrip has no body weight, so curves
measured per kilogram use the study's reference dose.

- A bolus or basal injection uses the insulin named in its notes ("Tresiba", "NovoRapid",
  "Humalog Mix 25", Ukrainian names too). With the feature on, the treatment editor offers a
  picker for boluses and a list for basal injections. Otherwise the default bolus insulin
  (initially the Treatments insulin type) or basal insulin applies.
- **Show insulin activity on the chart** draws how fast each insulin is working, in units per
  hour, as coloured layers stacked along the bottom (JugglucoNG `InsulinActivityStack`). One
  dose's layer adds up to the dose. Steady-state curves (Toujeo, Tresiba) are reduced to one
  daily dose as `S(t) − S(t + 24 h)`. A curve ends where its source stopped measuring.
- The IOB/COB numbers and curves of the Treatments settings are unchanged.

Not ported yet: JugglucoNG's adaptive forecast, per-hour profiles, food macros and activity
intensity.
