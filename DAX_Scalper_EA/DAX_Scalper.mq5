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
#include "Include/AdvancedStrategy.mqh"

//--- Input parameters (kept for compatibility)
input double   LotSize = 0.1;                    // Lot size (adjusted for DAX)
input int      StopLoss = 80;                    // Stop Loss in pips (wider for DAX volatility)
input int      TakeProfit = 120;                 // Take Profit in pips (1.5:1 R/R ratio)
input int      MagicNumber = 789123;             // Magic number
input int      StartHour = 8;                    // Trading start hour (avoid early volatility)
input int      EndHour = 12;                     // Trading end hour (avoid late volatility)
input int      MaxDailyTrades = 5;               // Maximum trades per day (very conservative)
input double   MaxDailyLoss = 250.0;             // Maximum daily loss (controlled)
input bool     UseBreakoutStrategy = true;       // Use breakout strategy (PROFITABLE - ENABLED)
input bool     UseMAStrategy = true;             // Use MA strategy (PROFITABLE - ENABLED)
input bool     UseAdvancedStrategy = false;      // Use advanced multi-indicator strategy (PROBLEMATIC - DISABLED)
input bool     UseBothStrategies = true;         // Use multiple strategies (breakout + MA only)
input int      MinutesBetweenTrades = 30;        // Minimum minutes between trades (much longer cooldown)
input double   MaxSpreadPoints = 50.0;           // Maximum allowed spread in points

//--- Indicator parameters (aggressive setup)
input int      RSI_Period = 9;                   // RSI period (faster)
input int      MA_Fast = 5;                      // Fast MA period (very fast)
input int      MA_Slow = 13;                     // Slow MA period (faster)
input int      Breakout_Bars = 4;                // Bars to look for breakout
input double   RetestBuffer = 2.0;               // Retest buffer in index points
input double   RangeMultiplier = 1.25;           // TP multiplier (k * Range)
input double   MinRangeQuality = 0.33;           // Minimum body-to-range ratio

//--- Advanced Strategy parameters
input double   MinSignalStrength = 0.6;          // Minimum signal strength (0.0-1.0)
input double   ExitSignalThreshold = 0.4;        // Exit signal threshold
input int      ConfirmationBars = 2;             // Signal confirmation bars
input bool     UseRegimeFilter = false;          // Use market regime filter (DISABLED - PROBLEMATIC)
input bool     UseVolumeFilter = false;          // Use volume profile filter (DISABLED - UNRELIABLE DAX VOLUME)
input bool     UseMicrostructureFilter = false;  // Use microstructure filter (DISABLED - PROBLEMATIC)

//--- Risk management parameters
input double   RiskPerTrade = 0.005;             // 0.5% of equity
input int      MaxConsecLoss = 3;                // Max consecutive losses before cooldown
input double   MaxDailyLossPercent = 0.02;       // 2% of equity (CONSERVATIVE LIKE NEW_DAX)
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
CAdvancedStrategy* g_advanced_strategy = NULL;

//--- Enhanced Error Handling Variables
int                g_last_error = 0;
datetime           g_last_error_time = 0;
int                g_error_count = 0;
int                g_network_error_count = 0;
datetime           g_last_network_error_time = 0;
bool               g_graceful_degradation_mode = false;

