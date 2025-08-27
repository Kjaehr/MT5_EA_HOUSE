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
input int      StopLoss = 15;                    // Stop Loss in pips (slightly wider)
input int      TakeProfit = 45;                  // Take Profit in pips (1.5:1 R/R ratio)
input int      MagicNumber = 789123;             // Magic number
input int      StartHour = 8;                    // Trading start hour (avoid early volatility)
input int      EndHour = 20;                     // Trading end hour (avoid late volatility)
input int      MaxDailyTrades = 15;              // Maximum trades per day (much more conservative)
input double   MaxDailyLoss = 250.0;             // Maximum daily loss (controlled)
input bool     UseBreakoutStrategy = true;       // Use breakout instead of indicators
input bool     UseBothStrategies = false;        // Use only one strategy to avoid conflicts
input bool     UseScalpingMode = false;          // Disable ultra aggressive scalping mode
input int      MinutesBetweenTrades = 10;        // Minimum minutes between trades (longer cooldown)

//--- Indicator parameters (aggressive setup)
input int      RSI_Period = 9;                   // RSI period (faster)
input int      MA_Fast = 5;                      // Fast MA period (very fast)
input int      MA_Slow = 13;                     // Slow MA period (faster)
input int      Breakout_Bars = 4;                // Bars to look for breakout (longer period)
input double   MinBreakoutRange = 18.0;          // Minimum range in pips for breakout (higher threshold)

