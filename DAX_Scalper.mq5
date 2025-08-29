//+------------------------------------------------------------------+
//|                                           New_Dax_Refactored.mq5 |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"
#property version   "2.00"

// Include standard MQL5 libraries
#include <Trade/Trade.mqh>

// Include the new modular classes
#include "Include/Logger.mqh"
#include "Include/ConfigManager.mqh"
#include "Include/TradeManager.mqh"
#include "Include/BreakoutStrategy.mqh"
#include "Include/MAStrategy.mqh"

//--- Input parameters (kept for compatibility)
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

//--- Risk management parameters
input double   RiskPerTrade = 0.005;             // 0.5% of equity
input int      MaxConsecLoss = 3;                // Max consecutive losses before cooldown
input double   MaxDailyLossPercent = 0.10;      // 10% of equity
input int      StartDelayMinutes = 15;           // Start delay after market open

//--- Logging parameters
input ENUM_LOG_LEVEL LogLevel = LOG_LEVEL_INFO;  // Log level
input bool     EnableFileLogging = true;         // Enable file logging

//--- Global objects
CLogger*           g_logger = NULL;
CConfigManager*    g_config = NULL;
CTradeManager*     g_trade_manager = NULL;
CBreakoutStrategy* g_breakout_strategy = NULL;
CMAStrategy*       g_ma_strategy = NULL;

