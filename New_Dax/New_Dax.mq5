//+------------------------------------------------------------------+
//|                                                     New_Dax.mq5 |
//|                           Admiral Pivot Points DAX Scalper EA   |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"
#property description "Admiral Pivot Points strategy with MACD, Stochastic, and Moving Averages"

#include <Trade/Trade.mqh>
#include "Include/AdmiralStrategy.mqh"
#include "Include/StrategyManager.mqh"

//--- Input parameters
input group "=== Strategy Settings ==="
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15;        // Trading timeframe (5M or 15M)
input ENUM_TIMEFRAMES InpPivotTimeframe = PERIOD_H1;    // Pivot calculation timeframe (H1 or D1)
input double InpMinSignalStrength = 0.7;               // Minimum signal strength (0.0-1.0) - ORIGINAL WORKING VALUE
input int InpStopLossBuffer = 7;                       // Stop loss buffer in pips
input bool InpUseDynamicStops = true;                  // Use dynamic stops based on swing points
input bool InpUsePivotTargets = true;                  // Use pivot levels as targets
input bool InpUseMACDTrend = true;                     // Use MACD trend instead of absolute value

input group "=== Risk Management ==="
input double InpLotSize = 0.01;                        // Fixed lot size (REDUCED for safety)
input double InpRiskPercent = 1.0;                     // Risk per trade (% of account) (REDUCED)
input bool InpUseFixedLots = true;                     // Use fixed lots (false = risk-based)
input double InpMaxLotSize = 0.5;                      // Maximum lot size (INCREASED for seasonal multipliers)
input double InpMinSLDistance = 10.0;                  // Minimum SL distance in PIPS (10 pips = reasonable minimum)
input double InpMaxSLDistance = 50.0;                  // Maximum SL distance in PIPS (50 pips = reasonable maximum)
input int InpMaxDailyTrades = 5;                       // Maximum trades per day

input group "=== Advanced Position Sizing ==="
input bool InpUseDrawdownAdaptive = true;              // Enable drawdown-adaptive sizing
input double InpDrawdownThreshold = 5.0;               // Drawdown threshold (%) to start reducing size
input double InpMaxDrawdownReduction = 0.5;            // Maximum size reduction at high drawdown (50%)
input bool InpUsePerformanceAdaptive = true;           // Enable performance-adaptive sizing
input int InpPerformanceLookback = 20;                 // Number of trades to analyze for performance
input double InpMinPerformanceMultiplier = 0.7;       // Minimum multiplier for poor performance
input double InpMaxPerformanceMultiplier = 1.3;       // Maximum multiplier for good performance

input group "=== Short Optimization ==="
input bool InpOptimizeShorts = true;                  // Enable short trade optimization
input bool InpUseSymmetricRSI = true;                 // Use symmetric RSI thresholds (25/75 instead of 20/80)
input double InpShortSignalStrengthMultiplier = 0.8;  // Signal strength multiplier for shorts (0.8 = 20% lower threshold)
input double InpMaxDailyLoss = 500.0;                  // Maximum daily loss in account currency
input int InpMinutesBetweenTrades = 30;                // Minimum minutes between trades

input group "=== Trading Hours ==="
input int InpStartHour = 8;                            // Trading start hour
input int InpEndHour = 16;                             // Trading end hour
input bool InpTradeOnFriday = false;                   // Allow trading on Friday

input group "=== Advanced Features ==="
input bool InpUseRegimeBasedTrading = false;           // Enable regime-based trading (DISABLED for TrendFollowing focus)
input bool InpUseH4BiasFilter = true;                  // Enable H4 bias filter
input bool InpUseDeterministicSignals = true;          // Enable deterministic signal strength
input bool InpUsePivotZones = true;                    // Enable pivot zones instead of lines
input bool InpUseAdvancedRiskManagement = true;        // Enable advanced risk management
input bool InpUseNewsFilter = true;                    // Enable high impact news filtering

input group "=== Adaptive Position Sizing ==="
input bool InpUseAdaptiveSizing = true;                // Use adaptive position sizing
input double InpBaseRiskPercent = 1.0;                 // Base risk per trade (%)
input double InpMaxRiskPercent = 2.0;                  // Maximum risk per trade (%)



input group "=== Strategy Manager ==="
input bool InpUseStrategyManager = false;              // Enable multi-strategy management
input bool InpUseSignalCombination = false;            // Enable signal combination from multiple strategies
input double InpMinCombinedStrength = 0.7;             // Minimum combined signal strength (0.0-1.0)
input bool InpRequireConsensus = false;                // Require consensus from multiple strategies
input int InpMinConsensusCount = 2;                    // Minimum strategies for consensus (2-4)

input group "=== Individual Strategy Controls ==="
input bool InpEnableAdmiralStrategy = false;           // Enable Admiral Pivot Points Strategy
input bool InpEnableTrendFollowingStrategy = true;     // Enable Trend Following Strategy
input bool InpEnableBreakoutStrategy = false;          // Enable Breakout Strategy (future)
input bool InpEnableMeanReversionStrategy = false;     // Enable Mean Reversion Strategy (future)
input bool InpEnableMomentumStrategy = false;          // Enable Momentum Strategy (future)

input group "=== Strategy Weights ==="
input double InpAdmiralWeight = 1.0;                   // Admiral strategy weight (0.0-2.0)
input double InpTrendFollowingWeight = 0.9;            // Trend Following strategy weight (0.0-2.0)
input double InpBreakoutWeight = 0.8;                  // Breakout strategy weight (0.0-2.0)
input double InpMeanReversionWeight = 0.6;             // Mean Reversion strategy weight (0.0-2.0)
input double InpMomentumWeight = 0.7;                  // Momentum strategy weight (0.0-2.0)

input group "=== Trend Following Parameters ==="
input double InpTrendADXThreshold = 18.0;              // ADX threshold for trend strength (10.0-30.0) - Lowered for more trades
input double InpTrendMinStrength = 0.35;               // Minimum trend strength (0.1-0.8) - Lowered for more trades
input double InpTrendMinSignalStrength = 0.45;         // Minimum signal strength (0.3-0.8) - Lowered for more trades
input bool InpTrendUsePullbacks = false;               // Use pullback entries (disable for more immediate entries)
input bool InpTrendUseBreakouts = false;               // Use breakout continuation logic (disable for simplicity)
input bool InpTrendRequirePriceAboveBothEMAs = false;  // Require price above/below BOTH EMAs (strict mode)
input bool InpTrendAllowEMACrossoverEntries = true;    // Allow entries when price is between EMAs but EMAs are crossed

input group "=== Enhanced Trend Following Features ==="
input bool InpTrendUseMACDConfirmation = false;        // Enable MACD confirmation (disable for more trades)
input bool InpTrendUseMACDTrendMode = false;           // Use MACD trend mode vs signal mode
input bool InpTrendUseMTFBiasFilter = true;            // Enable multi-timeframe bias filter
input ENUM_TIMEFRAMES InpTrendMTFTimeframe = PERIOD_D1; // Higher timeframe for bias (H4/D1) - Changed to D1
input double InpTrendMTFBiasStrengthMin = 0.1;         // Minimum MTF bias strength (0.0-1.0) - Lowered
input bool InpTrendAllowAgainstBias = true;            // Allow trades against MTF bias (more permissive)
input bool InpTrendUseRegimeDetection = false;         // Enable market regime detection (DISABLED for more trades)
input bool InpTrendUseRegimeBasedSizing = false;       // Enable regime-based position sizing (DISABLED)
input bool InpTrendUseRegimeBasedStops = false;        // Enable regime-based stop/target levels (DISABLED)