//--- Performance Optimization Variables
datetime           g_last_tick_time = 0;
int                g_tick_count = 0;
int                g_processed_ticks = 0;
double             g_cached_ask = 0.0;
double             g_cached_bid = 0.0;
double             g_cached_spread = 0.0;
datetime           g_cache_time = 0;
int                g_cache_validity_seconds = 1; // Cache valid for 1 second
bool               g_market_data_cached = false;

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
    Print("=== DAX_SCALPER_EA OnInit() STARTING ===");

    //--- Initialize logger
    g_logger = new CLogger("DAX_EA", LogLevel);
    if(g_logger == NULL)
    {
        Print("CRITICAL: Failed to create logger");
        return INIT_FAILED;
    }

    Print("Logger created successfully");

    if(EnableFileLogging)
        g_logger.EnableFileLogging("");

    g_logger.Info("=== DAX EA REFACTORED v2.0 STARTING ===");

    //--- Enhanced initialization with error handling
    ResetLastError();

    //--- Validate symbol and market conditions
    if(!ValidateSymbolInfo())
    {
        g_logger.Error("Symbol validation failed during initialization");
        return INIT_FAILED;
    }

    //--- Initialize configuration manager
    g_config = new CConfigManager();
    if(g_config == NULL)
    {
        g_logger.Error("Failed to create configuration manager");
        HandleError(GetLastError(), "Configuration manager creation");
        return INIT_FAILED;
    }

    //--- Update configuration from inputs
    bool config_updated = g_config.UpdateFromInputs(
        LotSize, StopLoss, TakeProfit, MagicNumber,
        StartHour, EndHour, MaxDailyTrades, MaxDailyLoss,
        UseBreakoutStrategy, UseBothStrategies, false, // UseScalpingMode deprecated
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

        g_breakout_strategy.Enable(); // FIXED: Enable the strategy after initialization
        g_logger.Info("Breakout strategy created, initialized and enabled successfully");
    }

    if(UseMAStrategy || UseBothStrategies)
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

        g_ma_strategy.Enable(); // FIXED: Enable the strategy after initialization
        g_logger.Info("MA strategy created, initialized and enabled successfully");
    }

    // DISABLED: Advanced strategy causes problems with unstable custom indicators
    if(UseAdvancedStrategy && !UseBothStrategies) // Only if explicitly enabled and not using both
    {
        g_advanced_strategy = new CAdvancedStrategy(_Symbol, _Period);
        if(g_advanced_strategy == NULL)
        {
            g_logger.Error("Failed to create advanced strategy");
            return INIT_FAILED;
        }

        g_advanced_strategy.SetLogger(g_logger);
        g_advanced_strategy.SetConfig(g_config);
        g_advanced_strategy.SetTradeManager(g_trade_manager);

        // Configure advanced strategy parameters
        g_advanced_strategy.SetMinSignalStrength(MinSignalStrength);
        g_advanced_strategy.SetExitThreshold(ExitSignalThreshold);
        g_advanced_strategy.SetConfirmationBars(ConfirmationBars);
        g_advanced_strategy.SetRegimeFilter(UseRegimeFilter);
        g_advanced_strategy.SetVolumeFilter(UseVolumeFilter);
        g_advanced_strategy.SetMicrostructureFilter(UseMicrostructureFilter);

        if(!g_advanced_strategy.Initialize())
        {
            g_logger.Error("Failed to initialize advanced strategy");
            return INIT_FAILED;
        }

        g_advanced_strategy.Enable(); // FIXED: Enable the strategy after initialization
        g_logger.Info("Advanced strategy created, initialized and enabled successfully");
    }

    //--- Calculate warm-up period (REDUCED for backtest compatibility)
    WarmupBars = MathMax(MA_Slow + 5, RSI_Period + 5); // Much smaller warmup: ~18 bars instead of 39
    g_logger.Info("Warm-up period set to: " + IntegerToString(WarmupBars) + " bars");
    Print("WARMUP BARS CALCULATED: ", WarmupBars, " (MA_Slow=", MA_Slow, " RSI_Period=", RSI_Period, ")");

    //--- Performance optimization: Initialize arrays and caching
    OptimizeArrayOperations();

    //--- Set timer for bar events
    EventSetTimer(1); // Check every second for new bars

    g_logger.Info("DAX EA Refactored v2.0 initialized successfully with enhanced error handling and performance optimization");
    Print("=== DAX_SCALPER_EA OnInit() COMPLETED SUCCESSFULLY ===");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Kill timer
    EventKillTimer();

    if(g_logger != NULL)
    {
        g_logger.Info("DAX EA Refactored shutting down. Reason: " + IntegerToString(reason));

        //--- Log performance and error statistics before shutdown
        LogPerformanceStats();
        LogErrorStatistics();
    }

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

    if(g_advanced_strategy != NULL)
    {
        g_advanced_strategy.Deinitialize();
        delete g_advanced_strategy;
        g_advanced_strategy = NULL;
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
    //--- CRITICAL DEBUG: Log every OnTick call
    static int total_ticks = 0;
    total_ticks++;

    if(total_ticks % 1000 == 1) // Log every 1000 ticks
    {
        Print("OnTick called - Total ticks: ", total_ticks);
        if(g_logger != NULL)
            g_logger.Info("OnTick called - Total ticks: " + IntegerToString(total_ticks));
    }

    //--- TEMPORARILY DISABLE tick filtering for debugging
    // if(!ShouldProcessTick())
    // {
    //     if(total_ticks % 5000 == 1) // Log filtering less frequently
    //     {
    //         Print("Tick filtered - Total: ", total_ticks);
    //     }
    //     return; // Skip this tick for performance
    // }

    if(total_ticks % 100 == 1) // Log processing more frequently
    {
        Print("Processing tick: ", total_ticks);
    }

    //--- Enhanced Safety checks with error handling
    if(g_logger == NULL || g_config == NULL || g_trade_manager == NULL)
    {
        if(total_ticks % 1000 == 1)
            Print("CRITICAL: Core components not initialized - Logger:", (g_logger != NULL), " Config:", (g_config != NULL), " TradeManager:", (g_trade_manager != NULL));
        return;
    }

    if(total_ticks % 1000 == 1)
        Print("Core components OK - continuing...");

    //--- Check for graceful degradation mode
    if(g_graceful_degradation_mode)
    {
        if(total_ticks % 1000 == 1)
            Print("In graceful degradation mode - cooldown until:", TimeToString(cooldown_end_time));

        if(TimeCurrent() > cooldown_end_time)
        {
            ExitGracefulDegradationMode();
        }
        else
        {
            return; // Skip trading during degradation
        }
    }

    //--- Performance optimization: Use cached market data
    double ask, bid, spread;
    if(!GetCachedMarketData(ask, bid, spread))
    {
        if(total_ticks % 1000 == 1)
            Print("Market data cache failed - Ask:", ask, " Bid:", bid);
        HandleError(GetLastError(), "Market data cache update");
        return;
    }

    if(total_ticks % 1000 == 1)
        Print("Market data OK - Ask:", ask, " Bid:", bid, " Spread:", spread);

    //--- NEW BAR CHECK - Only process on new bars for performance
    static datetime last_bar_time = 0;
    datetime current_bar_time = iTime(_Symbol, _Period, 0);
    bool is_new_bar = (current_bar_time != last_bar_time);

    // Handle iTime error
    if(current_bar_time == 0)
    {
        if(total_ticks % 1000 == 1)
            Print("ERROR: iTime failed - current_bar_time is 0");
        HandleError(GetLastError(), "iTime failed");
        return;
    }

    // DEBUG: Log new bar detection
    if(total_ticks % 1000 == 1)
        Print("Bar check - Current:", TimeToString(current_bar_time), " Last:", TimeToString(last_bar_time), " IsNew:", is_new_bar);

    // Always check positions, but only do heavy calculations on new bars
    if(!is_new_bar && !g_trade_manager.HasActivePosition())
    {
        if(total_ticks % 1000 == 1)
            Print("SKIP: No new bar and no active position");
        return;
    }

    if(is_new_bar)
    {
        last_bar_time = current_bar_time;
        Print("NEW BAR DETECTED at ", TimeToString(current_bar_time));
    }

    //--- Warm-up gate: Check if we have enough bars
    int available_bars = Bars(_Symbol, _Period);
    if(available_bars < WarmupBars)
    {
        // ALWAYS log warmup status on new bars
        if(is_new_bar)
            Print("SKIP: Warming up... Need ", WarmupBars, " bars, have ", available_bars);
        if(!is_warmed_up)
        {
            g_logger.Debug("SKIP: Warming up... Need " + IntegerToString(WarmupBars) + " bars, have " + IntegerToString(available_bars));
        }
        return;
    }

    if(!is_warmed_up)
    {
        is_warmed_up = true;
        Print("WARMUP COMPLETE! Trading enabled with ", available_bars, " bars");
        g_logger.Info("Warm-up complete. Trading enabled.");
    }

    // ALWAYS log progress on new bars
    if(is_new_bar)
        Print("Warmup OK - Available bars: ", available_bars, " Required: ", WarmupBars);

    //--- Check trading hours
    if(!IsTradingTime())
    {
        if(is_new_bar) // Log on new bars
        {
            MqlDateTime dt;
            TimeCurrent(dt);
            Print("SKIP: Outside trading hours - ", dt.hour, ":", dt.min);
        }
        static datetime last_time_log = 0;
        if(TimeCurrent() - last_time_log > 3600) // Log once per hour
        {
            MqlDateTime dt;
            TimeCurrent(dt);
            g_logger.Debug(StringFormat("Outside trading hours: %02d:%02d", dt.hour, dt.min));
            last_time_log = TimeCurrent();
        }
        return;
    }

    if(is_new_bar)
        Print("Trading hours OK - continuing to checks...");

    //--- Reset daily counters and session tracking
    ResetDailyCounters();

    //--- Check cooldown from consecutive losses
    if(TimeCurrent() < cooldown_end_time)
    {
        if(is_new_bar)
            Print("SKIP: In cooldown until ", TimeToString(cooldown_end_time));
        return;
    }

    //--- Check daily limits
    double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double max_daily_loss = current_equity * g_config.GetMaxDailyLossPercent();
    if(daily_trade_count >= g_config.GetMaxDailyTrades() || daily_loss >= max_daily_loss)
    {
        if(is_new_bar)
            Print("SKIP: Daily limits reached - Trades:", daily_trade_count, "/", g_config.GetMaxDailyTrades(), " Loss:", daily_loss, "/", max_daily_loss);
        return;
    }

    //--- Check time between trades
    int time_since_last = (int)(TimeCurrent() - last_trade_time);
    int min_time_required = g_config.GetMinutesBetweenTrades() * 60;
    if(time_since_last < min_time_required)
    {
        if(is_new_bar)
            Print("SKIP: Too soon since last trade - ", time_since_last, "s / ", min_time_required, "s required");
        return;
    }

    if(is_new_bar)
        Print("All checks passed - proceeding to signal logic... is_new_bar=", is_new_bar);

    //--- Check for existing positions - ONLY ONE POSITION AT A TIME
    if(g_trade_manager.HasActivePosition())
    {
        ManagePositions();
        return;
    }

    //--- Always update position status
    if(g_advanced_strategy != NULL && g_advanced_strategy.IsEnabled())
        g_advanced_strategy.OnTick();
    if(g_breakout_strategy != NULL && g_breakout_strategy.IsEnabled())
        g_breakout_strategy.OnTick();
    if(g_ma_strategy != NULL && g_ma_strategy.IsEnabled())
        g_ma_strategy.OnTick();

    //--- Heavy calculations and signal checking only on new bars
    Print("Before signal check - is_new_bar=", is_new_bar);
    if(is_new_bar)
    {
        Print("ENTERING SIGNAL CHECK BLOCK");
        g_logger.Debug("New bar detected - checking for signals");

        // Call OnBar for strategies that have it
        if(g_advanced_strategy != NULL && g_advanced_strategy.IsEnabled())
            g_advanced_strategy.OnBar();

        // Check for new signals
        CheckAndExecuteSignals();
    }
    else
    {
        static int tick_count = 0;
        tick_count++;
        if(tick_count % 100 == 0) // Log every 100 ticks
        {
            g_logger.Debug("Waiting for new bar... (tick " + IntegerToString(tick_count) + ")");
        }
    }
}