//--- Global variables for session management
int daily_trade_count = 0;
double daily_loss = 0.0;
datetime last_trade_date = 0;
datetime last_trade_time = 0;
datetime cooldown_end_time = 0;
int consecutive_losses = 0;
bool is_warmed_up = false;
int WarmupBars = 50;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Initialize logger
    g_logger = new CLogger("DAX_EA", LogLevel);
    if(g_logger == NULL)
    {
        Print("Failed to create logger");
        return INIT_FAILED;
    }

    if(EnableFileLogging)
        g_logger.EnableFileLogging("");

    g_logger.Info("=== DAX EA REFACTORED v2.0 STARTING ===");

    //--- Initialize configuration manager
    g_config = new CConfigManager();
    if(g_config == NULL)
    {
        g_logger.Error("Failed to create configuration manager");
        return INIT_FAILED;
    }

    //--- Update configuration from inputs
    bool config_updated = g_config.UpdateFromInputs(
        LotSize, StopLoss, TakeProfit, MagicNumber,
        StartHour, EndHour, MaxDailyTrades, MaxDailyLoss,
        UseBreakoutStrategy, UseBothStrategies, UseScalpingMode,
        RSI_Period, MA_Fast, MA_Slow, Breakout_Bars,
        RetestBuffer, RangeMultiplier, MinRangeQuality,
        RiskPerTrade, MaxConsecLoss, MaxDailyLossPercent,
        MinutesBetweenTrades, MaxSpreadPoints, StartDelayMinutes
    );

    if(!config_updated)
    {
        g_logger.Error("Configuration validation failed");
        return INIT_FAILED;
    }

    g_config.PrintConfiguration();

    //--- Initialize trade manager
    g_trade_manager = new CTradeManager(_Symbol, MagicNumber, g_logger, g_config);
    if(g_trade_manager == NULL)
    {
        g_logger.Error("Failed to create trade manager");
        return INIT_FAILED;
    }

    //--- Initialize strategies
    if(UseBreakoutStrategy || UseBothStrategies)
    {
        g_breakout_strategy = new CBreakoutStrategy(_Symbol, _Period);
        if(g_breakout_strategy == NULL)
        {
            g_logger.Error("Failed to create breakout strategy");
            return INIT_FAILED;
        }

        g_breakout_strategy.SetLogger(g_logger);
        g_breakout_strategy.SetConfig(g_config);
        g_breakout_strategy.SetTradeManager(g_trade_manager);
        g_breakout_strategy.SetLookbackBars(Breakout_Bars);
        g_breakout_strategy.SetRetestBuffer(RetestBuffer);
        g_breakout_strategy.SetRangeMultiplier(RangeMultiplier);
        g_breakout_strategy.SetMinRangeQuality(MinRangeQuality);

        if(!g_breakout_strategy.Initialize())
        {
            g_logger.Error("Failed to initialize breakout strategy");
            return INIT_FAILED;
        }
    }

    if(!UseBreakoutStrategy || UseBothStrategies)
    {
        g_ma_strategy = new CMAStrategy(_Symbol, _Period);
        if(g_ma_strategy == NULL)
        {
            g_logger.Error("Failed to create MA strategy");
            return INIT_FAILED;
        }

        g_ma_strategy.SetLogger(g_logger);
        g_ma_strategy.SetConfig(g_config);
        g_ma_strategy.SetTradeManager(g_trade_manager);
        g_ma_strategy.SetRSIPeriod(RSI_Period);
        g_ma_strategy.SetMAFastPeriod(MA_Fast);
        g_ma_strategy.SetMASlowPeriod(MA_Slow);

        if(!g_ma_strategy.Initialize())
        {
            g_logger.Error("Failed to initialize MA strategy");
            return INIT_FAILED;
        }
    }

    //--- Calculate warm-up period
    WarmupBars = MathMax(MA_Slow * 3, MathMax(RSI_Period * 3, Breakout_Bars + 5));
    g_logger.Info("Warm-up period set to: " + IntegerToString(WarmupBars) + " bars");

    g_logger.Info("DAX EA Refactored initialized successfully");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(g_logger != NULL)
        g_logger.Info("DAX EA Refactored shutting down. Reason: " + IntegerToString(reason));

    //--- Cleanup strategies
    if(g_breakout_strategy != NULL)
    {
        g_breakout_strategy.Deinitialize();
        delete g_breakout_strategy;
        g_breakout_strategy = NULL;
    }

    if(g_ma_strategy != NULL)
    {
        g_ma_strategy.Deinitialize();
        delete g_ma_strategy;
        g_ma_strategy = NULL;
    }

    //--- Cleanup managers
    if(g_trade_manager != NULL)
    {
        delete g_trade_manager;
        g_trade_manager = NULL;
    }

    if(g_config != NULL)
    {
        delete g_config;
        g_config = NULL;
    }

    if(g_logger != NULL)
    {
        g_logger.Info("=== DAX EA REFACTORED SHUTDOWN COMPLETE ===");
        delete g_logger;
        g_logger = NULL;
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Safety checks
    if(g_logger == NULL || g_config == NULL || g_trade_manager == NULL)
        return;

    //--- Warm-up gate: Check if we have enough bars
    if(Bars(_Symbol, _Period) < WarmupBars)
    {
        if(!is_warmed_up)
        {
            g_logger.Debug("SKIP: Warming up... Need " + IntegerToString(WarmupBars) + " bars, have " + IntegerToString(Bars(_Symbol, _Period)));
        }
        return;
    }

    if(!is_warmed_up)
    {
        is_warmed_up = true;
        g_logger.Info("Warm-up complete. Trading enabled.");
    }

    //--- Check trading hours
    if(!IsTradingTime())
        return;

    //--- Reset daily counters and session tracking
    ResetDailyCounters();

    //--- Check cooldown from consecutive losses
    if(TimeCurrent() < cooldown_end_time)
        return;

    //--- Check daily limits
    double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double max_daily_loss = current_equity * g_config.GetMaxDailyLossPercent();
    if(daily_trade_count >= g_config.GetMaxDailyTrades() || daily_loss >= max_daily_loss)
        return;

    //--- Check time between trades
    if(TimeCurrent() - last_trade_time < g_config.GetMinutesBetweenTrades() * 60)
        return;

    //--- Check for existing positions - ONLY ONE POSITION AT A TIME
    if(g_trade_manager.HasActivePosition())
    {
        ManagePositions();
        return;
    }

    //--- Check strategies for signals
    CheckAndExecuteSignals();
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
        g_logger.Info("Daily counters reset for new trading day");
    }
}

//+------------------------------------------------------------------+
//| Check strategies and execute signals                             |
//+------------------------------------------------------------------+
void CheckAndExecuteSignals()
{
    SSignal signal;
    signal.is_valid = false;

    //--- Strategy priority: Breakout first, then MA
    if(g_config.GetUseBothStrategies())
    {
        // Try breakout strategy first
        if(g_breakout_strategy != NULL && g_breakout_strategy.IsEnabled())
        {
            signal = g_breakout_strategy.CheckSignal();
        }

        // If no breakout signal, try MA strategy
        if(!signal.is_valid && g_ma_strategy != NULL && g_ma_strategy.IsEnabled())
        {
            signal = g_ma_strategy.CheckSignal();
        }
    }
    else if(g_config.GetUseBreakoutStrategy())
    {
        if(g_breakout_strategy != NULL && g_breakout_strategy.IsEnabled())
        {
            signal = g_breakout_strategy.CheckSignal();
        }
    }
    else
    {
        if(g_ma_strategy != NULL && g_ma_strategy.IsEnabled())
        {
            signal = g_ma_strategy.CheckSignal();
        }
    }

    //--- Execute signal if valid
    if(signal.is_valid)
    {
        ExecuteSignal(signal);
    }
}

