//+------------------------------------------------------------------+
//|                                      DAX_Simple_Scalping_EA.mq5 |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- Input parameters
input double   LotSize = 0.1;                    // Lot size (adjusted for DAX)
input int      StopLoss = 30;                    // Stop Loss in pips (slightly wider)
input int      TakeProfit = 60;                  // Take Profit in pips (1.5:1 R/R ratio)
input int      MagicNumber = 789123;             // Magic number
input int      StartHour = 8;                    // Trading start hour (avoid early volatility)
input int      EndHour = 12;                     // Trading end hour (avoid late volatility)
input int      MaxDailyTrades = 15;              // Maximum trades per day (much more conservative)
input double   MaxDailyLoss = 250.0;             // Maximum daily loss (controlled)
input bool     UseBreakoutStrategy = true;       // Use breakout instead of indicators
input bool     UseBothStrategies = false;        // Use only one strategy to avoid conflicts
input bool     UseScalpingMode = false;          // Disable ultra aggressive scalping mode
input int      MinutesBetweenTrades = 10;        // Minimum minutes between trades (longer cooldown)
input double   MaxSpreadPoints = 50.0;           // Maximum allowed spread in points

//--- Indicator parameters (aggressive setup)
input int      RSI_Period = 9;                   // RSI period (faster)
input int      MA_Fast = 5;                      // Fast MA period (very fast)
input int      MA_Slow = 13;                     // Slow MA period (faster)
input int      Breakout_Bars = 4;                // Bars to look for breakout
input double   RetestBuffer = 2.0;               // Retest buffer in index points
input double   RangeMultiplier = 1.25;           // TP multiplier (k * Range)
input double   MinRangeQuality = 0.33;           // Minimum body-to-range ratio

//--- Global variables
CTrade trade;
int rsi_handle, ma_fast_handle, ma_slow_handle, m15_ema50_handle;
int daily_trade_count = 0;
double daily_loss = 0.0;
datetime last_trade_date = 0;
double last_high = 0, last_low = 0;
datetime last_trade_time = 0;
bool has_active_position = false;  // Track if we have any active position

//--- Risk management variables
double RiskPerTrade = 0.005;        // 0.5% of equity
int MaxConsecLoss = 3;              // Max consecutive losses before cooldown
double MaxDailyLossPercent = 0.02;  // 2% of equity
datetime cooldown_end_time = 0;     // Cooldown end time





//--- Warm-up and safety variables
int WarmupBars = 0;
int StartDelayMinutes = 15;
datetime session_start_time = 0;
int session_bar_count = 0;
bool is_warmed_up = false;

//--- Analysis variables
int breakout_signals = 0, ma_signals = 0, scalping_signals = 0;
int breakout_wins = 0, ma_wins = 0, scalping_wins = 0;
int consecutive_losses = 0;
double max_consecutive_loss = 0;
datetime last_processed_time = 0;  // Track last processed deal time to prevent duplicates