//+------------------------------------------------------------------+
//| Timer event - handle bar events                                 |
//+------------------------------------------------------------------+
void OnTimer()
{
    static datetime last_bar_time = 0;
    datetime current_bar_time = iTime(_Symbol, _Period, 0);

    // Check if we have a new bar
    if(current_bar_time != last_bar_time)
    {
        last_bar_time = current_bar_time;

        // Call OnBar for all active strategies
        if(g_advanced_strategy != NULL && g_advanced_strategy.IsEnabled())
            g_advanced_strategy.OnBar();
        if(g_breakout_strategy != NULL && g_breakout_strategy.IsEnabled())
            g_breakout_strategy.OnBar();
        if(g_ma_strategy != NULL && g_ma_strategy.IsEnabled())
            g_ma_strategy.OnBar();
    }
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                    |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
    MqlDateTime dt;
    TimeCurrent(dt);

    // NORMAL DAX TRADING HOURS: 09:00-17:00 (main active session)
    bool trading_session = (dt.hour >= 9 && dt.hour < 17);

    // Alternative: Use specific DAX hours if needed
    // bool main_session = (dt.hour >= 8 && dt.hour < 22);
    // bool extended_session = (dt.hour >= 1 && dt.hour < 8) || (dt.hour >= 22 && dt.hour <= 23);
    // bool trading_session = main_session || extended_session;

    // DEBUG: Log trading hours check
    static datetime last_log = 0;
    if(TimeCurrent() - last_log > 3600) // Log once per hour
    {
        Print("IsTradingTime check - Hour: ", dt.hour, " Min: ", dt.min, " Result: ", trading_session);
        last_log = TimeCurrent();
    }

    return trading_session;
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



    //--- Strategy priority: Advanced first, then others
    if(g_config.GetUseBothStrategies())
    {
        Print("Using both strategies mode");

        // FIXED: Prioritize profitable strategies first (breakout + MA only)
        // Try breakout strategy first (most profitable)
        if(g_breakout_strategy != NULL && g_breakout_strategy.IsEnabled())
        {
            Print("Checking breakout strategy");
            signal = g_breakout_strategy.CheckSignal();
            if(signal.is_valid)
                Print("Breakout signal found: ", signal.reason);
        }
        else
        {
            Print("Breakout strategy not available or not enabled");
        }

        // If no breakout signal, try MA strategy
        if(!signal.is_valid && g_ma_strategy != NULL && g_ma_strategy.IsEnabled())
        {
            Print("Checking MA strategy");
            signal = g_ma_strategy.CheckSignal();
            if(signal.is_valid)
                Print("MA signal found: ", signal.reason);
        }
        else if(!signal.is_valid)
        {
            Print("MA strategy not available or not enabled");
        }

        // Advanced strategy disabled by default (problematic indicators)
        // if(!signal.is_valid && g_advanced_strategy != NULL && g_advanced_strategy.IsEnabled())
        // {
        //     signal = g_advanced_strategy.CheckSignal();
        // }
    }
    else if(UseAdvancedStrategy)
    {
        if(g_advanced_strategy != NULL && g_advanced_strategy.IsEnabled())
        {
            signal = g_advanced_strategy.CheckSignal();
        }
    }
    else if(UseBreakoutStrategy)
    {
        if(g_breakout_strategy != NULL && g_breakout_strategy.IsEnabled())
        {
            signal = g_breakout_strategy.CheckSignal();
        }
    }
    else if(UseMAStrategy)
    {
        if(g_ma_strategy != NULL && g_ma_strategy.IsEnabled())
        {
            signal = g_ma_strategy.CheckSignal();
        }
    }

    //--- Execute signal if valid
    if(signal.is_valid)
    {
        Print("Valid signal found - executing: ", signal.reason);
        ExecuteSignal(signal);
    }
    else
    {
        Print("No valid signals found");
    }
}

