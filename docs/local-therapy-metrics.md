<!--
  local-therapy-metrics.md
  xdrip

  Created by Paul Plant on 12/8/26.
  Copyright © 2026 Johan Degraeve. All rights reserved.
-->

# Local IOB and COB

IOB and COB are calculated automatically from eligible recorded treatments when
no configured provider supplies that metric. There are no calculation-enable switches.
Older saved `calculateLocalIOB` and `calculateLocalCOB` preferences are ignored.

Open **Settings → General → Treatments**, between Glucose Ranges and
Statistics. This uses the same grouped child screen and menu rows as other settings.
An introductory explanation is followed by separate, untitled Insulin Type and
Carb Duration sections. Externally owned options remain visible, disabled, and show
Automatic. CareLink disables only Insulin Type. The insulin footer uses Trio's terms
Duration of Insulin Action (DIA) and Insulin Peak Time, populated from the actual
local model (ten hours with peaks of 75/55/45 minutes). It does not claim that these
are Trio's complete defaults: Trio uses 75 minutes for rapid-acting and 55 for
ultra-rapid unless a custom peak is selected. Wording and peak handling were checked
against [Trio's IOB calculation](https://github.com/nightscout/Trio/blob/7b6470e5f0965cd31a04a7eb4c4f6c99dea31681/Trio/Sources/APS/OpenAPSSwift/Iob/IobCalculation.swift).
Treatment entry has no settings button or setup reminder.

Nightscout AID owns both metrics and disables both options. CareLink
owns IOB and leaves Carb Duration available for local COB. An external outage never
selects a local fallback. Saved model preferences remain intact across source changes.

A single Show IOB/COB switch in Home Screen settings controls the optional main-chart
curves, independently of calculations and the compact values. It defaults to on
when no explicit preference is stored. An explicit off preference remains off.

Local values show the amount and unit. Their details and accessibility descriptions identify them as estimates of recorded treatments.

An eligible bolus or carb treatment in the preceding 24 hours enables both
local metric displays, including while browsing history. Older history also enables
them within 24 hours before or after an eligible treatment. The window is defined by
`TherapyModelSettings.visibilityInterval`. Its exact endpoints are excluded.
Visibility is separate from calculation: before a treatment its contribution is zero,
and exhausted treatments also show zero. Only treatments at or before the selected
time contribute to amounts. Future, deleted and invalid amounts do not contribute. IOB includes
boluses only, excluding all basal types. Manual entries and imports from the active
therapy source use the existing record identities. Matching time/amount is not a
deduplication rule. No calculated values are exported as AID status or included in
clinical analytics.

## Models

IOB ports the exponential formula in
[OpenAPS/oref0 88cf032](https://github.com/openaps/oref0/blob/88cf032aa74ff25f69464a7d9cd601ee3940c0b3/lib/iob/calculate.js).
That implementation credits
[the original Loop formula discussion](https://github.com/LoopKit/Loop/issues/388#issuecomment-317938473).
The simple insulin picker offers NovoRapid (75-minute peak), Fiasp (55-minute peak)
and Lyumjev (45-minute peak). All use Trio's ten-hour default duration, including insulin's long, low-level tail. Peak
choices follow [Trio's documented guidance](https://triodocs.org/configuration/settings/algorithm/additionals/).
DIA is defined by `TherapyModelSettings.defaultInsulinDuration` (600 minutes).
Older custom peak preferences resolve to the nearest named preset. Older duration
preferences now use the fixed ten-hour model.

Unlike oref0's input wrapper, elapsed time is continuous rather than rounded to the
nearest minute. Boundary guards return the full bolus at time zero and zero at the
end. An algebraic expansion avoids a removable singularity when the intermediate
parameter `a` equals one. This is the bolus component, not AID net basal-plus-bolus IOB.

COB ports only `PiecewiseLinearAbsorption` from
[LoopKit 421c1a2](https://github.com/LoopKit/LoopKit/blob/421c1a256e76a7166ab2848cedba53162d34fda1/LoopKit/CarbKit/CarbMath.swift).
Absorption starts after ten minutes, increases in rate until 15% of the duration,
remains constant until 50%, then slows to zero at completion. Initial duration is
four hours, with 2 through 8 hours offered in one-hour steps. The help groups
2–3 hours as faster, 4–6 as normal and 7–8 as longer absorption. Longer absorption
may be useful when GLP-1 medication slows digestion. These labels describe the
selected estimate model, not a measured absorption rate. The GLP-1 explanation is
supported by [NIDDK medication guidance](https://www.niddk.nih.gov/health-information/diabetes/overview/insulin-medicines-treatments),
which describes slowed stomach emptying with these medicines. Older custom durations resolve to
the nearest supported choice. Duration excludes the
fixed delay. Meals are modeled independently and summed. This does not implement
OpenAPS glucose-responsive absorption or LoopKit's adaptive absorption system.

These are configurable model defaults, not individualized treatment settings.
Global setting changes recalculate both current and historical estimates. Historical
curves use the current model, not an audit trail of values previously displayed.

## Integration and freshness

`TherapyMetricsManager` reads detached treatments on the Core Data context, resolves
source ownership and supplies the same metrics to Home and companion payloads.
Inputs and chart series are cached by source, settings, revision and buffered time
range. Therapy curves reuse the glucose manager's buffered coverage, rounded outward
to hours. AID status history is retained and only missing edges are fetched when
scrolling. Source/revision changes reset it, disjoint jumps reload, and older edges
are trimmed. Small pans clip existing curves without fetching or regenerating them.
Cancelled queued chart requests are discarded before database work.
A failed read is distinct from an empty result. Saved treatment/status changes
invalidate caches. Stale in-flight generations cannot replace new data.

Foreground refreshes and existing glucose/background opportunities update values.
There is no added polling or background keepalive. Local companion snapshots expire
after 17 minutes, or at the 24-hour visibility deadline if sooner. Expired values
become unavailable. They are not extrapolated by the Watch or an extension.
New optional payload fields preserve decoding of older payloads.

Home therapy curves use the main glucose chart's plot, axes, gridlines and gestures.
Visible curves enable the same bottom space as basal rendering, once for both: the
existing -10 mg/dL baseline (0 on a 24-hour range). They remain independent of
whether treatment markers are shown. Screen Lock omits them.

Display constants set 15 U, 70 g and a 100 mg/dL reference height. From the shared
baseline, 15 U reaches that height. The 7 g/U ratio is preserved, so 70 g sits lower.
When either displayed maximum exceeds its limit, both curves are reduced by the
same factor. Negative external IOB is preserved and extends the lower domain as
needed. Glucose scaling at the top is unchanged. Lines use the bolus/carbohydrate treatment colors with opacity 1.0, immediately
above basal marks and below treatment symbols and glucose.

Local curves include five-minute samples and treatment/end/visibility boundaries.
Treatments have before/after points at the same timestamp for vertical jumps.
External curves read source-filtered device-status history from Core Data. Incomplete
pump/uploader rows do not interrupt otherwise fresh metric readings. Repeated uploads of the same AID calculation collapse onto its stored calculation
timestamp, using the latest updated finite value per metric. Upload time is the
fallback when no valid calculation timestamp exists. Stale reuploads do not revive
old estimates. Genuine AID changes, including net basal IOB changes, remain intact. Valid historical points join by linear interpolation when strictly less than 32 minutes apart
(`TherapyModelSettings.externalChartJoinInterval`). This is presentation between recorded AID
values, not a local estimate or a change to current-value freshness. A final reading is held
only until its existing 17-minute freshness deadline. Gaps of 32 minutes or more remain gaps.
No local treatment inputs are read for charts when both metrics are externally owned. Neither these display coordinates
nor the display ratio change the calculated amounts.

## Reference verification

`TherapyMetricsTests` includes numerical goldens from the pinned oref0 JavaScript,
LoopKit absorption breakpoints, allowed-parameter monotonicity, timing/visibility,
source ownership, transport compatibility and persisted treatment selection.
Actual build and test outcomes are reported separately when delivering the change.

## License notices

The ports preserve the following upstream MIT notices. They are also available in
the app's license information.

The MIT License (MIT)

Copyright (c) 2015-2019 OpenAPS Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
The MIT License (MIT)

Copyright (c) 2015 Nathan Racklyeft
Copyright (c) 2016 LoopKit Authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Runtime hardening

Home suspends therapy chart requests outside the active scene. A serial worker performs chart
reads and sampling, checking cancellation between samples and before caching results. Main-thread
input cache misses schedule an asynchronous read and temporarily report unavailable. They never
wait for Core Data or turn a failed read into zero. Device-status saves retain treatment inputs,
while treatment saves invalidate them. Companion value-only refreshes are coalesced to one per
minute. Source and availability transitions remain immediate. No background keepalive is added.
Bluetooth RSSI display reads a small copied snapshot instead of waiting on the Bluetooth queue.
