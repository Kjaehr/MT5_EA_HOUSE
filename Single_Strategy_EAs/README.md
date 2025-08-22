# GOLD Single Strategy EAs

## Overview
This directory contains 5 standalone Expert Advisors extracted from the original GOLD_Multistrategy.mq5. Each EA implements a single strategy and can be backtested and optimized independently.

## Strategy EAs

### 1. GOLD_ORB.mq5 (Magic: 55221001)
**Strategy**: Opening Range Breakout
- **Tag**: XAU_ORB
- **Logic**: Places pending orders above/below session opening range
- **Key Parameters**:
  - `Inp_ORB_RangeMin`: Minimum range bars (10)
  - `Inp_ORB_SL_ATR`: Stop Loss ATR multiplier (1.00)
  - `Inp_ORB_TP1_ATR`: Take Profit ATR multiplier (0.50)
  - `Inp_ORB_ADX_Min/Max`: ADX filter (15-45)
  - `Inp_ORB_ExpireMin`: Order expiration (30 min)

### 2. GOLD_VWAP_Fade.mq5 (Magic: 55221002)
**Strategy**: VWAP Mean Reversion
- **Tag**: XAU_VWAP_Fade
- **Logic**: Fades price when it deviates significantly from session VWAP
- **Key Parameters**:
  - `Inp_VWAP_FadeZ`: Z-Score threshold (1.2)
  - `Inp_RSI_BuyMax/SellMin`: RSI filters (45/55)
  - `Inp_ADX_Max_Fade`: Maximum ADX for fade (26)
  - `Inp_Fade_SL_ATR`: Stop Loss ATR (0.8)

### 3. GOLD_VWAP_Trend.mq5 (Magic: 55221003)
**Strategy**: VWAP Trend Reentry
- **Tag**: XAU_VWAP_Trend
- **Logic**: Buys/sells on pullbacks to EMA in trending markets
- **Key Parameters**:
  - `Inp_TR_ADX_Min`: Minimum ADX for trend (24)
  - `Inp_EMA_Fast/Slow`: EMA periods (21/55)
  - `Inp_SMA_Trend`: Trend filter SMA (200)
  - `Inp_TR_TimeStopMin`: Time-based exit (45 min)

### 4. GOLD_Keltner.mq5 (Magic: 55221004)
**Strategy**: Keltner Channel Mean Reversion
- **Tag**: XAU_Keltner
- **Logic**: Trades reversions from Keltner channel extremes
- **Key Parameters**:
  - `Inp_Keltner_EMA`: Channel center EMA (20)
  - `Inp_Keltner_Mult`: Channel width multiplier (2.8)
  - `Inp_K_ADX_Max`: Maximum ADX for mean reversion (24)
  - `Inp_K_SL_FactorATR`: Stop Loss factor (0.5)

### 5. GOLD_Sweep.mq5 (Magic: 55221005)
**Strategy**: Liquidity Sweep
- **Tag**: XAU_Sweep
- **Logic**: Detects liquidity sweeps and trades the reversion
- **Key Parameters**:
  - `Inp_Sweep_Lookback`: Bars to find swing points (80)
  - `Inp_Sweep_MinWickPts`: Minimum wick size (20 pts)
  - `Inp_Sweep_SL_Buffer`: SL buffer (15 pts)

## Common Features

### Risk Management
All EAs include identical risk management:
- Daily Loss Cap (3.0%)
- Weekly Loss Cap (8.0%)
- Maximum Consecutive Losses (5)
- Maximum Trades Per Day (10)
- Automatic daily/weekly resets

### Session Management
- London Session: 08:00-16:00
- NY Session: 14:30-21:00
- Configurable session times

### CSV Logging
Each EA creates its own CSV file with:
- Trade details (entry/exit prices, lots, P&L)
- Strategy-specific indicators
- Session information
- Timestamps

### Technical Indicators
- ATR for volatility-based sizing
- ADX for trend/range filtering
- Strategy-specific indicators (RSI, EMAs, etc.)

## Usage Instructions

### 1. Compilation
- Copy files to MT5 `Experts` folder
- Compile each EA individually in MetaEditor
- No dependencies on other files

### 2. Backtesting
- Load individual EA on XAUUSD M5 chart
- Set appropriate date range
- Optimize strategy-specific parameters
- Compare results between strategies

### 3. Parameter Optimization
Each EA has focused parameter sets:
- **ORB**: Range size, ATR multipliers, ADX filters
- **VWAP Fade**: Z-score, RSI levels, ADX max
- **VWAP Trend**: EMA periods, ADX min, time stops
- **Keltner**: Channel parameters, ADX max
- **Sweep**: Lookback period, wick size, buffers

### 4. Live Trading
- Use unique magic numbers (55221001-55221005)
- Each EA can run independently
- Monitor individual CSV logs
- Risk management applies per EA

## File Structure
```
Single_Strategy_EAs/
├── GOLD_ORB.mq5          # Opening Range Breakout
├── GOLD_VWAP_Fade.mq5    # VWAP Mean Reversion
├── GOLD_VWAP_Trend.mq5   # VWAP Trend Reentry
├── GOLD_Keltner.mq5      # Keltner Channel MR
├── GOLD_Sweep.mq5        # Liquidity Sweep
└── README.md             # This file
```

## Next Steps
1. Backtest each strategy individually
2. Optimize parameters for each strategy
3. Compare performance metrics
4. Select best-performing strategies
5. Consider combining profitable strategies in new multi-strategy EA

## Notes
- All EAs are self-contained and independent
- No shared dependencies or global variables
- Each maintains its own state and statistics
- CSV files are strategy-specific with unique naming
- Risk management is isolated per EA
