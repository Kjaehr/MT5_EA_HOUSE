# GOLD_ORB.mq5 Implementation Plan

## Overview
This document outlines a comprehensive plan to improve the GOLD_ORB.mq5 EA with better risk calculation, session management, VWAP filtering, bias filtering, and trade transaction handling.

## Implementation Phases

### Phase 1: Risk Calculation and Lot Size Improvements
**Priority: HIGH** - Critical for proper risk management

#### Changes Required:
1. Fix `CalculateLotSize()` to accept SL distance in price (not points)
2. Remove hardcoded fallback values for XAU
3. Implement proper error handling when broker returns 0
4. Clean up calling chain to pass price distances instead of points
5. Proper lot rounding with SYMBOL_VOLUME_STEP

#### Files to Modify:
- `CalculateLotSize()` function
- `Arm()` function where lot size is calculated
- All callers that pass `Pts()` converted values

---

### Phase 2: Session and Time Logic Improvements
**Priority: HIGH** - Essential for correct session detection

#### Changes Required:
1. Update `GetCurrentSession()` to use both hours AND minutes
2. Implement GMT offset handling in all time calculations
3. Handle overlapping/overnight sessions correctly
4. Update session end detection to include minutes
5. Apply GMT offset to daily reset logic

#### Files to Modify:
- `GetCurrentSession()` function
- `IsEligible()` session timing logic
- `Arm()` session start calculations
- `IsDayBoundaryReached()` and `DoDailyReset()`

---

### Phase 3: Range Window and Error Handling
**Priority: MEDIUM** - Improves robustness

#### Changes Required:
1. Handle `iBarShift()` returning -1
2. Add clear logging when count < 3 or ATR/efficiency out of bounds
3. Improve error messages for debugging

#### Files to Modify:
- `Arm()` function range calculation logic

---

### Phase 4: Spread and Distance Validation
**Priority: MEDIUM** - Prevents order rejection

#### Changes Required:
1. Run `CheckSpreadFilter()` again in `PlacePendingOrders()`
2. Improve `NormalizeAndValidatePending()` to preserve SL/TP distances
3. Reject orders if minimum distances cannot be maintained

#### Files to Modify:
- `PlacePendingOrders()` function
- `NormalizeAndValidatePending()` function

---

### Phase 5: Stop-Limit Entry Improvements
**Priority: MEDIUM** - Fixes Stop-Limit order placement

#### Changes Required:
1. Ensure Stop and Limit prices respect stops/freeze levels
2. Normalize stoplimit prices with tick size logic
3. Clean up unused global variables

#### Files to Modify:
- `PlacePendingOrders()` Stop-Limit section
- Global variable declarations (cleanup)

---

### Phase 6: VWAP Filter Enhancements
**Priority: LOW** - Feature enhancement

#### Changes Required:
1. Add `Inp_VWAP_MinBars` input parameter
2. Allow arming after minimum bars instead of hard rejection
3. Implement ring buffer for `g_vwap_values` (optional)
4. Add `Inp_VWAP_RequireSlope` boolean input

#### Files to Modify:
- Input parameters section
- `CheckVWAPFilter()` function
- `UpdateVWAP()` function

---

### Phase 7: Bias Filter Improvements
**Priority: LOW** - Feature enhancement

#### Changes Required:
1. Fix EMA slope calculation with clear indexing
2. Add bounds checking for SlopeBars
3. Improve logging when bias filter rejects

#### Files to Modify:
- `IsEligible()` bias filter section

---

### Phase 8: OnTradeTransaction Improvements
**Priority: HIGH** - Critical for accurate statistics

#### Changes Required:
1. Use `DEAL_REASON` for close classification instead of `ORDER_TYPE`
2. Count trades only when position fully closed
3. Set session traded flags on ENTRY, not EXIT
4. Fix partial close handling

#### Files to Modify:
- `OnTradeTransaction()` function
- Trade counting and statistics logic

---

### Phase 9: Partial Close, BE and Trailing Improvements
**Priority: MEDIUM** - Position management