input group "=== Advanced Risk Management ==="
input bool InpTrendUseDynamicSizing = true;            // Enable dynamic position sizing
input double InpTrendBaseRiskPercent = 1.0;            // Base risk per trade (%)
input double InpTrendMaxRiskPercent = 2.0;             // Maximum risk per trade (%)
input bool InpTrendUseCorrelationFilter = true;        // Enable correlation-based position limits
input double InpTrendMaxCorrelation = 0.7;             // Maximum allowed correlation (0.0-1.0)
input bool InpTrendUseDrawdownProtection = true;       // Enable drawdown-based position reduction
input double InpTrendMaxDrawdownPercent = 10.0;        // Maximum drawdown before reduction (%)

input group "=== Trend Following Trading Hours ==="
input bool InpTrendTradeOnFriday = false;              // Allow TrendFollowing trading on Friday
input bool InpTrendUseProfitableHours = true;          // Use specific profitable hours
input int InpTrendSession1Start = 8;                   // Session 1 start hour (0-23)
input int InpTrendSession1End = 9;                     // Session 1 end hour (0-23)
input int InpTrendSession2Start = 10;                  // Session 2 start hour (0-23)
input int InpTrendSession2End = 11;                    // Session 2 end hour (0-23)
input int InpTrendSession3Start = 17;                  // Session 3 start hour (0-23)
input int InpTrendSession3End = 20;                    // Session 3 end hour (0-23)

input group "=== General Settings ==="
input long InpMagicNumber = 20241201;                  // Base Magic number
input long InpAdmiralMagicNumber = 20241201;           // Admiral strategy magic number
input long InpTrendMagicNumber = 20241202;             // TrendFollowing strategy magic number
input string InpTradeComment = "Admiral_DAX";          // Trade comment
input int InpMaxSlippagePoints = 3;                    // Maximum slippage in points
input bool InpVerboseLogging = true;                   // Enable verbose logging

//--- Global variables
CTrade g_trade;
CAdmiralStrategy* g_strategy = NULL;
CTrendFollowingStrategy* g_trend_strategy = NULL;
CStrategyManager* g_strategy_manager = NULL;

// Trading state
datetime g_last_bar_time = 0;
datetime g_last_trade_time = 0;
int g_daily_trades = 0;
double g_daily_pnl = 0.0;
datetime g_last_daily_reset = 0;

// Statistics
int g_total_trades = 0;
int g_winning_trades = 0;
double g_total_profit = 0.0;

// Advanced risk management
double g_daily_risk_used = 0.0;
double g_max_daily_risk = 0.0;
bool g_equity_stop_triggered = false;

// Advanced position sizing variables
double g_recent_trades_pnl[];
double g_peak_equity = 0.0;
double g_current_drawdown = 0.0;
double g_performance_multiplier = 1.0;
double g_drawdown_multiplier = 1.0;

