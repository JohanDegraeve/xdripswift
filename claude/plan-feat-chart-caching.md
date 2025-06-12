# Glucose Chart Caching Implementation Plan

## Problem Summary
The glucose chart is being recalculated every 15 seconds via a timer, even when no new data is available. This causes:
- Unnecessary performance overhead
- Chart "jumping" or resetting while user is viewing/scrolling
- Battery drain from constant recalculation

## Root Cause
In `RootViewController.swift`, a timer calls `updateLabelsAndChartWithPredictions()` every 15 seconds, which always calls `updateChartWithResetEndDate()`, forcing a complete chart regeneration.

## Additional Optimization
The 15-second timer interval can be increased to 60 seconds since:
- "Minutes ago" label only needs updating once per minute
- Libre 2 provides new data every minute anyway
- This reduces timer wake-ups by 75%
- Labels will still update immediately when new data arrives

## Solution Design

### 1. Add Smart Caching System
Create a caching mechanism that tracks when chart data actually needs updating:

```swift
class GlucoseChartCache {
    private var lastChartUpdateTimestamp: Date?
    private var lastReadingTimestamp: Date?
    private var lastTreatmentTimestamp: Date?
    private var lastChartWidth: Int?
    private var cachedChartPoints: [ChartPoint]?
    private var cachedPredictionPoints: [ChartPoint]?
    
    func needsUpdate(currentReadingTimestamp: Date?, 
                     currentTreatmentTimestamp: Date?,
                     currentChartWidth: Int) -> Bool {
        // Check if any data has changed
    }
    
    func updateCache(chartPoints: [ChartPoint], 
                     predictionPoints: [ChartPoint],
                     readingTimestamp: Date?,
                     treatmentTimestamp: Date?) {
        // Store cached data
    }
}
```

### 2. Modify Update Logic
Change `updateLabelsAndChart()` to only update the chart when necessary:

```swift
@objc private func updateLabelsAndChart(...) {
    // Always update labels (time ago, value, etc.)
    updateLabels()
    
    // Only update chart if data changed
    if chartCache.needsUpdate(...) {
        updateChartWithResetEndDate(updatePredictions: updatePredictions)
        chartCache.updateCache(...)
    }
}
```

### 3. Track Data Changes
Monitor actual data changes that require chart updates:

#### New Glucose Reading
- Already handled in `processNewReading()`
- Add cache invalidation

#### Treatment Changes
- Monitor `nightscoutTreatmentsUpdateCounter`
- Add cache invalidation

#### User Settings Changes
- Chart width changes (3h, 6h, 12h, 24h)
- Threshold changes
- Display setting changes

#### User Interactions
- Double tap (force refresh)
- Pull to refresh
- Time window button taps

### 4. Preserve User Scroll Position
When chart IS updated due to new data:
- Save current scroll position if user has panned
- Restore position after update
- Only reset to current time if user hasn't interacted

## Implementation Steps

### Phase 1: Add Caching Infrastructure
1. Create `GlucoseChartCache` class
2. Add cache instance to `GlucoseChartManager`
3. Add timestamp tracking for last reading and treatment

### Phase 2: Modify Timer Updates
1. Change timer interval from 15 seconds to 60 seconds in `ConstantsHomeView.updateHomeViewIntervalInSeconds`
2. Split `updateLabelsAndChart()` into:
   - `updateLabels()` - runs every minute via timer
   - `updateChartIfNeeded()` - only when data changes
3. Ensure immediate updates when new glucose data arrives (keeps responsive feel)

### Phase 3: Add Change Detection
1. Track last glucose reading timestamp
2. Track treatment modification timestamp
3. Compare before updating chart

### Phase 4: Optimize Prediction Updates
1. Cache prediction calculations
2. Only recalculate when:
   - New glucose data arrives
   - IOB/COB changes (new treatment)
   - Time window changes

### Phase 5: Testing
1. Verify chart updates on new glucose data
2. Verify chart updates on treatment changes
3. Verify no updates during idle periods
4. Test scroll position preservation

## Benefits
- Reduced CPU usage by ~90% during idle periods
- Reduced timer wake-ups by 75% (from every 15s to every 60s)
- Eliminated unwanted chart jumping
- Better user experience when viewing historical data
- Significantly improved battery life
- Smoother scrolling performance
- More responsive to actual data changes

## Files to Modify
1. `RootViewController.swift` - Update timer logic
2. `GlucoseChartManager.swift` - Add caching
3. `UserDefaults.swift` - Add treatment timestamp tracking
4. Create new `GlucoseChartCache.swift`

## Backward Compatibility
- Cache is transparent to existing code
- Falls back to updating if cache state uncertain
- No changes to chart rendering logic