//--- Global variables
CTrade trade;
int rsi_handle, ma_fast_handle, ma_slow_handle;
int daily_trade_count = 0;
double daily_loss = 0.0;
datetime last_trade_date = 0;
double last_high = 0, last_low = 0;
datetime last_trade_time = 0;
bool has_active_position = false;  // Track if we have any active position

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

    //--- Check if handles are valid
    if(rsi_handle == INVALID_HANDLE || ma_fast_handle == INVALID_HANDLE || ma_slow_handle == INVALID_HANDLE)
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

    //--- Check daily limits
    if(daily_trade_count >= MaxDailyTrades || daily_loss >= MaxDailyLoss)
        return;

    //--- Check time between trades
    if(TimeCurrent() - last_trade_time < MinutesBetweenTrades * 60)
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
    
    //--- Stricter spread check to avoid poor entries
    if(spread > 2.5 * point * 10)
    {
        Print("Spread too wide: ", spread / (point * 10), " pips");
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

    // More lenient trading hours - only skip very early/late
    return (dt.hour >= StartHour && dt.hour < EndHour);
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
//| Update position status                                           |
//+------------------------------------------------------------------+
void UpdatePositionStatus()
{
    has_active_position = false;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            has_active_position = true;
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Check breakout signals (main strategy) - Returns true if signal found |
//+------------------------------------------------------------------+
bool CheckBreakoutSignals(double ask, double bid)
{
    //--- Get recent high/low
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);

    // Buffer safety checks
    int high_copied = CopyHigh(_Symbol, _Period, 1, Breakout_Bars, high);
    int low_copied = CopyLow(_Symbol, _Period, 1, Breakout_Bars, low);
    int close_copied = CopyClose(_Symbol, _Period, 0, 3, close); // Need 3 bars for momentum

    if(high_copied < Breakout_Bars || low_copied < Breakout_Bars || close_copied < 3)
    {
        Print("SKIP: Insufficient buffer data - High:", high_copied, " Low:", low_copied, " Close:", close_copied);
        return false;
    }

    // Bounds guards
    if(ArraySize(high) < Breakout_Bars || ArraySize(low) < Breakout_Bars || ArraySize(close) < 3)
    {
        Print("SKIP: Array size insufficient");
        return false;
    }
    
    //--- Find highest high and lowest low in lookback period
    double recent_high = high[ArrayMaximum(high)];
    double recent_low = low[ArrayMinimum(low)];
    double current_price = close[0];
    
    //--- Improved breakout logic with momentum filter
    bool bullish_breakout = (current_price > recent_high && ask > recent_high);
    bool bearish_breakout = (current_price < recent_low && bid < recent_low);

    //--- Additional filters for better quality signals
    double range = recent_high - recent_low;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    bool sufficient_range = (range > MinBreakoutRange * point * 10);

    // Require momentum: price should be moving in breakout direction
    bool bullish_momentum = (close[0] > close[1] && close[1] >= close[2]);
    bool bearish_momentum = (close[0] < close[1] && close[1] <= close[2]);

    // Combine all conditions
    bullish_breakout = bullish_breakout && bullish_momentum;
    bearish_breakout = bearish_breakout && bearish_momentum;
    
    if(bullish_breakout && sufficient_range)
    {
        breakout_signals++;
        double range_pips = range / (point * 10);
        Print("BREAKOUT LONG: Range=", range_pips, " pips, High=", recent_high, " Current=", current_price);
        OpenLongPosition(ask, 1); // Strategy 1 = Breakout
        return true;
    }
    else if(bearish_breakout && sufficient_range)
    {
        breakout_signals++;
        double range_pips = range / (point * 10);
        Print("BREAKOUT SHORT: Range=", range_pips, " pips, Low=", recent_low, " Current=", current_price);
        OpenShortPosition(bid, 1); // Strategy 1 = Breakout
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
                          (close[0] - close[2]) > 8 * point * 10); // 8+ pips in 3 bars

    bool strong_down_move = (close[0] < close[1] && close[1] < close[2] &&
                            (close[2] - close[0]) > 8 * point * 10); // 8+ pips down in 3 bars

    //--- Quick reversal scalping
    bool bounce_from_low = (close[0] > low[1] && (close[0] - low[1]) > 6 * point * 10);
    bool drop_from_high = (close[0] < high[1] && (high[1] - close[0]) > 6 * point * 10);

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
//| Open long position                                               |
//+------------------------------------------------------------------+
void OpenLongPosition(double price, int strategy_id)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double sl, tp;

    //--- Calculate stop loss (standard for all strategies)
    sl = price - StopLoss * point * 10;

    //--- Calculate take profit
    tp = price + TakeProfit * point * 10;

    //--- Validate lot size
    double validated_lots = ValidateLotSize(LotSize);

    //--- Open position
    if(trade.Buy(validated_lots, _Symbol, price, sl, tp, GetStrategyComment(strategy_id)))
    {
        daily_trade_count++;
        last_trade_time = TimeCurrent();
        double risk_pips = (price - sl) / (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
        double reward_pips = (tp - price) / (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
        Print("LONG OPENED [Strategy ", strategy_id, "]: Price=", price, " SL=", sl, " TP=", tp,
              " Risk=", risk_pips, "pips Reward=", reward_pips, "pips Volume=", validated_lots,
              " Trades today=", daily_trade_count, " Time=", TimeToString(TimeCurrent()));
    }
    else
    {
        Print("FAILED LONG [Strategy ", strategy_id, "]: Error=", GetLastError(), " Volume=", validated_lots,
              " Price=", price, " SL=", sl, " TP=", tp);
    }
}

//+------------------------------------------------------------------+
//| Open short position                                              |
//+------------------------------------------------------------------+
void OpenShortPosition(double price, int strategy_id)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double sl, tp;

    //--- Calculate stop loss (standard for all strategies)
    sl = price + StopLoss * point * 10;

    //--- Calculate take profit
    tp = price - TakeProfit * point * 10;

    //--- Validate lot size
    double validated_lots = ValidateLotSize(LotSize);

    //--- Open position
    if(trade.Sell(validated_lots, _Symbol, price, sl, tp, GetStrategyComment(strategy_id)))
    {
        daily_trade_count++;
        last_trade_time = TimeCurrent();
        double risk_pips = (sl - price) / (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
        double reward_pips = (price - tp) / (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
        Print("SHORT OPENED [Strategy ", strategy_id, "]: Price=", price, " SL=", sl, " TP=", tp,
              " Risk=", risk_pips, "pips Reward=", reward_pips, "pips Volume=", validated_lots,
              " Trades today=", daily_trade_count, " Time=", TimeToString(TimeCurrent()));
    }
    else
    {
        Print("FAILED SHORT [Strategy ", strategy_id, "]: Error=", GetLastError(), " Volume=", validated_lots,
              " Price=", price, " SL=", sl, " TP=", tp);
    }
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double profit_pips = 0;
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                profit_pips = (current_price - open_price) / (point * 10);
            else
                profit_pips = (open_price - current_price) / (point * 10);
            
            //--- Simple breakeven move after 10 pips profit
            if(profit_pips >= 10.0)
            {
                double current_sl = PositionGetDouble(POSITION_SL);
                double new_sl = open_price; // Move to breakeven
                
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && new_sl > current_sl)
                {
                    trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
                    Print("Long position moved to breakeven at ", new_sl);
                }
                else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && 
                       (current_sl == 0 || new_sl < current_sl))
                {
                    trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
                    Print("Short position moved to breakeven at ", new_sl);
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
//| OnTrade event - track wins/losses by strategy                    |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Check if a position was closed
    if(HistorySelect(TimeCurrent() - 86400, TimeCurrent())) // Last 24 hours
    {
        int total_deals = HistoryDealsTotal();
        if(total_deals > 0)
        {
            ulong ticket = HistoryDealGetTicket(total_deals - 1);
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
               HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber)
            {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
                ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);

                if(deal_type == DEAL_TYPE_SELL || deal_type == DEAL_TYPE_BUY) // Position close
                {
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

                        consecutive_losses = 0;
                    }
                    else
                    {
                        consecutive_losses++;
                        if(consecutive_losses > max_consecutive_loss)
                            max_consecutive_loss = consecutive_losses;
                    }

                    Print("TRADE CLOSED [", comment, "]: Profit=", profit, " ConsecutiveLosses=", consecutive_losses, " DailyLoss=", daily_loss);

                    // Print strategy statistics every 10 trades
                    if((daily_trade_count % 10) == 0)
                        PrintStrategyStats();
                }
            }
        }
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