// Long vs Short performance tracking
int g_long_trades = 0;
int g_short_trades = 0;
int g_long_wins = 0;
int g_short_wins = 0;
double g_long_profit = 0.0;
double g_short_profit = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Admiral DAX EA Initialization ===");

    // Validate inputs
    if(!ValidateInputs())
    {
        Print("ERROR: Invalid input parameters");
        return INIT_PARAMETERS_INCORRECT;
    }

    // Initialize trade object
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetDeviationInPoints(InpMaxSlippagePoints);
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    g_trade.SetAsyncMode(false);

    // Initialize strategy
    g_strategy = new CAdmiralStrategy(_Symbol, InpTimeframe, InpPivotTimeframe);
    if(g_strategy == NULL)
    {
        Print("ERROR: Failed to create strategy object");
        return INIT_FAILED;
    }

    // Configure strategy (legacy parameters)
    g_strategy.SetMinSignalStrength(InpMinSignalStrength);
    g_strategy.SetStopLossBuffer(InpStopLossBuffer);
    g_strategy.SetUseDynamicStops(InpUseDynamicStops);
    g_strategy.SetUsePivotTargets(InpUsePivotTargets);
    g_strategy.SetUseMACDTrend(InpUseMACDTrend);

    // Configure new advanced features
    g_strategy.SetUseRegimeBasedTrading(InpUseRegimeBasedTrading);
    g_strategy.SetUseH4BiasFilter(InpUseH4BiasFilter);
    g_strategy.SetUseDeterministicSignals(InpUseDeterministicSignals);
    g_strategy.SetUsePivotZones(InpUsePivotZones);

    // Initialize strategy
    if(!g_strategy.Initialize())
    {
        Print("ERROR: Failed to initialize strategy");
        delete g_strategy;
        g_strategy = NULL;
        return INIT_FAILED;
    }

    // Configure news filter after initialization
    g_strategy.SetUseNewsFilter(InpUseNewsFilter);

    // Initialize TrendFollowingStrategy if StrategyManager is enabled
    if(InpUseStrategyManager)
    {
        Print("=== INITIALIZING TREND FOLLOWING STRATEGY ===");
        g_trend_strategy = new CTrendFollowingStrategy(_Symbol, InpTimeframe);
        if(g_trend_strategy == NULL)
        {
            Print("ERROR: Failed to create TrendFollowingStrategy object");
            delete g_strategy;
            g_strategy = NULL;
            return INIT_FAILED;
        }
        Print("TrendFollowingStrategy object created successfully");

        // Configure Enhanced TrendFollowingStrategy parameters
        STrendFollowingParams trend_params;

        // Basic trend parameters
        trend_params.adx_threshold = InpTrendADXThreshold;
        trend_params.min_trend_strength = InpTrendMinStrength;
        trend_params.use_pullback_entries = InpTrendUsePullbacks;
        trend_params.enable_breakout_logic = InpTrendUseBreakouts;
        trend_params.require_price_above_both_emas = InpTrendRequirePriceAboveBothEMAs;
        trend_params.allow_ema_crossover_entries = InpTrendAllowEMACrossoverEntries;

        // Enhanced MACD parameters
        trend_params.use_macd_confirmation = InpTrendUseMACDConfirmation;
        trend_params.use_macd_trend_mode = InpTrendUseMACDTrendMode;

        // Multi-timeframe parameters
        trend_params.use_mtf_bias_filter = InpTrendUseMTFBiasFilter;
        trend_params.mtf_timeframe = InpTrendMTFTimeframe;
        trend_params.mtf_bias_strength_min = InpTrendMTFBiasStrengthMin;
        trend_params.allow_against_bias = InpTrendAllowAgainstBias;

        // Market regime parameters
        trend_params.use_regime_detection = InpTrendUseRegimeDetection;
        trend_params.use_regime_based_sizing = InpTrendUseRegimeBasedSizing;
        trend_params.use_regime_based_stops = InpTrendUseRegimeBasedStops;

        // Advanced risk management
        trend_params.use_dynamic_sizing = InpTrendUseDynamicSizing;
        trend_params.base_risk_percent = InpTrendBaseRiskPercent;
        trend_params.max_risk_percent = InpTrendMaxRiskPercent;
        trend_params.use_correlation_filter = InpTrendUseCorrelationFilter;
        trend_params.max_correlation = InpTrendMaxCorrelation;
        trend_params.use_drawdown_protection = InpTrendUseDrawdownProtection;
        trend_params.max_drawdown_percent = InpTrendMaxDrawdownPercent;

        // Set trading hours for TrendFollowing strategy
        trend_params.trade_on_friday = InpTrendTradeOnFriday;
        trend_params.use_profitable_hours = InpTrendUseProfitableHours;
        trend_params.session1_start = InpTrendSession1Start;
        trend_params.session1_end = InpTrendSession1End;
        trend_params.session2_start = InpTrendSession2Start;
        trend_params.session2_end = InpTrendSession2End;
        trend_params.session3_start = InpTrendSession3Start;
        trend_params.session3_end = InpTrendSession3End;

        // Set adaptive sizing parameters
        trend_params.use_adaptive_sizing = InpUseAdaptiveSizing;
        trend_params.use_dynamic_sizing = InpUseAdaptiveSizing; // Use same setting
        trend_params.base_risk_percent = InpBaseRiskPercent;
        trend_params.max_risk_percent = InpMaxRiskPercent;

        g_trend_strategy.SetTrendParams(trend_params);

        Print("Initializing TrendFollowingStrategy...");
        if(!g_trend_strategy.Initialize())
        {
            Print("ERROR: Failed to initialize TrendFollowingStrategy");
            delete g_trend_strategy;
            g_trend_strategy = NULL;
            delete g_strategy;
            g_strategy = NULL;
            return INIT_FAILED;
        }
        Print("TrendFollowingStrategy initialized successfully");

        // Update risk parameters after initialization
        SStrategyRiskParams risk_params = g_trend_strategy.GetRiskParams();
        risk_params.min_signal_strength = InpTrendMinSignalStrength;
        g_trend_strategy.SetRiskParams(risk_params);

        Print("Enhanced TrendFollowingStrategy initialized successfully (OPTIMIZED FOR MORE TRADES):");
        Print("  ADX threshold: ", InpTrendADXThreshold, ", Min strength: ", InpTrendMinStrength, ", Min signal: ", InpTrendMinSignalStrength);
        Print("  EMA strict mode: ", InpTrendRequirePriceAboveBothEMAs, ", Allow crossover entries: ", InpTrendAllowEMACrossoverEntries);
        Print("  MACD confirmation: ", InpTrendUseMACDConfirmation, ", MTF bias: ", InpTrendUseMTFBiasFilter, ", Regime detection: ", InpTrendUseRegimeDetection);
        Print("  Pullbacks: ", InpTrendUsePullbacks, ", Breakouts: ", InpTrendUseBreakouts);
        Print("  Dynamic sizing: ", InpTrendUseDynamicSizing, ", Base risk: ", InpTrendBaseRiskPercent, "%");
        Print("Enhanced TrendFollowingStrategy object created: ", g_trend_strategy != NULL ? "YES" : "NO");
    }

    // Initialize StrategyManager if enabled
    if(InpUseStrategyManager)
    {
        Print("=== INITIALIZING STRATEGY MANAGER ===");
        g_strategy_manager = new CStrategyManager(_Symbol, InpTimeframe);
        if(g_strategy_manager == NULL)
        {
            Print("ERROR: Failed to create StrategyManager object");
            if(g_trend_strategy != NULL)
            {
                delete g_trend_strategy;
                g_trend_strategy = NULL;
            }
            delete g_strategy;
            g_strategy = NULL;
            return INIT_FAILED;
        }
        Print("StrategyManager object created successfully");

        // Set Admiral strategy in StrategyManager
        if(!g_strategy_manager.SetAdmiralStrategy(g_strategy))
        {
            Print("ERROR: Failed to set Admiral strategy in StrategyManager");
            delete g_strategy_manager;
            g_strategy_manager = NULL;
            if(g_trend_strategy != NULL)
            {
                delete g_trend_strategy;
                g_trend_strategy = NULL;
            }
            delete g_strategy;
            g_strategy = NULL;
            return INIT_FAILED;
        }

        // Set TrendFollowingStrategy in StrategyManager
        if(g_trend_strategy != NULL)
        {
            Print("Setting TrendFollowingStrategy in StrategyManager...");
            if(!g_strategy_manager.SetTrendFollowingStrategy(g_trend_strategy))
            {
                Print("ERROR: Failed to set TrendFollowing strategy in StrategyManager");
                delete g_strategy_manager;
                g_strategy_manager = NULL;
                delete g_trend_strategy;
                g_trend_strategy = NULL;
                delete g_strategy;
                g_strategy = NULL;
                return INIT_FAILED;
            }
            Print("TrendFollowingStrategy successfully set in StrategyManager");
        }
        else
        {
            Print("WARNING: TrendFollowingStrategy is NULL - not setting in StrategyManager");
        }

        // Configure StrategyManager
        g_strategy_manager.SetUseCombination(InpUseSignalCombination);
        g_strategy_manager.SetMinCombinedStrength(InpMinCombinedStrength);
        g_strategy_manager.SetRequireConsensus(InpRequireConsensus, InpMinConsensusCount);

        // Configure individual strategies
        Print("=== CONFIGURING STRATEGIES ===");
        Print("Admiral Strategy Input: ", InpEnableAdmiralStrategy);
        Print("TrendFollowing Strategy Input: ", InpEnableTrendFollowingStrategy);

        g_strategy_manager.EnableStrategy(STRATEGY_ADMIRAL, InpEnableAdmiralStrategy);
        g_strategy_manager.EnableStrategy(STRATEGY_TREND_FOLLOWING, InpEnableTrendFollowingStrategy);
        g_strategy_manager.EnableStrategy(STRATEGY_BREAKOUT, InpEnableBreakoutStrategy);
        g_strategy_manager.EnableStrategy(STRATEGY_MEAN_REVERSION, InpEnableMeanReversionStrategy);
        g_strategy_manager.EnableStrategy(STRATEGY_MOMENTUM, InpEnableMomentumStrategy);

        Print("Admiral Strategy Enabled: ", g_strategy_manager.IsStrategyEnabled(STRATEGY_ADMIRAL));
        Print("TrendFollowing Strategy Enabled: ", g_strategy_manager.IsStrategyEnabled(STRATEGY_TREND_FOLLOWING));

        // Set strategy weights
        g_strategy_manager.SetStrategyWeight(STRATEGY_ADMIRAL, InpAdmiralWeight);
        g_strategy_manager.SetStrategyWeight(STRATEGY_TREND_FOLLOWING, InpTrendFollowingWeight);
        g_strategy_manager.SetStrategyWeight(STRATEGY_BREAKOUT, InpBreakoutWeight);
        g_strategy_manager.SetStrategyWeight(STRATEGY_MEAN_REVERSION, InpMeanReversionWeight);
        g_strategy_manager.SetStrategyWeight(STRATEGY_MOMENTUM, InpMomentumWeight);

        // Initialize StrategyManager
        Print("Initializing StrategyManager...");
        if(!g_strategy_manager.Initialize())
        {
            Print("ERROR: Failed to initialize StrategyManager");
            delete g_strategy_manager;
            g_strategy_manager = NULL;
            if(g_trend_strategy != NULL)
            {
                delete g_trend_strategy;
                g_trend_strategy = NULL;
            }
            delete g_strategy;
            g_strategy = NULL;
            return INIT_FAILED;
        }
        Print("StrategyManager initialized successfully");
        Print("Signal combination: ", InpUseSignalCombination ? "ENABLED" : "DISABLED");
        Print("Require consensus: ", InpRequireConsensus ? "ENABLED" : "DISABLED");

        // Give indicators some time to initialize by waiting for a few ticks
        Print("Waiting for indicators to initialize...");
        Sleep(1000); // Wait 1 second for indicators to start calculating
    }

    // Initialize daily reset
    ResetDailyCounters();

    // Initialize adaptive sizing variables
    g_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    g_current_drawdown = 0.0;
    g_performance_multiplier = 1.0;
    g_drawdown_multiplier = 1.0;
    ArrayResize(g_recent_trades_pnl, InpPerformanceLookback);
    ArrayInitialize(g_recent_trades_pnl, 0.0);

    // FINAL STATUS CHECK
    Print("=== FINAL INITIALIZATION STATUS ===");
    Print("InpUseStrategyManager: ", InpUseStrategyManager);
    Print("g_strategy_manager created: ", g_strategy_manager != NULL);
    if(g_strategy_manager != NULL)
    {
        Print("Admiral strategy enabled: ", g_strategy_manager.IsStrategyEnabled(STRATEGY_ADMIRAL));
        Print("TrendFollowing strategy enabled: ", g_strategy_manager.IsStrategyEnabled(STRATEGY_TREND_FOLLOWING));
    }
    Print("g_strategy created: ", g_strategy != NULL);
    Print("g_trend_strategy created: ", g_trend_strategy != NULL);

    Print("Admiral DAX EA initialized successfully");
    Print("Trading timeframe: ", EnumToString(InpTimeframe));
    Print("Pivot timeframe: ", EnumToString(InpPivotTimeframe));
    Print("Magic number: ", InpMagicNumber);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== Admiral DAX EA Deinitialization ===");

    // Clean up StrategyManager first (it manages the strategy reference)
    if(g_strategy_manager != NULL)
    {
        g_strategy_manager.Deinitialize();
        delete g_strategy_manager;
        g_strategy_manager = NULL;
    }

    // Clean up strategies (only if not managed by StrategyManager)
    if(g_trend_strategy != NULL)
    {
        g_trend_strategy.Deinitialize();
        delete g_trend_strategy;
        g_trend_strategy = NULL;
    }

    if(g_strategy != NULL)
    {
        g_strategy.Deinitialize();
        delete g_strategy;
        g_strategy = NULL;
    }

    // Print final statistics
    PrintFinalStatistics();

    Print("Deinitialization reason: ", reason);
    Print("Admiral DAX EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if new bar
    datetime current_bar_time = iTime(_Symbol, InpTimeframe, 0);
    if(current_bar_time == g_last_bar_time)
        return;

    g_last_bar_time = current_bar_time;

    // Reset daily counters if new day
    CheckDailyReset();

    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Debug: Check strategy status periodically
    static datetime last_status_check = 0;
    if(InpUseStrategyManager && g_strategy_manager != NULL && TimeCurrent() - last_status_check > 60) // Every minute
    {
        Print("=== STRATEGY STATUS CHECK ===");
        Print("Admiral enabled: ", g_strategy_manager.IsStrategyEnabled(STRATEGY_ADMIRAL));
        Print("TrendFollowing enabled: ", g_strategy_manager.IsStrategyEnabled(STRATEGY_TREND_FOLLOWING));
        last_status_check = TimeCurrent();
    }

    // Update strategy and check for signals
    ProcessSignals();

    // Manage existing positions
    ManagePositions();

    // Update statistics
    UpdateStatistics();
}