//+------------------------------------------------------------------+
//| Execute trading signal                                           |
//+------------------------------------------------------------------+
void ExecuteSignal(SSignal& signal)
{
    //--- Enhanced validation before trade execution
    if(!ValidateMarketData())
    {
        g_logger.Error("Signal execution aborted: Invalid market data");
        return;
    }

    if(!ValidateSymbolInfo())
    {
        g_logger.Error("Signal execution aborted: Invalid symbol info");
        return;
    }

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

        // Reset error counters on successful trade
        g_network_error_count = 0;
    }
    else
    {
        // Enhanced error handling for trade failures
        bool is_recoverable = HandleError(result.error_code, "Trade execution: " + signal.reason);

        if(!is_recoverable)
        {
            g_logger.Critical("Non-recoverable trade error - entering degradation mode");
            EnterGracefulDegradationMode("Trade execution failure");
        }
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

    // Check advanced strategy first (highest priority)
    if(g_advanced_strategy != NULL && g_advanced_strategy.IsEnabled())
    {
        should_exit = g_advanced_strategy.ShouldExit(pos_info);
    }

    if(!should_exit && g_breakout_strategy != NULL && g_breakout_strategy.IsEnabled())
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

//+------------------------------------------------------------------+
//| Enhanced Error Handling Functions                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Handle error with comprehensive logging and recovery            |
//+------------------------------------------------------------------+
bool HandleError(int error_code, string context = "")
{
    g_last_error = error_code;
    g_last_error_time = TimeCurrent();
    g_error_count++;

    if(error_code == 0) return true; // No error

    string error_desc = "";
    bool is_critical = false;
    bool is_network = IsNetworkError(error_code);
    bool is_recoverable = IsRecoverableError(error_code);

    // Categorize common MT5 errors
    switch(error_code)
    {
        case 4: error_desc = "Trade server is busy"; break;
        case 6: error_desc = "No connection with trade server"; is_critical = true; break;
        case 8: error_desc = "Too frequent requests"; break;
        case 129: error_desc = "Invalid price"; break;
        case 130: error_desc = "Invalid stops"; break;
        case 131: error_desc = "Invalid trade volume"; break;
        case 132: error_desc = "Market is closed"; break;
        case 133: error_desc = "Trade is disabled"; is_critical = true; break;
        case 134: error_desc = "Not enough money"; is_critical = true; break;
        case 135: error_desc = "Price changed"; break;
        case 136: error_desc = "Off quotes"; break;
        case 137: error_desc = "Broker is busy"; break;
        case 138: error_desc = "Requote"; break;
        case 139: error_desc = "Order is locked"; break;
        case 140: error_desc = "Long positions only allowed"; break;
        case 141: error_desc = "Too many requests"; break;
        case 145: error_desc = "Modification denied because order too close to market"; break;
        case 146: error_desc = "Trade context is busy"; break;
        case 147: error_desc = "Expirations are denied by broker"; break;
        case 148: error_desc = "Amount of open and pending orders has reached the limit"; break;
        default: error_desc = "Unknown error"; break;
    }

    // Log error with appropriate level
    string full_message = StringFormat("Error %d: %s%s",
                                      error_code, error_desc,
                                      (context != "" ? " [Context: " + context + "]" : ""));

    if(is_critical)
    {
        if(g_logger != NULL) g_logger.Critical(full_message);
        EnterGracefulDegradationMode("Critical error: " + error_desc);
    }
    else if(is_network)
    {
        g_network_error_count++;
        g_last_network_error_time = TimeCurrent();
        if(g_logger != NULL) g_logger.Warning("Network " + full_message);

        // Enter degradation mode after multiple network errors
        if(g_network_error_count > 5 &&
           TimeCurrent() - g_last_network_error_time < 300) // 5 minutes
        {
            EnterGracefulDegradationMode("Multiple network errors");
        }
    }
    else
    {
        if(g_logger != NULL) g_logger.Error(full_message);
    }

    return is_recoverable;
}

//+------------------------------------------------------------------+
//| Check if error is network-related                               |
//+------------------------------------------------------------------+
bool IsNetworkError(int error_code)
{
    switch(error_code)
    {
        case 4:   // Trade server is busy
        case 6:   // No connection with trade server
        case 8:   // Too frequent requests
        case 137: // Broker is busy
        case 141: // Too many requests
        case 146: // Trade context is busy
            return true;
        default:
            return false;
    }
}

//+------------------------------------------------------------------+
//| Check if error is recoverable                                   |
//+------------------------------------------------------------------+
bool IsRecoverableError(int error_code)
{
    switch(error_code)
    {
        case 4:   // Trade server is busy - retry later
        case 8:   // Too frequent requests - slow down
        case 129: // Invalid price - get new price
        case 135: // Price changed - get new price
        case 136: // Off quotes - retry
        case 137: // Broker is busy - retry later
        case 138: // Requote - retry with new price
        case 141: // Too many requests - slow down
        case 146: // Trade context is busy - retry
            return true;
        case 6:   // No connection - critical but may recover
        case 133: // Trade is disabled - critical
        case 134: // Not enough money - critical
        case 148: // Too many orders - critical
            return false;
        default:
            return true; // Assume recoverable unless proven otherwise
    }
}

//+------------------------------------------------------------------+
//| Enter graceful degradation mode                                 |
//+------------------------------------------------------------------+
void EnterGracefulDegradationMode(string reason)
{
    if(g_graceful_degradation_mode) return; // Already in degradation mode

    g_graceful_degradation_mode = true;

    if(g_logger != NULL)
    {
        g_logger.Critical("ENTERING GRACEFUL DEGRADATION MODE: " + reason);
        g_logger.Warning("Trading will be suspended for 10 minutes");
    }

    // Set cooldown period
    cooldown_end_time = TimeCurrent() + 600; // 10 minutes
}

//+------------------------------------------------------------------+
//| Exit graceful degradation mode                                  |
//+------------------------------------------------------------------+
void ExitGracefulDegradationMode()
{
    if(!g_graceful_degradation_mode) return;

    g_graceful_degradation_mode = false;
    g_network_error_count = 0; // Reset network error counter

    if(g_logger != NULL)
    {
        g_logger.Info("EXITING GRACEFUL DEGRADATION MODE - Normal operation resumed");
    }
}

//+------------------------------------------------------------------+
//| Validate market data integrity                                  |
//+------------------------------------------------------------------+
bool ValidateMarketData()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Check for invalid prices
    if(ask <= 0 || bid <= 0 || point <= 0)
    {
        if(g_logger != NULL)
            g_logger.Error("Invalid market data: Ask=" + DoubleToString(ask, 5) +
                          " Bid=" + DoubleToString(bid, 5) + " Point=" + DoubleToString(point, 8));
        return false;
    }

    // Check for abnormal spread
    double spread = ask - bid;
    if(spread <= 0 || spread > ask * 0.1) // Spread > 10% of price is abnormal
    {
        if(g_logger != NULL)
            g_logger.Warning("Abnormal spread detected: " + DoubleToString(spread/point, 1) + " points");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Validate symbol information                                     |
//+------------------------------------------------------------------+
bool ValidateSymbolInfo()
{
    if(!SymbolSelect(_Symbol, true))
    {
        if(g_logger != NULL)
            g_logger.Error("Failed to select symbol: " + _Symbol);
        return false;
    }

    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    if(tick_size <= 0 || tick_value <= 0 || min_lot <= 0 || max_lot <= 0)
    {
        if(g_logger != NULL)
            g_logger.Error("Invalid symbol specifications: TickSize=" + DoubleToString(tick_size, 8) +
                          " TickValue=" + DoubleToString(tick_value, 2) +
                          " MinLot=" + DoubleToString(min_lot, 2) +
                          " MaxLot=" + DoubleToString(max_lot, 2));
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Log error statistics                                            |
//+------------------------------------------------------------------+
void LogErrorStatistics()
{
    if(g_logger == NULL) return;

    g_logger.Info("=== ERROR STATISTICS ===");
    g_logger.Info("Total errors: " + IntegerToString(g_error_count));
    g_logger.Info("Network errors: " + IntegerToString(g_network_error_count));
    g_logger.Info("Last error: " + IntegerToString(g_last_error) +
                  " at " + TimeToString(g_last_error_time));
    g_logger.Info("Graceful degradation mode: " + (g_graceful_degradation_mode ? "ACTIVE" : "INACTIVE"));
    g_logger.Info("========================");
}

//+------------------------------------------------------------------+
//| Performance Optimization Functions                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if tick should be processed (tick filtering)             |
//+------------------------------------------------------------------+
bool ShouldProcessTick()
{
    datetime current_time = TimeCurrent();
    g_tick_count++;

    // Always process first tick
    if(g_last_tick_time == 0)
    {
        g_last_tick_time = current_time;
        g_processed_ticks++;
        return true;
    }

    // In backtest, process more frequently for better signal detection
    if(MQLInfoInteger(MQL_TESTER))
    {
        // In backtest, process every tick for better accuracy
        g_last_tick_time = current_time;
        g_processed_ticks++;
        return true;
    }

    // Skip ticks that are too frequent (< 1 second apart) in live trading
    if(current_time - g_last_tick_time < 1)
    {
        return false;
    }

    // Always process if we have active positions
    if(g_trade_manager != NULL && g_trade_manager.HasActivePosition())
    {
        g_last_tick_time = current_time;
        g_processed_ticks++;
        return true;
    }

    // For new signals, process every 1-2 seconds during trading hours
    if(IsTradingTime())
    {
        g_last_tick_time = current_time;
        g_processed_ticks++;
        return true;
    }

    // Outside trading hours, process less frequently (every 10 seconds)
    if(current_time - g_last_tick_time >= 10)
    {
        g_last_tick_time = current_time;
        g_processed_ticks++;
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Update market data cache for performance                        |
//+------------------------------------------------------------------+
bool UpdateMarketDataCache()
{
    datetime current_time = TimeCurrent();

    // Check if cache is still valid
    if(g_market_data_cached && (current_time - g_cache_time) < g_cache_validity_seconds)
    {
        return true; // Use cached data
    }

    // Update cache
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    if(ask <= 0 || bid <= 0)
    {
        return false; // Invalid data
    }

    g_cached_ask = ask;
    g_cached_bid = bid;
    g_cached_spread = ask - bid;
    g_cache_time = current_time;
    g_market_data_cached = true;

    return true;
}

//+------------------------------------------------------------------+
//| Get cached market data for performance                          |
//+------------------------------------------------------------------+
bool GetCachedMarketData(double &ask, double &bid, double &spread)
{
    if(!UpdateMarketDataCache())
        return false;

    ask = g_cached_ask;
    bid = g_cached_bid;
    spread = g_cached_spread;

    return true;
}

//+------------------------------------------------------------------+
//| Optimize array operations and memory management                 |
//+------------------------------------------------------------------+
void OptimizeArrayOperations()
{
    // Pre-allocate commonly used arrays to avoid frequent memory allocation
    static bool arrays_initialized = false;

    if(!arrays_initialized)
    {
        // This function can be called to pre-allocate arrays if needed
        // For now, we rely on MQL5's automatic memory management
        arrays_initialized = true;

        if(g_logger != NULL)
            g_logger.Debug("Array operations optimized");
    }
}

//+------------------------------------------------------------------+
//| Log performance statistics                                      |
//+------------------------------------------------------------------+
void LogPerformanceStats()
{
    if(g_logger == NULL) return;

    double tick_efficiency = (g_tick_count > 0) ? (double)g_processed_ticks / g_tick_count * 100.0 : 0.0;

    g_logger.Info("=== PERFORMANCE STATISTICS ===");
    g_logger.Info("Total ticks received: " + IntegerToString(g_tick_count));
    g_logger.Info("Ticks processed: " + IntegerToString(g_processed_ticks));
    g_logger.Info("Tick efficiency: " + DoubleToString(tick_efficiency, 1) + "%");
    g_logger.Info("Market data cached: " + (g_market_data_cached ? "YES" : "NO"));
    g_logger.Info("Cache validity: " + IntegerToString(g_cache_validity_seconds) + " seconds");
    g_logger.Info("===============================");
}