#### Changes Required:
1. Check stops/freeze levels before `PositionModify()`
2. Handle trailing stop errors gracefully
3. Improve break-even logic

#### Files to Modify:
- `OnTickActive()` function
- Position modification logic

---

### Phase 10: CSV Logging Improvements
**Priority: LOW** - Better reporting

#### Changes Required:
1. Fix action/type mapping
2. Add `deal_reason` and `is_full_close` columns
3. Store pending prices for CANCEL/EXPIRE events
4. Ensure consistent position_id usage

#### Files to Modify:
- `WriteTradeToCSV()` function
- CSV header and data writing logic

---

### Phase 11: Session Management Cleanup
**Priority: LOW** - Code quality

#### Changes Required:
1. Use minute fields in session detection
2. Add SES_OFF handling for VWAP reset
3. Respect session end times with minutes

#### Files to Modify:
- `GetCurrentSession()` function
- `IsSessionActive()` function

---

### Phase 12: Final Cleanup
**Priority: LOW** - Code quality

#### Changes Required:
1. Fix `buffer_pts` units in CSV (points vs price)
2. Remove or implement `HandleStopLimitEntry()` stub
3. Review all `Print()` statements for clarity
4. Code documentation and comments

#### Files to Modify:
- Various functions for cleanup
- Documentation and comments

## Testing Strategy
After each phase:
1. Compile and fix any syntax errors
2. Test in Strategy Tester with historical data
3. Verify logging output and CSV files
4. Check risk calculations with different scenarios
5. Validate session detection across different time zones

## Risk Assessment
- **High Risk**: Phases 1, 2, 8 (core functionality)
- **Medium Risk**: Phases 3, 4, 5, 9 (robustness)
- **Low Risk**: Phases 6, 7, 10, 11, 12 (enhancements)

## Dependencies
- Phase 1 must be completed before Phase 4
- Phase 2 must be completed before Phase 11
- Phase 8 should be completed early for accurate testing

---

# READY-TO-USE PROMPTS FOR IMPLEMENTATION

## PHASE 1 PROMPT: Risk Calculation and Lot Size Improvements

```
Fix the risk calculation and lot size system in GOLD_ORB.mq5:

1. **Update CalculateLotSize() function signature and implementation:**
   - Change parameter from `double sl_points` to `double sl_price_distance`
   - Calculate risk per lot as: `ticks = sl_price_distance / SYMBOL_TRADE_TICK_SIZE` then `risk_per_lot = ticks * SYMBOL_TRADE_TICK_VALUE`
   - Remove all hardcoded fallback values (tick_value=1.0, tick_size=0.01, contract_size=100.0)
   - If any symbol property returns 0 or invalid, log clear error and return 0 (fail gracefully)
   - Ensure proper lot rounding: `lots = MathRound(lots / lot_step) * lot_step`

2. **Update all callers of CalculateLotSize():**
   - In Arm() function, change from `CalculateLotSize(Inp_RiskPct, Pts(sl_pts))` to `CalculateLotSize(Inp_RiskPct, sl_pts)`
   - Pass the actual price distance, not points conversion

3. **Add validation:**
   - Return 0 if any required symbol properties are invalid
   - Log specific error messages for debugging

Focus only on risk calculation - don't modify other parts of the code.
```

## PHASE 2 PROMPT: Session and Time Logic Improvements

```
Improve session and time logic in GOLD_ORB.mq5 to handle minutes and GMT offset:

1. **Update GetCurrentSession() function:**
   - Use both hours AND minutes for session detection
   - Apply Inp_BrokerGMT_Offset to convert server time to GMT, then to target timezone
   - Handle session end times with minutes (not just hours)
   - Example: London 08:00-16:00, NY 14:30-21:00

2. **Update session timing in IsEligible():**
   - Use minutes in session subwindow calculations
   - Apply GMT offset when calculating minutes_from_open

3. **Update Arm() function session start calculations:**
   - Include minutes when setting session_start datetime
   - Apply GMT offset consistently

4. **Update daily reset logic:**
   - Apply GMT offset in IsDayBoundaryReached()
   - Ensure DoDailyReset() uses correct timezone

5. **Handle overlapping sessions:**
   - Add logic for when London and NY sessions overlap
   - Ensure proper session transition handling

Focus only on time and session logic - don't modify risk calculation or other systems.
```