//+------------------------------------------------------------------+
//| Validate input parameters                                       |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
    if(InpMinSignalStrength < 0.0 || InpMinSignalStrength > 1.0)
    {
        Print("ERROR: Invalid signal strength. Must be between 0.0 and 1.0");
        return false;
    }

    if(InpLotSize <= 0.0)
    {
        Print("ERROR: Invalid lot size. Must be greater than 0");
        return false;
    }

    if(InpRiskPercent <= 0.0 || InpRiskPercent > 10.0)
    {
        Print("ERROR: Invalid risk percent. Must be between 0.1 and 10.0");
        return false;
    }

    if(InpStartHour < 0 || InpStartHour > 23 || InpEndHour < 0 || InpEndHour > 23)
    {
        Print("ERROR: Invalid Admiral trading hours. Must be between 0 and 23");
        return false;
    }

    // Validate TrendFollowing session hours
    if(InpTrendSession1Start < 0 || InpTrendSession1Start > 23 || InpTrendSession1End < 0 || InpTrendSession1End > 23 ||
       InpTrendSession2Start < 0 || InpTrendSession2Start > 23 || InpTrendSession2End < 0 || InpTrendSession2End > 23 ||
       InpTrendSession3Start < 0 || InpTrendSession3Start > 23 || InpTrendSession3End < 0 || InpTrendSession3End > 23)
    {
        Print("ERROR: Invalid TrendFollowing session hours. All hours must be between 0 and 23");
        return false;
    }

    if(InpAdmiralMagicNumber == InpTrendMagicNumber)
    {
        Print("ERROR: Admiral and TrendFollowing magic numbers must be different");
        return false;
    }

    if(InpMaxDailyTrades <= 0)
    {
        Print("ERROR: Invalid max daily trades. Must be greater than 0");
        return false;
    }

    // Validate StrategyManager parameters
    if(InpMinCombinedStrength < 0.0 || InpMinCombinedStrength > 1.0)
    {
        Print("ERROR: Invalid combined signal strength. Must be between 0.0 and 1.0");
        return false;
    }

    if(InpMinConsensusCount < 1 || InpMinConsensusCount > 4)
    {
        Print("ERROR: Invalid consensus count. Must be between 1 and 4");
        return false;
    }

    // Validate strategy weights
    if(InpAdmiralWeight < 0.0 || InpAdmiralWeight > 2.0 ||
       InpTrendFollowingWeight < 0.0 || InpTrendFollowingWeight > 2.0 ||
       InpBreakoutWeight < 0.0 || InpBreakoutWeight > 2.0 ||
       InpMeanReversionWeight < 0.0 || InpMeanReversionWeight > 2.0 ||
       InpMomentumWeight < 0.0 || InpMomentumWeight > 2.0)
    {
        Print("ERROR: Invalid strategy weights. Must be between 0.0 and 2.0");
        return false;
    }

    // Validate Trend Following parameters
    if(InpTrendADXThreshold < 10.0 || InpTrendADXThreshold > 30.0)
    {
        Print("ERROR: Invalid ADX threshold. Must be between 10.0 and 30.0");
        return false;
    }

    if(InpTrendMinStrength < 0.1 || InpTrendMinStrength > 0.8)
    {
        Print("ERROR: Invalid minimum trend strength. Must be between 0.1 and 0.8");
        return false;
    }

    if(InpTrendMinSignalStrength < 0.3 || InpTrendMinSignalStrength > 0.8)
    {
        Print("ERROR: Invalid minimum signal strength. Must be between 0.3 and 0.8");
        return false;
    }

    // Validate StrategyManager logic - at least one strategy must be enabled
    if(InpUseStrategyManager)
    {
        if(!InpEnableAdmiralStrategy && !InpEnableTrendFollowingStrategy &&
           !InpEnableBreakoutStrategy && !InpEnableMeanReversionStrategy && !InpEnableMomentumStrategy)
        {
            Print("ERROR: StrategyManager requires at least one strategy to be enabled");
            return false;
        }
    }

    if(InpRequireConsensus && InpMinConsensusCount > 1)
    {
        int enabled_strategies = 0;
        if(InpEnableAdmiralStrategy) enabled_strategies++;
        if(InpEnableTrendFollowingStrategy) enabled_strategies++;
        if(InpEnableBreakoutStrategy) enabled_strategies++;
        if(InpEnableMeanReversionStrategy) enabled_strategies++;
        if(InpEnableMomentumStrategy) enabled_strategies++;

        if(enabled_strategies < InpMinConsensusCount)
        {
            Print("ERROR: Not enough strategies enabled for consensus requirement");
            return false;
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                    |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
    // Check if strategy is initialized
    if(g_strategy == NULL || !g_strategy.IsInitialized())
    {
        if(InpVerboseLogging)
            Print("DEBUG: Strategy not initialized");
        return false;
    }

    // Note: Trading hours are now handled by individual strategies
    // This allows each strategy to have its own optimal trading times

    // Check Friday trading (global setting)
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    if(!InpTradeOnFriday && dt.day_of_week == 5) // Friday
    {
        if(InpVerboseLogging)
            Print("DEBUG: Friday trading disabled (global setting)");
        return false;
    }

    // Check daily limits
    if(g_daily_trades >= InpMaxDailyTrades)
    {
        if(InpVerboseLogging)
            Print("DEBUG: Daily trade limit reached: ", g_daily_trades, "/", InpMaxDailyTrades);
        return false;
    }

    if(g_daily_pnl <= -InpMaxDailyLoss)
    {
        if(InpVerboseLogging)
            Print("DEBUG: Daily loss limit reached: ", g_daily_pnl);
        return false;
    }

    // Check equity stop (2R limit)
    if(!CheckEquityStop())
    {
        if(InpVerboseLogging)
            Print("DEBUG: Equity stop triggered");
        return false;
    }

    // Check time between trades
    if(InpMinutesBetweenTrades > 0 && g_last_trade_time > 0)
    {
        int minutes_since_last = (int)((TimeCurrent() - g_last_trade_time) / 60);
        if(minutes_since_last < InpMinutesBetweenTrades)
        {
            if(InpVerboseLogging)
                Print("DEBUG: Too soon since last trade: ", minutes_since_last, " minutes");
            return false;
        }
    }

    // Check if position already exists for the current strategy
    // Note: This check is now handled per strategy with different magic numbers
    // allowing multiple strategies to have simultaneous positions

    if(InpVerboseLogging)
        Print("DEBUG: Trading allowed");
    return true;
}

//+------------------------------------------------------------------+
//| Check if strategy has existing position                         |
//+------------------------------------------------------------------+
bool HasStrategyPosition(long magic_number)
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == magic_number)
            {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Process trading signals                                        |
//+------------------------------------------------------------------+
void ProcessSignals()
{
    SAdmiralSignal signal;

    // ALWAYS log which path we're taking (even without verbose logging)
    static int signal_count = 0;
    signal_count++;

    // Use StrategyManager if enabled, otherwise use Admiral strategy directly
    if(InpUseStrategyManager && g_strategy_manager != NULL)
    {
        Print("SIGNAL #", signal_count, ": Using StrategyManager - Admiral enabled: ",
              g_strategy_manager.IsStrategyEnabled(STRATEGY_ADMIRAL));

        // Get combined signal from StrategyManager
        SCombinedSignal combined_signal = g_strategy_manager.GetCombinedSignal();

        if(combined_signal.is_valid)
        {
            // Convert combined signal to Admiral signal format
            signal = g_strategy_manager.ConvertToAdmiralSignal(combined_signal);

            Print("SIGNAL #", signal_count, ": StrategyManager generated signal from: ",
                  combined_signal.contributing_strategies);

            if(InpVerboseLogging)
            {
                Print("=== COMBINED SIGNAL DETECTED ===");
                Print(g_strategy_manager.GetCombinedSignalInfo(combined_signal));
            }

            // Store the contributing strategies for trade execution
            signal.signal_description = combined_signal.contributing_strategies;
        }
        else
        {
            Print("SIGNAL #", signal_count, ": StrategyManager - No valid signal");
        }
    }
    else if(!InpUseStrategyManager)
    {
        Print("SIGNAL #", signal_count, ": Using LEGACY mode (StrategyManager disabled)");

        // Legacy mode - use Admiral strategy directly only if StrategyManager is completely disabled
        if(g_strategy == NULL)
        {
            Print("SIGNAL #", signal_count, ": ERROR - Strategy is NULL");
            return;
        }

        // Check for entry signal
        signal = g_strategy.CheckEntrySignal();

        if(signal.is_valid)
        {
            Print("SIGNAL #", signal_count, ": LEGACY Admiral signal detected");
            if(InpVerboseLogging)
            {
                Print("=== ADMIRAL SIGNAL DETECTED (LEGACY) ===");
                Print("Direction: ", signal.is_long ? "LONG" : "SHORT");
                Print("Strength: ", signal.signal_strength);
                Print("Entry: ", signal.entry_price);
                Print("Stop Loss: ", signal.stop_loss);
                Print("Take Profit: ", signal.take_profit);
                Print("Description: ", signal.signal_description);
            }
        }
        else
        {
            Print("SIGNAL #", signal_count, ": LEGACY - No Admiral signal");
        }
    }
    else
    {
        // StrategyManager is enabled but not working properly
        Print("SIGNAL #", signal_count, ": ERROR - StrategyManager enabled but not available");
        Print("InpUseStrategyManager: ", InpUseStrategyManager);
        Print("g_strategy_manager != NULL: ", g_strategy_manager != NULL);
    }

    // Execute trade if we have a valid signal
    if(signal.is_valid)
    {
        Print("SIGNAL #", signal_count, ": EXECUTING TRADE");

        // Determine strategy name from signal description
        string strategy_name = "Admiral"; // Default
        if(StringFind(signal.signal_description, "TrendFollowing") >= 0)
        {
            strategy_name = "TrendFollowing";
        }
        else if(StringFind(signal.signal_description, "Admiral+TrendFollowing") >= 0)
        {
            strategy_name = "Combined"; // For combined signals, we'll use Admiral magic number
        }

        ExecuteTrade(signal, strategy_name);
    }
    else
    {
        Print("SIGNAL #", signal_count, ": No trade executed");
    }
}

//+------------------------------------------------------------------+
//| Execute trade based on signal                                 |
//+------------------------------------------------------------------+
void ExecuteTrade(const SAdmiralSignal &signal, string strategy_name = "Admiral")
{
    // Determine magic number based on strategy
    long magic_number = InpAdmiralMagicNumber; // Default to Admiral
    string trade_comment = InpTradeComment;

    if(strategy_name == "TrendFollowing")
    {
        magic_number = InpTrendMagicNumber;
        trade_comment = "Trend_DAX";
    }
    else if(strategy_name == "Combined")
    {
        magic_number = InpAdmiralMagicNumber; // Use Admiral magic for combined signals
        trade_comment = "Combined_DAX";
    }

    // Check if this strategy already has a position
    if(HasStrategyPosition(magic_number))
    {
        Print("TRADE REJECTED: ", strategy_name, " strategy already has a position (Magic: ", magic_number, ")");
        return;
    }

    Print("EXECUTING TRADE for ", strategy_name, " strategy with Magic Number: ", magic_number);

    // Set the magic number for this trade
    g_trade.SetExpertMagicNumber(magic_number);

    // ENHANCED VALIDATION: Use new fail-safes
    if(!ValidateTradeWithFailsafes(signal))
    {
        Print("TRADE REJECTED: Failed enhanced validation");
        return;
    }

    // Use original signal - no harmful enhancements
    SAdmiralSignal enhanced_signal = signal;

    // LEGACY SAFETY CHECK: Validate signal before execution
    double current_price = enhanced_signal.is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl_distance = MathAbs(current_price - enhanced_signal.stop_loss);
    double tp_distance = MathAbs(enhanced_signal.take_profit - current_price);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Get broker minimum stop level
    double min_stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    double pip_size = 0.1; // 1 pip for DAX = 0.1 price units
    double required_min_distance = MathMax(InpMinSLDistance * pip_size, min_stop_level + 5 * pip_size);

    // EMERGENCY OVERRIDE: Ensure SL is within acceptable range
    double corrected_sl = enhanced_signal.stop_loss;

    // Check if SL is too close
    if(sl_distance < required_min_distance)
    {
        Print("EMERGENCY: SL too close (", sl_distance/pip_size, " pips). Minimum required: ", required_min_distance/pip_size, " pips");
        if(enhanced_signal.is_long)
            corrected_sl = current_price - required_min_distance;
        else
            corrected_sl = current_price + required_min_distance;

        sl_distance = required_min_distance;
    }
    // Check if SL is too far
    else if(sl_distance > InpMaxSLDistance * pip_size)
    {
        Print("EMERGENCY: SL too far (", sl_distance/pip_size, " pips). Maximum allowed: ", InpMaxSLDistance, " pips");
        if(signal.is_long)
            corrected_sl = current_price - (InpMaxSLDistance * pip_size);
        else
            corrected_sl = current_price + (InpMaxSLDistance * pip_size);

        sl_distance = InpMaxSLDistance * pip_size;
    }

    // FIXED: Use pip_size instead of point for DAX validation
    if(sl_distance < InpMinSLDistance * pip_size)
    {
        Print("TRADE REJECTED: Stop loss too close (", sl_distance/pip_size, " pips). Minimum required: ", InpMinSLDistance);
        return;
    }

    if(sl_distance > InpMaxSLDistance * pip_size)
    {
        Print("TRADE REJECTED: Stop loss too far (", sl_distance/pip_size, " pips). Maximum allowed: ", InpMaxSLDistance);
        return;
    }

    if(tp_distance < 20 * pip_size) // Minimum 20 pips TP - FIXED to use pip_size
    {
        Print("TRADE REJECTED: Take profit too close (", tp_distance/pip_size, " pips)");
        return;
    }

    double lot_size = CalculateLotSize(enhanced_signal);

    if(lot_size <= 0)
    {
        Print("ERROR: Invalid lot size calculated: ", lot_size);
        return;
    }

    // FINAL SAFETY: Check account risk
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double max_risk = account_balance * 0.05; // Never risk more than 5% on single trade
    double trade_risk = lot_size * sl_distance * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(trade_risk > max_risk)
    {
        Print("TRADE REJECTED: Risk too high (", trade_risk, ") vs max allowed (", max_risk, ")");
        return;
    }

    Print("EXECUTING TRADE: ", enhanced_signal.is_long ? "BUY" : "SELL",
          " | Lot: ", lot_size, " | SL Distance: ", sl_distance/pip_size, " pips",
          " | Risk: ", trade_risk, " (", (trade_risk/account_balance)*100, "%)",
          " | Corrected SL: ", corrected_sl);

    bool result = false;

    if(enhanced_signal.is_long)
    {
        result = g_trade.Buy(lot_size, _Symbol, enhanced_signal.entry_price,
                           corrected_sl, enhanced_signal.take_profit, trade_comment);
    }
    else
    {
        result = g_trade.Sell(lot_size, _Symbol, enhanced_signal.entry_price,
                            corrected_sl, enhanced_signal.take_profit, trade_comment);
    }

    if(result)
    {
        g_last_trade_time = TimeCurrent();
        g_daily_trades++;
        g_total_trades++;

        // Register trade execution with the appropriate strategy
        if(g_strategy_manager != NULL)
        {
            CTrendFollowingStrategy* trend_strategy = g_strategy_manager.GetTrendFollowingStrategy();
            CAdmiralStrategy* admiral_strategy = g_strategy_manager.GetAdmiralStrategy();

            if(strategy_name == "TrendFollowing" && trend_strategy != NULL)
            {
                trend_strategy.RegisterTradeExecution();
            }
            else if(strategy_name == "Admiral" && admiral_strategy != NULL)
            {
                admiral_strategy.RegisterTradeExecution();
            }
            else if(strategy_name == "Combined")
            {
                // For combined signals, register with both strategies
                if(trend_strategy != NULL)
                    trend_strategy.RegisterTradeExecution();
                if(admiral_strategy != NULL)
                    admiral_strategy.RegisterTradeExecution();
            }
        }

        // Track long vs short performance
        if(enhanced_signal.is_long)
        {
            g_long_trades++;
        }
        else
        {
            g_short_trades++;
        }

        if(InpVerboseLogging)
        {
            Print("TRADE EXECUTED: ", enhanced_signal.is_long ? "BUY" : "SELL",
                  " | Lot: ", lot_size, " | Ticket: ", g_trade.ResultOrder(),
                  " | SL: ", corrected_sl, " | TP: ", enhanced_signal.take_profit);
        }
    }
    else
    {
        Print("TRADE FAILED: ", g_trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk management                   |
//+------------------------------------------------------------------+
double CalculateLotSize(const SAdmiralSignal &signal)
{
    double calculated_lot_size;

    // Get combined risk multiplier (seasonal + volatility) from strategy
    double combined_risk_mult = 1.0;
    if(g_strategy != NULL && g_strategy.GetRegimeManager() != NULL)
    {
        combined_risk_mult = g_strategy.GetRegimeManager().GetCombinedRiskMultiplier();
    }

    // Calculate adaptive multipliers
    UpdateAdaptiveMultipliers();

    // Apply all multipliers: seasonal/volatility + performance + drawdown
    double total_multiplier = combined_risk_mult * g_performance_multiplier * g_drawdown_multiplier;

    if(InpUseFixedLots)
    {
        calculated_lot_size = InpLotSize * total_multiplier;
        Print("DEBUG: Fixed lot with adaptive adjustment - Base:", InpLotSize,
              " Total mult:", total_multiplier, " (Seasonal/Vol:", combined_risk_mult,
              " Performance:", g_performance_multiplier, " Drawdown:", g_drawdown_multiplier, ") Final:", calculated_lot_size);
    }
    else
    {
        // Risk-based position sizing with enhanced safety checks
        double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double base_risk_amount = account_balance * (InpRiskPercent / 100.0);
        double risk_amount = base_risk_amount * total_multiplier;

        Print("DEBUG: Risk-based sizing with adaptive adjustment - Base risk:", base_risk_amount,
              " Total mult:", total_multiplier, " Final risk:", risk_amount);

        double entry_price = signal.entry_price;
        double stop_loss = signal.stop_loss;

        if(stop_loss <= 0 || entry_price <= 0)
        {
            Print("ERROR: Invalid entry or stop loss prices");
            return 0.0;
        }

        double risk_points = MathAbs(entry_price - stop_loss);

        // SAFETY CHECK: Minimum SL distance - FIXED to use pip_size for DAX
        double pip_size = 0.1; // 1 pip for DAX = 0.1 price units
        if(risk_points < InpMinSLDistance * pip_size)
        {
            Print("ERROR: Stop loss too close. Distance: ", risk_points/pip_size, " pips. Required: ", InpMinSLDistance, " pips");
            return 0.0;
        }

        double point_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

        if(point_value <= 0 || tick_size <= 0 || risk_points <= 0)
        {
            Print("ERROR: Invalid symbol parameters");
            return 0.0;
        }

        calculated_lot_size = risk_amount / (risk_points * point_value / tick_size);

        Print("DEBUG: Risk calculation - Balance:", account_balance, " Risk:", risk_amount,
              " Points:", risk_points, " Calculated lot:", calculated_lot_size);
    }

    // Apply lot size limits with MAXIMUM safety limit
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), InpMaxLotSize);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    calculated_lot_size = MathMax(calculated_lot_size, min_lot);
    calculated_lot_size = MathMin(calculated_lot_size, max_lot);
    calculated_lot_size = NormalizeDouble(calculated_lot_size / lot_step, 0) * lot_step;

    // FINAL SAFETY CHECK
    if(calculated_lot_size > InpMaxLotSize)
    {
        Print("WARNING: Calculated lot size (", calculated_lot_size, ") exceeds maximum (", InpMaxLotSize, "). Using maximum.");
        calculated_lot_size = InpMaxLotSize;
    }

    Print("FINAL LOT SIZE: ", calculated_lot_size);
    return calculated_lot_size;
}

//+------------------------------------------------------------------+
//| Manage existing positions                                      |
//+------------------------------------------------------------------+
void ManagePositions()
{
    // Manage all positions for this symbol
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetTicket(i) == 0) continue;

        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        long position_type = PositionGetInteger(POSITION_TYPE);
        bool is_long = (position_type == POSITION_TYPE_BUY);
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        long magic = PositionGetInteger(POSITION_MAGIC);
        double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_price = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

        Print("Managing position: Ticket=", ticket, ", Magic=", magic, ", Type=", is_long ? "LONG" : "SHORT");

    // Advanced trailing stop management
    if(g_strategy != NULL)
    {
        // Check if should move to breakeven
        if(g_strategy.ShouldMoveToBreakeven(ticket, entry_price, current_price))
        {
            double current_sl = PositionGetDouble(POSITION_SL);
            double breakeven_sl = entry_price + (is_long ? 1.0 : -1.0); // 1 point profit

            if((is_long && breakeven_sl > current_sl) || (!is_long && breakeven_sl < current_sl))
            {
                if(g_trade.PositionModify(ticket, breakeven_sl, PositionGetDouble(POSITION_TP)))
                {
                    Print("BREAKEVEN: Moved SL to breakeven+1 for ticket ", ticket);
                }
            }
        }

        // Update trailing stop
        if(g_strategy.UpdateTrailingStop(ticket, entry_price, current_price))
        {
            if(InpVerboseLogging)
                Print("TRAILING: Stop updated for ticket ", ticket);
        }

        // Check exit conditions
        if(g_strategy.ShouldExit(is_long))
        {
            if(g_trade.PositionClose(_Symbol))
            {
                if(InpVerboseLogging)
                    Print("POSITION CLOSED: Exit signal detected");
            }
            else
            {
                Print("FAILED TO CLOSE POSITION: ", g_trade.ResultRetcodeDescription());
            }
        }
    }
    } // Close the for loop
}