//+------------------------------------------------------------------+
//| Execute trading signal                                           |
//+------------------------------------------------------------------+
void ExecuteSignal(SSignal& signal)
{
    STradeResult result;

    if(signal.signal_type == ORDER_TYPE_BUY)
    {
        result = g_trade_manager.OpenLongMarket(g_config.GetLotSize(), signal.stop_loss, signal.take_profit, signal.reason);
    }
    else if(signal.signal_type == ORDER_TYPE_SELL)
    {
        result = g_trade_manager.OpenShortMarket(g_config.GetLotSize(), signal.stop_loss, signal.take_profit, signal.reason);
    }

    if(result.success)
    {
        daily_trade_count++;
        last_trade_time = TimeCurrent();
        g_logger.Info("Signal executed successfully. Ticket: " + IntegerToString(result.ticket));
    }
    else
    {
        g_logger.Error("Failed to execute signal. Error: " + IntegerToString(result.error_code));
    }
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
    SPositionInfo pos_info = g_trade_manager.GetPositionInfo();

    if(!pos_info.exists)
        return;

    //--- Check strategy-specific exit conditions
    bool should_exit = false;

    if(g_breakout_strategy != NULL && g_breakout_strategy.IsEnabled())
    {
        should_exit = g_breakout_strategy.ShouldExit(pos_info);
    }

    if(!should_exit && g_ma_strategy != NULL && g_ma_strategy.IsEnabled())
    {
        should_exit = g_ma_strategy.ShouldExit(pos_info);
    }

    if(should_exit)
    {
        g_trade_manager.ClosePosition("Strategy exit signal");
    }

    //--- Implement trailing stop (simplified version)
    if(pos_info.profit_points > 20) // If profit > 20 points
    {
        g_trade_manager.TrailStopLoss(10); // Trail with 10 points distance
    }
}

//+------------------------------------------------------------------+
//| OnTrade event - track wins/losses                               |
//+------------------------------------------------------------------+
void OnTrade()
{
    if(g_logger == NULL || g_config == NULL)
        return;

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

        // Check if it's our symbol and magic number
        if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol ||
           HistoryDealGetInteger(ticket, DEAL_MAGIC) != g_config.GetMagicNumber())
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

        // Track consecutive losses
        if(profit > 0)
        {
            consecutive_losses = 0;  // Reset on win
            g_logger.Info("POSITION CLOSED [WIN]: " + comment + " Profit: " + DoubleToString(profit, 2));
        }
        else if(profit < 0)  // Only count actual losses, not zero-profit deals
        {
            consecutive_losses++;
            g_logger.Warning("POSITION CLOSED [LOSS]: " + comment + " Loss: " + DoubleToString(profit, 2) +
                           " Consecutive losses: " + IntegerToString(consecutive_losses));

            // Implement cooldown after MaxConsecLoss consecutive losses
            if(consecutive_losses >= g_config.GetMaxConsecLoss())
            {
                cooldown_end_time = TimeCurrent() + 60 * 60;  // 60 minutes cooldown
                g_logger.Critical("COOLDOWN ACTIVATED: " + IntegerToString(consecutive_losses) +
                                " consecutive losses, cooldown until " + TimeToString(cooldown_end_time));
            }
        }

        // Only process the most recent closure
        break;
    }
}

//+------------------------------------------------------------------+
//| OnTester function for backtesting                               |
//+------------------------------------------------------------------+
double OnTester()
{
    if(g_logger != NULL)
        g_logger.Info("OnTester: Backtesting completed");

    //--- Calculate basic profit factor
    double total_profit = 0.0;
    double total_loss = 0.0;

    if(HistorySelect(0, TimeCurrent()))
    {
        int total_deals = HistoryDealsTotal();
        for(int i = 0; i < total_deals; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
               HistoryDealGetInteger(ticket, DEAL_MAGIC) == g_config.GetMagicNumber())
            {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                if(profit > 0)
                    total_profit += profit;
                else
                    total_loss += MathAbs(profit);
            }
        }
    }

    double profit_factor = (total_loss > 0) ? total_profit / total_loss : 0.0;

    if(g_logger != NULL)
    {
        g_logger.Info("OnTester Results:");
        g_logger.Info("Total Profit: " + DoubleToString(total_profit, 2));
        g_logger.Info("Total Loss: " + DoubleToString(total_loss, 2));
        g_logger.Info("Profit Factor: " + DoubleToString(profit_factor, 2));

        // Print strategy statistics
        if(g_breakout_strategy != NULL)
            g_breakout_strategy.PrintStatistics();

        if(g_ma_strategy != NULL)
            g_ma_strategy.PrintStatistics();
    }

    return profit_factor;
}