## PHASE 3 PROMPT: Range Window and Error Handling

```
Improve range window calculation and error handling in GOLD_ORB.mq5:

1. **Update Arm() function range calculation:**
   - Handle iBarShift() returning -1 (add explicit checks)
   - If first_bar or end_bar is -1, log clear error and return false
   - Add validation that we have sufficient M1 bars before proceeding

2. **Improve logging for range validation:**
   - When count < 3: log "Insufficient bars for range calculation: count=%d, need minimum 3"
   - When range_atr_ratio out of bounds: log current ratio and limits
   - When efficiency < minimum: log current efficiency and minimum required

3. **Add safety checks:**
   - Validate that session_start is reasonable (not too far in past/future)
   - Check that range_high > range_low before proceeding
   - Ensure ATR value is valid before using in calculations

Focus only on range calculation and error handling - don't modify other systems.
```

## PHASE 4 PROMPT: Spread and Distance Validation

```
Improve spread filtering and distance validation in GOLD_ORB.mq5:

1. **Update PlacePendingOrders() function:**
   - Add CheckSpreadFilter() call at the beginning, before any order placement
   - If spread check fails, return false immediately

2. **Improve NormalizeAndValidatePending() function:**
   - When adjusting entry price due to minimum distance requirements, preserve the original SL/TP distance
   - Instead of compressing SL/TP, recalculate them based on new entry price
   - If the required SL/TP distances cannot be maintained with minimum distance rules, return false (reject the order)

3. **Add validation logic:**
   - Before placing any order, verify that entry, SL, and TP all respect minimum distance requirements
   - Log specific reasons when orders are rejected due to distance violations

4. **Example logic for buy orders:**
   - If entry must be moved up due to minimum distance, calculate: new_sl = new_entry - original_sl_distance
   - Verify new_sl still respects minimum distance from new_entry
   - If not possible, reject the order setup

Focus only on spread filtering and distance validation - don't modify other systems.
```

## PHASE 5 PROMPT: Stop-Limit Entry Improvements

```
Fix Stop-Limit order placement in GOLD_ORB.mq5:

1. **Update Stop-Limit order placement in PlacePendingOrders():**
   - Ensure both Stop price (validated_buy_entry/validated_sell_entry) and Limit price respect stops/freeze levels
   - Normalize limit_price using same tick_size logic as other prices
   - Add validation that Stop and Limit prices have proper relationship (Buy: Stop > Limit, Sell: Stop < Limit)

2. **Fix the OrderSend requests:**
   - Verify that request.price (stop price) and request.stoplimit (limit price) are properly normalized
   - Add error handling for OrderSend failures with specific error codes
   - Log the actual Stop and Limit prices being used

3. **Clean up unused global variables:**
   - Remove or properly implement: g_stop_limit_triggered, g_stop_limit_entry_price, g_stop_limit_direction
   - If keeping them, ensure they're used consistently throughout the code

4. **Add validation:**
   - Check that offset_pts creates valid limit prices
   - Ensure limit prices don't violate minimum distance requirements

Focus only on Stop-Limit order improvements - don't modify other systems.
```

## PHASE 6 PROMPT: VWAP Filter Enhancements

```
Enhance VWAP filtering system in GOLD_ORB.mq5:

1. **Add new input parameters:**
   - Add: input int Inp_VWAP_MinBars = 10; // Minimum bars before VWAP filter active
   - Add: input bool Inp_VWAP_RequireSlope = true; // Require VWAP slope for filtering

2. **Update CheckVWAPFilter() function:**
   - Allow arming when VWAP data exists but SD not yet calculated (if bars >= Inp_VWAP_MinBars)
   - Make slope requirement optional based on Inp_VWAP_RequireSlope
   - Add clear logging for why VWAP filter passes/fails

3. **Improve UpdateVWAP() function:**
   - Add check for minimum bars before calculating slope
   - Consider implementing ring buffer for g_vwap_values (optional - can keep current array shifting)
   - Ensure VWAP_SD calculation is robust

4. **Add VWAP status logging:**
   - Log VWAP values, SD, and slope when filter is evaluated
   - Show current price relative to VWAP bands

Focus only on VWAP filter improvements - don't modify other systems.
```