//+------------------------------------------------------------------+
//| Reset daily counters                                          |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dt.year, dt.mon, dt.day));

    if(g_last_daily_reset != today)
    {
        g_daily_trades = 0;
        g_daily_pnl = 0.0;
        g_daily_risk_used = 0.0;
        g_equity_stop_triggered = false; // Reset equity stop for new day
        g_last_daily_reset = today;

        if(InpVerboseLogging)
            Print("Daily counters reset for new trading day");
    }
}

//+------------------------------------------------------------------+
//| Check if daily reset is needed                               |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dt.year, dt.mon, dt.day));

    if(g_last_daily_reset != today)
        ResetDailyCounters();
}

//+------------------------------------------------------------------+
//| Update statistics                                             |
//+------------------------------------------------------------------+
void UpdateStatistics()
{
    // Update daily P&L
    double current_daily_pnl = 0.0;

    // Calculate daily P&L from closed positions
    if(HistorySelect(g_last_daily_reset, TimeCurrent()))
    {
        int total_deals = HistoryDealsTotal();
        for(int i = 0; i < total_deals; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket > 0)
            {
                long deal_magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
                if(deal_magic == InpMagicNumber)
                {
                    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                    double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
                    double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);

                    current_daily_pnl += (profit + swap + commission);
                }
            }
        }
    }

    g_daily_pnl = current_daily_pnl;

    // Update StrategyManager performance if enabled
    // Note: This is a simplified approach. In a full implementation,
    // we would track individual trade results and update performance accordingly
    UpdateStrategyManagerPerformance();
}