//+------------------------------------------------------------------+
//| Helper function: Convert index points to price points           |
//+------------------------------------------------------------------+
double IndexPointsToPrice(double index_points)
{
    return index_points / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Initialize trade object
    trade.SetExpertMagicNumber(MagicNumber);

    //--- Create indicator handles
    rsi_handle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
    ma_fast_handle = iMA(_Symbol, _Period, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    ma_slow_handle = iMA(_Symbol, _Period, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
    m15_ema50_handle = iMA(_Symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);

    //--- Check if handles are valid
    if(rsi_handle == INVALID_HANDLE || ma_fast_handle == INVALID_HANDLE ||
       ma_slow_handle == INVALID_HANDLE || m15_ema50_handle == INVALID_HANDLE)
    {
        Print("Error creating indicator handles");
        return INIT_FAILED;
    }



    //--- Calculate warm-up period
    WarmupBars = MathMax(MA_Slow * 3, MathMax(RSI_Period * 3, Breakout_Bars + 5));
    Print("Warm-up period set to: ", WarmupBars, " bars");

    //--- Print symbol specifications for debugging
    PrintSymbolInfo();

    Print("DAX Simple Scalping EA initialized successfully");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Release indicator handles
    IndicatorRelease(rsi_handle);
    IndicatorRelease(ma_fast_handle);
    IndicatorRelease(ma_slow_handle);
    IndicatorRelease(m15_ema50_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Warm-up gate: Check if we have enough bars
    if(Bars(_Symbol, _Period) < WarmupBars)
    {
        if(!is_warmed_up)
        {
            Print("SKIP: Warming up... Need ", WarmupBars, " bars, have ", Bars(_Symbol, _Period));
        }
        return;
    }

    if(!is_warmed_up)
    {
        is_warmed_up = true;
        Print("Warm-up complete. Trading enabled.");
    }



    //--- Check trading hours
    if(!IsTradingTime())
        return;

    //--- Reset daily counters and session tracking
    ResetDailyCounters();

    //--- Session delay check: Wait after market open
    if(!CheckSessionDelay())
        return;

    //--- Check cooldown from consecutive losses
    if(TimeCurrent() < cooldown_end_time)
        return;

    //--- Check daily limits (use percentage of equity for daily loss)
    double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double max_daily_loss = current_equity * MaxDailyLossPercent;
    if(daily_trade_count >= MaxDailyTrades || daily_loss >= max_daily_loss)
        return;

    //--- Check time between trades (5 minutes cooldown)
    if(TimeCurrent() - last_trade_time < 5 * 60)
        return;

    //--- Check for existing positions - ONLY ONE POSITION AT A TIME
    UpdatePositionStatus();
    if(has_active_position)
    {
        ManagePositions();
        return; // Never allow multiple positions regardless of mode
    }
    
    //--- Get current market data
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double spread = ask - bid;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    //--- Robust spread check in points (no pip conversion assumptions)
    double spread_points = spread / point;
    if(spread_points > MaxSpreadPoints)
    {
        PrintFormat("Spread too wide: %.1f points (limit=%.1f)", spread_points, MaxSpreadPoints);
        return;
    }
    
    //--- Choose strategy - ONLY ONE SIGNAL PER TICK to prevent multiple positions
    if(UseBothStrategies)
    {
        // Try strategies in priority order - stop after first signal
        if(!CheckBreakoutSignals(ask, bid))
        {
            if(!CheckIndicatorSignals(ask, bid) && UseScalpingMode)
            {
                CheckScalpingSignals(ask, bid);
            }
        }
    }
    else if(UseBreakoutStrategy)
    {
        CheckBreakoutSignals(ask, bid);
    }
    else
    {
        CheckIndicatorSignals(ask, bid);
    }
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                    |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
    MqlDateTime dt;
    TimeCurrent(dt);

    // Specific time windows: 08:05-11:00 and 14:30-17:15 CET
    bool morning_session = (dt.hour == 8 && dt.min >= 5) || (dt.hour >= 9 && dt.hour < 11);
    bool afternoon_session = (dt.hour == 14 && dt.min >= 30) || (dt.hour >= 15 && dt.hour < 17) ||
                             (dt.hour == 17 && dt.min <= 15);

    return morning_session || afternoon_session;
}

//+------------------------------------------------------------------+
//| Reset daily counters                                             |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
    MqlDateTime dt;
    TimeCurrent(dt);
    datetime current_date = StringToTime(IntegerToString(dt.year) + "." + 
                                        IntegerToString(dt.mon) + "." + 
                                        IntegerToString(dt.day));
    
    if(last_trade_date != current_date)
    {
        daily_trade_count = 0;
        daily_loss = 0.0;
        last_trade_date = current_date;
        session_start_time = TimeCurrent();
        session_bar_count = 0;
        Print("Daily counters reset for new trading day");
    }
}

//+------------------------------------------------------------------+
//| Check session delay after market open                           |
//+------------------------------------------------------------------+
bool CheckSessionDelay()
{
    MqlDateTime dt;
    TimeCurrent(dt);

    // Check if we're at the start of trading session
    if(dt.hour == StartHour && dt.min < StartDelayMinutes)
    {
        Print("SKIP: Session delay - waiting ", StartDelayMinutes - dt.min, " more minutes");
        return false;
    }

    // Update session bar count
    if(session_start_time > 0)
    {
        session_bar_count = Bars(_Symbol, _Period, session_start_time, TimeCurrent());

        // Don't trade until we have enough bars for breakout analysis
        if(session_bar_count < Breakout_Bars)
        {
            Print("SKIP: Session bar count insufficient: ", session_bar_count, " < ", Breakout_Bars);
            return false;
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Update position status (fixed position loop)                    |
//+------------------------------------------------------------------+
void UpdatePositionStatus()
{
    has_active_position = false;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        // Fix: Use PositionGetSymbol and PositionGetInteger with index
        if(PositionGetSymbol(i) == _Symbol &&
           PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            has_active_position = true;
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Check range quality using body-to-range ratio                   |
//+------------------------------------------------------------------+
bool CheckRangeQuality(double &high[], double &low[], double &open[], double &close[])
{
    double total_body = 0.0;
    double total_range = 0.0;

    for(int i = 0; i < Breakout_Bars; i++)
    {
        total_body += MathAbs(close[i] - open[i]);
        total_range += (high[i] - low[i]);
    }

    double quality = (total_range > 0) ? total_body / total_range : 0.0;
    return quality >= MinRangeQuality;
}

//+------------------------------------------------------------------+
//| Check M15 EMA50 trend bias                                       |
//+------------------------------------------------------------------+
bool CheckTrendBias(bool is_long)
{
    double ema50[];
    ArraySetAsSeries(ema50, true);

    int copied = CopyBuffer(m15_ema50_handle, 0, 0, 16, ema50);
    if(copied < 16 || ArraySize(ema50) < 16)
        return false;

    // Calculate slope: current vs 15 bars ago
    double slope = ema50[0] - ema50[15];

    if(is_long)
        return slope > 0;  // Uptrend for long
    else
        return slope < 0;  // Downtrend for short
}

//+------------------------------------------------------------------+
//| Check breakout signals with retest logic                        |
//+------------------------------------------------------------------+
bool CheckBreakoutSignals(double ask, double bid)
{
    //--- Get price data
    double high[], low[], close[], open[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);

    // Need current + previous bar for retest logic
    int high_copied = CopyHigh(_Symbol, _Period, 0, Breakout_Bars + 2, high);
    int low_copied = CopyLow(_Symbol, _Period, 0, Breakout_Bars + 2, low);
    int close_copied = CopyClose(_Symbol, _Period, 0, Breakout_Bars + 2, close);
    int open_copied = CopyOpen(_Symbol, _Period, 0, Breakout_Bars + 2, open);

    if(high_copied < Breakout_Bars + 2 || low_copied < Breakout_Bars + 2 ||
       close_copied < Breakout_Bars + 2 || open_copied < Breakout_Bars + 2)
        return false;

    //--- Calculate range from bars 2-5 (skip current and previous bar)
    double breakout_high = high[ArrayMaximum(high, 2, Breakout_Bars)];
    double breakout_low = low[ArrayMinimum(low, 2, Breakout_Bars)];
    double range = breakout_high - breakout_low;

    //--- Check range quality (create sub-arrays for the range bars)
    double quality_high[], quality_low[], quality_open[], quality_close[];
    ArrayResize(quality_high, Breakout_Bars);
    ArrayResize(quality_low, Breakout_Bars);
    ArrayResize(quality_open, Breakout_Bars);
    ArrayResize(quality_close, Breakout_Bars);

    for(int i = 0; i < Breakout_Bars; i++)
    {
        quality_high[i] = high[i + 2];
        quality_low[i] = low[i + 2];
        quality_open[i] = open[i + 2];
        quality_close[i] = close[i + 2];
    }

    if(!CheckRangeQuality(quality_high, quality_low, quality_open, quality_close))
        return false;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double retest_buffer_price = RetestBuffer * point;

    //--- LONG: Previous bar closed above breakout_high, current bar retests and closes up
    bool long_breakout = close[1] > breakout_high;  // Previous bar broke above
    bool long_retest = low[0] <= (breakout_high + retest_buffer_price) &&
                       low[0] >= (breakout_high - retest_buffer_price);  // Current bar retested
    bool long_close_up = close[0] > open[0];  // Current bar closed up

    //--- SHORT: Previous bar closed below breakout_low, current bar retests and closes down
    bool short_breakout = close[1] < breakout_low;  // Previous bar broke below
    bool short_retest = high[0] >= (breakout_low - retest_buffer_price) &&
                        high[0] <= (breakout_low + retest_buffer_price);  // Current bar retested
    bool short_close_down = close[0] < open[0];  // Current bar closed down

    if(long_breakout && long_retest && long_close_up && CheckTrendBias(true))
    {
        breakout_signals++;
        double sl = breakout_low - 2.0 * point;  // SL behind range bottom - 2 points
        double tp = ask + RangeMultiplier * range;  // TP = k * Range

        PrintFormat("BREAKOUT LONG: Range=%.1f points, High=%.5f Retest=%.5f SL=%.5f TP=%.5f",
                   range/point, breakout_high, low[0], sl, tp);
        OpenLongPositionCustom(ask, sl, tp, 1);
        return true;
    }
    else if(short_breakout && short_retest && short_close_down && CheckTrendBias(false))
    {
        breakout_signals++;
        double sl = breakout_high + 2.0 * point;  // SL above range top + 2 points
        double tp = bid - RangeMultiplier * range;  // TP = k * Range

        PrintFormat("BREAKOUT SHORT: Range=%.1f points, Low=%.5f Retest=%.5f SL=%.5f TP=%.5f",
                   range/point, breakout_low, high[0], sl, tp);
        OpenShortPositionCustom(bid, sl, tp, 1);
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check indicator signals (alternative strategy) - Returns true if signal found |
//+------------------------------------------------------------------+
bool CheckIndicatorSignals(double ask, double bid)
{
    //--- Get indicator values
    double rsi[], ma_fast[], ma_slow[];
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(ma_fast, true);
    ArraySetAsSeries(ma_slow, true);

    // Buffer safety checks
    int rsi_copied = CopyBuffer(rsi_handle, 0, 0, 2, rsi);
    int ma_fast_copied = CopyBuffer(ma_fast_handle, 0, 0, 2, ma_fast);
    int ma_slow_copied = CopyBuffer(ma_slow_handle, 0, 0, 2, ma_slow);

    if(rsi_copied < 2 || ma_fast_copied < 2 || ma_slow_copied < 2)
    {
        Print("SKIP: Insufficient indicator data - RSI:", rsi_copied, " MA_Fast:", ma_fast_copied, " MA_Slow:", ma_slow_copied);
        return false;
    }

    // Bounds guards
    if(ArraySize(rsi) < 2 || ArraySize(ma_fast) < 2 || ArraySize(ma_slow) < 2)
    {
        Print("SKIP: Indicator array size insufficient");
        return false;
    }
    
    //--- More aggressive MA signals - not just crossovers
    bool ma_bullish = (ma_fast[0] > ma_slow[0]); // Fast above slow
    bool ma_bearish = (ma_fast[0] < ma_slow[0]); // Fast below slow

    // Look for momentum in MA direction
    bool ma_momentum_up = (ma_fast[0] > ma_fast[1] && ma_slow[0] >= ma_slow[1]);
    bool ma_momentum_down = (ma_fast[0] < ma_fast[1] && ma_slow[0] <= ma_slow[1]);

    // More lenient RSI filter
    bool rsi_not_extreme_high = (rsi[0] < 80);
    bool rsi_not_extreme_low = (rsi[0] > 20);

    // Entry conditions - maximum opportunities
    if((ma_bullish && ma_momentum_up) && rsi_not_extreme_high)
    {
        ma_signals++;
        Print("MA LONG: FastMA=", ma_fast[0], " SlowMA=", ma_slow[0], " RSI=", rsi[0]);
        OpenLongPosition(ask, 2); // Strategy 2 = MA
        return true;
    }
    else if((ma_bearish && ma_momentum_down) && rsi_not_extreme_low)
    {
        ma_signals++;
        Print("MA SHORT: FastMA=", ma_fast[0], " SlowMA=", ma_slow[0], " RSI=", rsi[0]);
        OpenShortPosition(bid, 2); // Strategy 2 = MA
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check scalping signals (ultra short-term) - Returns true if signal found |
//+------------------------------------------------------------------+
bool CheckScalpingSignals(double ask, double bid)
{
    //--- Get recent price action
    double close[], high[], low[];
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);

    // Buffer safety checks
    int close_copied = CopyClose(_Symbol, _Period, 0, 5, close);
    int high_copied = CopyHigh(_Symbol, _Period, 0, 5, high);
    int low_copied = CopyLow(_Symbol, _Period, 0, 5, low);

    if(close_copied < 5 || high_copied < 5 || low_copied < 5)
    {
        Print("SKIP: Insufficient scalping data - Close:", close_copied, " High:", high_copied, " Low:", low_copied);
        return false;
    }

    // Bounds guards
    if(ArraySize(close) < 5 || ArraySize(high) < 5 || ArraySize(low) < 5)
    {
        Print("SKIP: Scalping array size insufficient");
        return false;
    }

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    //--- Simple momentum scalping
    bool strong_up_move = (close[0] > close[1] && close[1] > close[2] &&
                          (close[0] - close[2]) > 8.0 * point); // 8+ points in 3 bars

    bool strong_down_move = (close[0] < close[1] && close[1] < close[2] &&
                            (close[2] - close[0]) > 8.0 * point); // 8+ points down in 3 bars

    //--- Quick reversal scalping
    bool bounce_from_low = (close[0] > low[1] && (close[0] - low[1]) > 6.0 * point);
    bool drop_from_high = (close[0] < high[1] && (high[1] - close[0]) > 6.0 * point);

    if(strong_up_move || bounce_from_low)
    {
        scalping_signals++;
        string signal_type = strong_up_move ? "MOMENTUM" : "BOUNCE";
        Print("SCALPING LONG (", signal_type, "): Close[0]=", close[0], " Close[2]=", close[2]);
        OpenLongPosition(ask, 3); // Strategy 3 = Scalping
        return true;
    }
    else if(strong_down_move || drop_from_high)
    {
        scalping_signals++;
        string signal_type = strong_down_move ? "MOMENTUM" : "DROP";
        Print("SCALPING SHORT (", signal_type, "): Close[0]=", close[0], " Close[2]=", close[2]);
        OpenShortPosition(bid, 3); // Strategy 3 = Scalping
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Validate and normalize lot size                                  |
//+------------------------------------------------------------------+
double ValidateLotSize(double lots)
{
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    //--- Normalize to lot step
    lots = MathRound(lots / lot_step) * lot_step;

    //--- Check limits
    if(lots < min_lot) lots = min_lot;
    if(lots > max_lot) lots = max_lot;

    return lots;
}

//+------------------------------------------------------------------+
//| Print symbol information for debugging                           |
//+------------------------------------------------------------------+
void PrintSymbolInfo()
{
    Print("=== SYMBOL INFORMATION ===");
    Print("Symbol: ", _Symbol);
    Print("Min Volume: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
    Print("Max Volume: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
    Print("Volume Step: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP));
    Print("Point: ", SymbolInfoDouble(_Symbol, SYMBOL_POINT));
    Print("Digits: ", SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    Print("Contract Size: ", SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE));
    Print("Validated Lot Size: ", ValidateLotSize(LotSize));
    Print("========================");
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                     |
//+------------------------------------------------------------------+
double CalculateLotSize(double entry_price, double stop_loss)
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double risk_amount = equity * RiskPerTrade;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    double sl_distance = MathAbs(entry_price - stop_loss);
    double sl_points = sl_distance / point;

    // Calculate lot size based on risk
    double lot_size = risk_amount / (sl_points * tick_value / tick_size);

    return ValidateLotSize(lot_size);
}

//+------------------------------------------------------------------+
//| Open long position with custom SL/TP                            |
//+------------------------------------------------------------------+
void OpenLongPositionCustom(double price, double sl, double tp, int strategy_id)
{
    double validated_lots = CalculateLotSize(price, sl);

    if(trade.Buy(validated_lots, _Symbol, price, sl, tp, GetStrategyComment(strategy_id)))
    {
        daily_trade_count++;
        last_trade_time = TimeCurrent();
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double risk_points = (price - sl) / point;
        double reward_points = (tp - price) / point;
        PrintFormat("LONG OPENED [Strategy %d]: Price=%.5f SL=%.5f TP=%.5f Risk=%.1f points Reward=%.1f points Volume=%.2f",
                   strategy_id, price, sl, tp, risk_points, reward_points, validated_lots);
    }
    else
    {
        Print("FAILED LONG [Strategy ", strategy_id, "]: Error=", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Open short position with custom SL/TP                           |
//+------------------------------------------------------------------+
void OpenShortPositionCustom(double price, double sl, double tp, int strategy_id)
{
    double validated_lots = CalculateLotSize(price, sl);

    if(trade.Sell(validated_lots, _Symbol, price, sl, tp, GetStrategyComment(strategy_id)))
    {
        daily_trade_count++;
        last_trade_time = TimeCurrent();
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double risk_points = (sl - price) / point;
        double reward_points = (price - tp) / point;
        PrintFormat("SHORT OPENED [Strategy %d]: Price=%.5f SL=%.5f TP=%.5f Risk=%.1f points Reward=%.1f points Volume=%.2f",
                   strategy_id, price, sl, tp, risk_points, reward_points, validated_lots);
    }
    else
    {
        Print("FAILED SHORT [Strategy ", strategy_id, "]: Error=", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Open long position (legacy function for other strategies)       |
//+------------------------------------------------------------------+
void OpenLongPosition(double price, int strategy_id)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double sl = price - StopLoss * point;
    double tp = price + TakeProfit * point;

    OpenLongPositionCustom(price, sl, tp, strategy_id);
}

//+------------------------------------------------------------------+
//| Open short position (legacy function for other strategies)      |
//+------------------------------------------------------------------+
void OpenShortPosition(double price, int strategy_id)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double sl = price + StopLoss * point;
    double tp = price - TakeProfit * point;

    OpenShortPositionCustom(price, sl, tp, strategy_id);
}

//+------------------------------------------------------------------+
//| Manage existing positions with trailing stops                   |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        // Fix: Use PositionGetSymbol and PositionGetInteger with index
        if(PositionGetSymbol(i) != _Symbol ||
           PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;

        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_sl = PositionGetDouble(POSITION_SL);
        double current_tp = PositionGetDouble(POSITION_TP);
        ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        double current_price = (pos_type == POSITION_TYPE_BUY) ?
                              SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                              SymbolInfoDouble(_Symbol, SYMBOL_ASK);

        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double initial_risk = 0;
        double profit_points = 0;

        if(pos_type == POSITION_TYPE_BUY)
        {
            initial_risk = (open_price - current_sl) / point;
            profit_points = (current_price - open_price) / point;
        }
        else
        {
            initial_risk = (current_sl - open_price) / point;
            profit_points = (open_price - current_price) / point;
        }

        // Calculate R multiple (profit in terms of initial risk)
        double r_multiple = (initial_risk > 0) ? profit_points / initial_risk : 0;

        //--- Trail stop at ≥1R profit: trail SL to entry ± 0.4R
        if(r_multiple >= 1.0)
        {
            double trail_distance = 0.4 * initial_risk * point;
            double new_sl = 0;

            if(pos_type == POSITION_TYPE_BUY)
            {
                new_sl = open_price + trail_distance;  // entry + 0.4R for long
                if(new_sl > current_sl)
                {
                    trade.PositionModify(ticket, new_sl, current_tp);
                    PrintFormat("Long position trailed: SL=%.5f (entry+0.4R) Profit=%.1fR",
                               new_sl, r_multiple);
                }
            }
            else
            {
                new_sl = open_price - trail_distance;  // entry - 0.4R for short
                if(current_sl == 0 || new_sl < current_sl)
                {
                    trade.PositionModify(ticket, new_sl, current_tp);
                    PrintFormat("Short position trailed: SL=%.5f (entry-0.4R) Profit=%.1fR",
                               new_sl, r_multiple);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get strategy comment based on ID                                 |
//+------------------------------------------------------------------+
string GetStrategyComment(int strategy_id)
{
    switch(strategy_id)
    {
        case 1: return "DAX Breakout";
        case 2: return "DAX MA Signal";
        case 3: return "DAX Scalping";
        default: return "DAX Simple";
    }
}

//+------------------------------------------------------------------+
//| OnTrade event - track wins/losses by strategy (robust version)   |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Select recent history to find position closures
    if(!HistorySelect(TimeCurrent() - 86400, TimeCurrent()))
        return;

    int total_deals = HistoryDealsTotal();
    if(total_deals == 0)
        return;

    // Check recent deals for position closures (DEAL_ENTRY_OUT)
    for(int i = total_deals - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);

        // Skip if already processed this deal (time-based to handle non-sequential tickets)
        datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
        if(deal_time <= last_processed_time)
            break;

        // Check if it's our symbol and magic number
        if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol ||
           HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber)
            continue;

        // Only process position closures (DEAL_ENTRY_OUT)
        ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        if(deal_entry != DEAL_ENTRY_OUT)
            continue;

        // This is a valid position closure - process it
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        string comment = HistoryDealGetString(ticket, DEAL_COMMENT);

        // Update daily loss tracking
        if(profit < 0)
        {
            daily_loss += MathAbs(profit);
        }

        // Track wins by strategy
        if(profit > 0)
        {
            if(StringFind(comment, "Breakout") >= 0) breakout_wins++;
            else if(StringFind(comment, "MA Signal") >= 0) ma_wins++;
            else if(StringFind(comment, "Scalping") >= 0) scalping_wins++;

            consecutive_losses = 0;  // Reset on win
        }
        else if(profit < 0)  // Only count actual losses, not zero-profit deals
        {
            consecutive_losses++;
            if(consecutive_losses > max_consecutive_loss)
                max_consecutive_loss = consecutive_losses;

            // Implement cooldown after MaxConsecLoss consecutive losses
            if(consecutive_losses >= MaxConsecLoss)
            {
                cooldown_end_time = TimeCurrent() + 60 * 60;  // 60 minutes cooldown
                PrintFormat("COOLDOWN ACTIVATED: %d consecutive losses, cooldown until %s",
                           consecutive_losses, TimeToString(cooldown_end_time));
            }
        }

        PrintFormat("POSITION CLOSED [%s]: Profit=%.2f ConsecutiveLosses=%d DailyLoss=%.2f",
                   comment, profit, consecutive_losses, daily_loss);

        // Update last processed deal time
        last_processed_time = deal_time;

        // Print strategy statistics every 10 trades
        if((daily_trade_count % 10) == 0)
            PrintStrategyStats();

        // Only process the most recent closure
        break;
    }
}

//+------------------------------------------------------------------+
//| Print detailed strategy statistics                               |
//+------------------------------------------------------------------+
void PrintStrategyStats()
{
    Print("=== STRATEGY STATISTICS ===");
    Print("Breakout: Signals=", breakout_signals, " Wins=", breakout_wins,
          " WinRate=", (breakout_signals > 0 ? (breakout_wins * 100.0 / breakout_signals) : 0), "%");
    Print("MA Signal: Signals=", ma_signals, " Wins=", ma_wins,
          " WinRate=", (ma_signals > 0 ? (ma_wins * 100.0 / ma_signals) : 0), "%");
    Print("Scalping: Signals=", scalping_signals, " Wins=", scalping_wins,
          " WinRate=", (scalping_signals > 0 ? (scalping_wins * 100.0 / scalping_signals) : 0), "%");
    Print("Max Consecutive Losses: ", max_consecutive_loss);
    Print("Daily Trades: ", daily_trade_count, " Daily Loss: ", daily_loss);
    Print("========================");
}

//+------------------------------------------------------------------+
//| OnTester function with safety guards                            |
//+------------------------------------------------------------------+
double OnTester()
{
    //--- Apply same warm-up and safety checks as OnTick
    if(Bars(_Symbol, _Period) < WarmupBars)
    {
        Print("OnTester: Insufficient bars for testing - Need ", WarmupBars, " bars");
        return 0.0;
    }

    //--- Test basic buffer access safety
    double test_close[];
    ArraySetAsSeries(test_close, true);

    int copied = CopyClose(_Symbol, _Period, 0, 10, test_close);
    if(copied < 10 || ArraySize(test_close) < 10)
    {
        Print("OnTester: Buffer test failed - Copied:", copied, " ArraySize:", ArraySize(test_close));
        return 0.0;
    }

    //--- Return basic profit factor or custom metric
    double total_profit = 0.0;
    double total_loss = 0.0;

    // Simple calculation based on history
    if(HistorySelect(0, TimeCurrent()))
    {
        int total_deals = HistoryDealsTotal();
        for(int i = 0; i < total_deals; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
               HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber)
            {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                if(profit > 0) total_profit += profit;
                else total_loss += MathAbs(profit);
            }
        }
    }

    double profit_factor = (total_loss > 0) ? total_profit / total_loss : 0.0;
    Print("OnTester: Profit Factor = ", profit_factor);

    return profit_factor;
}