## PHASE 7 PROMPT: Bias Filter Improvements

```
Fix bias filter calculation and logging in GOLD_ORB.mq5:

1. **Fix EMA slope calculation in IsEligible():**
   - Use clear indexing: EMA[1] - EMA[1+SlopeBars] (most recent closed bar vs older bar)
   - Add bounds checking: ensure SlopeBars doesn't exceed available EMA data
   - Handle case where insufficient EMA data is available

2. **Improve bias filter logic:**
   - Ensure slope calculation uses correct array indices
   - Add validation that EMA buffer has enough data points
   - Fix the slope direction logic (positive slope = uptrend, negative = downtrend)

3. **Enhanced logging:**
   - When bias filter rejects, log: current bid, SMA value, EMA slope, required direction
   - Show why specific direction was rejected (e.g., "Bid below SMA but EMA slope negative")
   - Log when bias filter passes and which direction is allowed

4. **Add safety checks:**
   - Verify EMA buffer copy was successful before calculating slope
   - Handle edge cases where SMA or EMA values are invalid

Focus only on bias filter improvements - don't modify other systems.
```

## PHASE 8 PROMPT: OnTradeTransaction Improvements

```
Fix trade transaction handling and statistics in GOLD_ORB.mq5:

1. **Update close reason classification:**
   - Use DEAL_REASON instead of ORDER_TYPE for determining close reason
   - Map DEAL_REASON values: DEAL_REASON_SL → "STOP_LOSS", DEAL_REASON_TP → "TAKE_PROFIT", etc.
   - Remove the HistoryOrderSelect() logic that tries to determine reason from order type

2. **Fix trade counting:**
   - Only increment g_total_trades++ and g_limits.trades_today++ when position is FULLY closed
   - For partial closes, don't count as complete trade
   - Add logic to detect if this is final close (remaining volume = 0)

3. **Fix session traded flags:**
   - Set g_london_traded/g_ny_traded = true on ENTRY (DEAL_ENTRY_IN), not on exit
   - This prevents multiple trades in same session even if first trade closes quickly

4. **Improve partial close handling:**
   - Track partial closes separately from full closes
   - Update remaining_lots in TradeMeta for partial closes
   - Only update final statistics when position fully closed

5. **Add new CSV columns:**
   - Add deal_reason column (from DEAL_REASON)
   - Add is_full_close boolean column

Focus only on trade transaction handling - don't modify other systems.
```

## PHASE 9 PROMPT: Partial Close, BE and Trailing Improvements

```
Improve position management in GOLD_ORB.mq5:

1. **Update partial close logic in OnTickActive():**
   - Before calling PositionModify() for break-even or TP2, check stops/freeze levels
   - If new SL cannot be set due to minimum distance, log warning and skip modification
   - Ensure partial close volume respects SYMBOL_VOLUME_STEP

2. **Improve break-even logic:**
   - Calculate break-even price: entry_price + (Inp_ORB_BE_OffsetPts * _Point)
   - Validate that BE price respects minimum distance from current price
   - Only modify if validation passes

3. **Fix trailing stop logic:**
   - Before setting new trailing SL, validate against stops/freeze levels
   - If trailing SL cannot be set, log reason and continue (don't treat as error)
   - Ensure trailing SL moves in correct direction only

4. **Add position modification error handling:**
   - Catch PositionModify() failures and log specific error codes
   - Don't abort strategy on modification failures - continue with existing SL/TP

5. **Improve TP2 setting:**
   - When setting TP2 after partial close, ensure it respects minimum distance
   - Validate TP2 price before attempting to set it

Focus only on position management improvements - don't modify other systems.
```

## PHASE 10 PROMPT: CSV Logging Improvements