//+------------------------------------------------------------------+
//| Update StrategyManager Performance (Simplified)                |
//+------------------------------------------------------------------+
void UpdateStrategyManagerPerformance()
{
    // This is a placeholder for strategy performance updates
    // In a full implementation, this would be called when individual trades close
    // with specific trade results (profit/loss, strategy that generated the signal)

    // For now, we'll update performance based on overall statistics
    // when the StrategyManager is enabled
    if(InpUseStrategyManager && g_strategy_manager != NULL)
    {
        // This is a simplified update - in practice, you would track
        // which strategy generated each signal and update accordingly
        // when trades close with their actual results

        // Example: If we knew a trade was generated by Admiral strategy and closed with profit
        // g_strategy_manager.UpdateStrategyPerformance(STRATEGY_ADMIRAL, true, profit_amount);
    }
}

//+------------------------------------------------------------------+
//| Print final statistics                                        |
//+------------------------------------------------------------------+
void PrintFinalStatistics()
{
    Print("=== FINAL STATISTICS ===");
    Print("Total trades: ", g_total_trades);
    Print("Daily trades: ", g_daily_trades);
    Print("Daily P&L: ", g_daily_pnl);
    Print("Winning trades: ", g_winning_trades);
    if(g_total_trades > 0)
        Print("Win rate: ", (double)g_winning_trades / g_total_trades * 100, "%");
    Print("Total profit: ", g_total_profit);
    Print("Current drawdown: ", g_current_drawdown, "%");
    Print("Performance multiplier: ", g_performance_multiplier);
    Print("Drawdown multiplier: ", g_drawdown_multiplier);

    // Long vs Short Performance Analysis
    Print("\n=== LONG vs SHORT ANALYSIS ===");
    Print("Long trades: ", g_long_trades, " | Short trades: ", g_short_trades);
    Print("Long wins: ", g_long_wins, " | Short wins: ", g_short_wins);

    if(g_long_trades > 0)
    {
        double long_win_rate = (double)g_long_wins / g_long_trades * 100;
        double long_avg_profit = g_long_profit / g_long_trades;
        Print("Long win rate: ", long_win_rate, "% | Avg profit per trade: ", long_avg_profit);
    }

    if(g_short_trades > 0)
    {
        double short_win_rate = (double)g_short_wins / g_short_trades * 100;
        double short_avg_profit = g_short_profit / g_short_trades;
        Print("Short win rate: ", short_win_rate, "% | Avg profit per trade: ", short_avg_profit);
    }

    if(g_long_trades > 0 && g_short_trades > 0)
    {
        double long_wr = (double)g_long_wins / g_long_trades * 100;
        double short_wr = (double)g_short_wins / g_short_trades * 100;
        double wr_difference = long_wr - short_wr;
        Print("Win rate difference (Long - Short): ", wr_difference, "%");

        if(wr_difference > 5.0)
            Print("RECOMMENDATION: Shorts underperforming - consider enhancements");
        else if(wr_difference < -5.0)
            Print("RECOMMENDATION: Longs underperforming - consider enhancements");
        else
            Print("PERFORMANCE: Long and short trades are balanced");
    }

    // StrategyManager performance report
    if(InpUseStrategyManager && g_strategy_manager != NULL)
    {
        Print("\n=== STRATEGY MANAGER REPORT ===");
        g_strategy_manager.PrintStrategyStatistics();
    }

    if(g_strategy != NULL)
    {
        Print("Strategy status: ", g_strategy.GetStrategyStatus());
        if(g_strategy.GetRegimeManager() != NULL)
        {
            CTradingRegimeManager* regime_mgr = g_strategy.GetRegimeManager();
            Print("Seasonal multiplier: ", regime_mgr.GetSeasonalRiskMultiplier());
            Print("Volatility multiplier: ", regime_mgr.GetVolatilityMultiplier());
            Print("Combined risk multiplier: ", regime_mgr.GetCombinedRiskMultiplier());
        }
    }

    Print("Equity stop triggered: ", g_equity_stop_triggered ? "YES" : "NO");
}