```
Improve CSV logging system in GOLD_ORB.mq5:

1. **Fix action/type mapping in WriteTradeToCSV():**
   - Create proper mapping for all action types: "ENTRY", "PARTIAL", "CLOSE", "CANCEL", "EXPIRE"
   - Don't fall back to "CLOSE" for unknown actions
   - Use specific labels for each type of trade event

2. **Add new CSV columns:**
   - Add "deal_reason" column (populated from DEAL_REASON in OnTradeTransaction)
   - Add "is_full_close" boolean column (true only when position fully closed)
   - Update CSV header accordingly

3. **Improve pending order logging:**
   - For CANCEL/EXPIRE events, store the pending order prices that were cancelled
   - Log both stop price and limit price for Stop-Limit orders
   - Ensure position_id consistency between ENTRY and subsequent events

4. **Fix data consistency:**
   - Ensure position_id in CSV refers to the same position throughout its lifecycle
   - When copying meta from order to position, maintain consistent ID usage
   - Store original pending prices for reference

5. **Update CSV header:**
   - Add the new columns to the FileWrite() header line
   - Ensure all data columns have corresponding headers

Focus only on CSV logging improvements - don't modify other systems.
```

## PHASE 11 PROMPT: Session Management Cleanup

```
Clean up session management functions in GOLD_ORB.mq5:

1. **Update GetCurrentSession() to use minutes:**
   - Check both hour and minute for session boundaries
   - Example: London ends at 16:00, NY starts at 14:30
   - Handle minute-level precision in session detection

2. **Improve IsSessionActive():**
   - Add support for minute-level session boundaries
   - Consider adding SES_OFF handling for outside trading windows

3. **Update VWAP reset logic:**
   - Allow VWAP updates during SES_OFF periods (for continuous calculation)
   - But don't apply VWAP filter outside active sessions

4. **Handle session transitions:**
   - Ensure smooth transition between sessions
   - Handle overlapping sessions (London/NY overlap period)
   - Reset session-specific variables at proper times

5. **Add session boundary logging:**
   - Log when sessions start/end with minute precision
   - Show current session status in verbose logging

Focus only on session management cleanup - don't modify other systems.
```

## PHASE 12 PROMPT: Final Cleanup and Documentation

```
Perform final cleanup and documentation improvements in GOLD_ORB.mq5:

1. **Fix CSV data units:**
   - Ensure buffer_pts column shows points (not price) or rename column to match actual units
   - Verify all CSV columns have correct data types and units

2. **Handle HandleStopLimitEntry() function:**
   - Either remove this stub function if unused
   - Or implement actual Stop-Limit entry logic if needed
   - Document the decision in comments

3. **Improve logging messages:**
   - Review all Print() statements under Inp_LogVerbose
   - Make messages clear and actionable
   - Add context information (current values, thresholds, etc.)

4. **Add code documentation:**
   - Add function header comments explaining purpose and parameters
   - Document complex logic sections
   - Add inline comments for non-obvious calculations

5. **Code cleanup:**
   - Remove any unused variables or functions
   - Ensure consistent naming conventions
   - Add proper error handling where missing

Focus only on cleanup and documentation - don't modify core functionality.
```

---

## USAGE INSTRUCTIONS

1. **Execute phases in order** - some phases depend on previous ones
2. **Test after each phase** - compile and run basic tests
3. **Use exact prompts** - copy/paste the prompt text for consistent results
4. **Focus on single phase** - don't mix changes from different phases
5. **Validate changes** - ensure each phase works before moving to next

## PRIORITY EXECUTION ORDER

**High Priority (Execute First):**
- Phase 1: Risk Calculation
- Phase 2: Session Logic
- Phase 8: Trade Transaction

**Medium Priority (Execute Second):**
- Phase 3: Error Handling
- Phase 4: Spread Validation
- Phase 5: Stop-Limit Orders
- Phase 9: Position Management

**Low Priority (Execute Last):**
- Phase 6: VWAP Enhancements
- Phase 7: Bias Filter
- Phase 10: CSV Logging
- Phase 11: Session Cleanup
- Phase 12: Final Cleanup