//+------------------------------------------------------------------+
//| Check equity stop (2R daily loss limit)                        |
//+------------------------------------------------------------------+
bool CheckEquityStop()
{
    if(g_equity_stop_triggered)
        return false; // Already triggered

    // Calculate 2R based on account balance and risk percent
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double single_r = account_balance * (InpRiskPercent / 100.0);
    double max_daily_loss = 2.0 * single_r; // 2R limit

    // Check if daily loss exceeds 2R
    if(g_daily_pnl <= -max_daily_loss)
    {
        g_equity_stop_triggered = true;
        Print("EQUITY STOP TRIGGERED: Daily loss (", g_daily_pnl, ") exceeds 2R limit (", -max_daily_loss, ")");

        // Close any open positions
        CloseAllPositions("Equity stop triggered");

        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Close all open positions                                        |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            long magic = PositionGetInteger(POSITION_MAGIC);
            if(magic == InpMagicNumber)
            {
                if(!g_trade.PositionClose(ticket))
                {
                    Print("ERROR: Failed to close position ", ticket, " - ", reason);
                }
                else
                {
                    Print("Position ", ticket, " closed - ", reason);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Enhanced trade validation with all fail-safes                  |
//+------------------------------------------------------------------+
bool ValidateTradeWithFailsafes(const SAdmiralSignal &signal)
{
    // 1. Check equity stop
    if(!CheckEquityStop())
    {
        Print("TRADE REJECTED: Equity stop triggered");
        return false;
    }

    // 2. Check news times (delegated to regime manager)
    // This is already implemented in the regime manager

    // 3. Basic signal validation
    if(!signal.is_valid)
    {
        Print("TRADE REJECTED: Invalid signal");
        return false;
    }

    // 4. Check minimum distance requirements
    double sl_distance = MathAbs(signal.entry_price - signal.stop_loss);
    double tp_distance = MathAbs(signal.take_profit - signal.entry_price);

    if(sl_distance < 6.0) // Minimum 6 points SL
    {
        Print("TRADE REJECTED: SL too close (", sl_distance, " < 6.0)");
        return false;
    }

    if(tp_distance < 10.0) // Minimum 10 points TP
    {
        Print("TRADE REJECTED: TP too close (", tp_distance, " < 10.0)");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Update adaptive position sizing multipliers                     |
//+------------------------------------------------------------------+
void UpdateAdaptiveMultipliers()
{
    // Update peak equity and drawdown
    double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(current_equity > g_peak_equity)
        g_peak_equity = current_equity;

    g_current_drawdown = (g_peak_equity - current_equity) / g_peak_equity * 100.0;

    // Calculate drawdown multiplier
    if(InpUseDrawdownAdaptive && g_current_drawdown > InpDrawdownThreshold)
    {
        double drawdown_factor = (g_current_drawdown - InpDrawdownThreshold) / (20.0 - InpDrawdownThreshold); // 20% max drawdown assumption
        drawdown_factor = MathMin(drawdown_factor, 1.0); // Cap at 100%
        g_drawdown_multiplier = 1.0 - (drawdown_factor * (1.0 - InpMaxDrawdownReduction));
        g_drawdown_multiplier = MathMax(g_drawdown_multiplier, InpMaxDrawdownReduction);
    }
    else
    {
        g_drawdown_multiplier = 1.0;
    }

    // Calculate performance multiplier
    if(InpUsePerformanceAdaptive)
    {
        UpdatePerformanceMultiplier();
    }
    else
    {
        g_performance_multiplier = 1.0;
    }
}

//+------------------------------------------------------------------+
//| Update performance-based multiplier                             |
//+------------------------------------------------------------------+
void UpdatePerformanceMultiplier()
{
    // Resize array if needed
    if(ArraySize(g_recent_trades_pnl) != InpPerformanceLookback)
    {
        ArrayResize(g_recent_trades_pnl, InpPerformanceLookback);
        ArrayInitialize(g_recent_trades_pnl, 0.0);
    }

    // Calculate recent performance
    double total_pnl = 0.0;
    int valid_trades = 0;

    for(int i = 0; i < ArraySize(g_recent_trades_pnl); i++)
    {
        if(g_recent_trades_pnl[i] != 0.0)
        {
            total_pnl += g_recent_trades_pnl[i];
            valid_trades++;
        }
    }

    if(valid_trades >= 5) // Need at least 5 trades for meaningful analysis
    {
        double avg_pnl = total_pnl / valid_trades;
        double win_rate = 0.0;

        // Calculate win rate
        int wins = 0;
        for(int i = 0; i < valid_trades; i++)
        {
            if(g_recent_trades_pnl[i] > 0) wins++;
        }
        win_rate = (double)wins / valid_trades;

        // Performance score: combine average P&L and win rate
        double performance_score = (avg_pnl > 0 ? 1.0 : 0.5) + (win_rate - 0.5); // Base score + win rate adjustment

        // Convert to multiplier
        if(performance_score > 1.0)
        {
            g_performance_multiplier = 1.0 + (performance_score - 1.0) * (InpMaxPerformanceMultiplier - 1.0);
        }
        else
        {
            g_performance_multiplier = InpMinPerformanceMultiplier + (performance_score * (1.0 - InpMinPerformanceMultiplier));
        }

        g_performance_multiplier = MathMax(g_performance_multiplier, InpMinPerformanceMultiplier);
        g_performance_multiplier = MathMin(g_performance_multiplier, InpMaxPerformanceMultiplier);
    }
    else
    {
        g_performance_multiplier = 1.0; // Neutral until enough data
    }
}

//+------------------------------------------------------------------+
//| Add trade result to performance tracking                        |
//+------------------------------------------------------------------+
void AddTradeToPerformanceTracking(double pnl)
{
    if(ArraySize(g_recent_trades_pnl) == 0) return;

    // Shift array left and add new trade
    for(int i = 0; i < ArraySize(g_recent_trades_pnl) - 1; i++)
    {
        g_recent_trades_pnl[i] = g_recent_trades_pnl[i + 1];
    }
    g_recent_trades_pnl[ArraySize(g_recent_trades_pnl) - 1] = pnl;
}



//+------------------------------------------------------------------+
//| OnTrade event - track completed trades for adaptive sizing      |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Select recent history to find position closures
    if(!HistorySelect(TimeCurrent() - 86400, TimeCurrent()))
        return;

    int total_deals = HistoryDealsTotal();
    if(total_deals == 0)
        return;

    static datetime last_processed_time = 0;

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
           HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
            continue;

        // Only process position closures (DEAL_ENTRY_OUT)
        ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        if(deal_entry != DEAL_ENTRY_OUT)
            continue;

        // This is a valid position closure - process it
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
        double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        double total_pnl = profit + swap + commission;

        // Add to performance tracking for adaptive sizing
        AddTradeToPerformanceTracking(total_pnl);

        // Determine if this was a long or short trade
        string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
        bool was_long_trade = (StringFind(comment, "Buy") >= 0 || StringFind(comment, "BUY") >= 0);

        // Update long vs short statistics
        if(was_long_trade)
        {
            g_long_profit += total_pnl;
            if(total_pnl > 0) g_long_wins++;
        }
        else
        {
            g_short_profit += total_pnl;
            if(total_pnl > 0) g_short_wins++;
        }

        // Update general statistics
        if(total_pnl > 0)
        {
            g_winning_trades++;
        }
        g_total_profit += total_pnl;

        // Update last processed time
        last_processed_time = deal_time;

        if(InpVerboseLogging)
        {
            Print("TRADE COMPLETED: Ticket=", ticket, " P&L=", total_pnl,
                  " (Profit:", profit, " Swap:", swap, " Commission:", commission, ")");
            Print("Performance tracking updated. Recent trades: ", ArraySize(g_recent_trades_pnl));
        }
    }
}