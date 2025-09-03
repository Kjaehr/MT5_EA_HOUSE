//+------------------------------------------------------------------+
//|                                              StrategyManager.mqh |
//|                           Multi-Strategy Management System       |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

#include "AdmiralStrategy.mqh"
#include "TrendFollowingStrategy.mqh"

//+------------------------------------------------------------------+
//| Strategy Type Enumeration                                        |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY_TYPE
{
    STRATEGY_ADMIRAL = 0,      // Admiral Pivot Points Strategy
    STRATEGY_TREND_FOLLOWING = 1, // Trend Following Strategy
    STRATEGY_BREAKOUT = 2,     // Breakout Strategy
    STRATEGY_MEAN_REVERSION = 3, // Mean Reversion Strategy
    STRATEGY_MOMENTUM = 4,     // Momentum Strategy
    STRATEGY_COUNT = 5         // Total number of strategies
};

//+------------------------------------------------------------------+
//| Strategy Performance Structure                                   |
//+------------------------------------------------------------------+
struct SStrategyPerformance
{
    string            name;
    int               total_signals;
    int               successful_trades;
    int               failed_trades;
    double            total_profit;
    double            total_loss;
    double            win_rate;
    double            profit_factor;
    double            avg_profit_per_trade;
    datetime          last_signal_time;
    bool              is_enabled;
    double            weight;

    // Constructor
    SStrategyPerformance()
    {
        name = "";
        total_signals = 0;
        successful_trades = 0;
        failed_trades = 0;
        total_profit = 0.0;
        total_loss = 0.0;
        win_rate = 0.0;
        profit_factor = 0.0;
        avg_profit_per_trade = 0.0;
        last_signal_time = 0;
        is_enabled = true;
        weight = 1.0;
    }

    // Copy constructor
    SStrategyPerformance(const SStrategyPerformance& other)
    {
        name = other.name;
        total_signals = other.total_signals;
        successful_trades = other.successful_trades;
        failed_trades = other.failed_trades;
        total_profit = other.total_profit;
        total_loss = other.total_loss;
        win_rate = other.win_rate;
        profit_factor = other.profit_factor;
        avg_profit_per_trade = other.avg_profit_per_trade;
        last_signal_time = other.last_signal_time;
        is_enabled = other.is_enabled;
        weight = other.weight;
    }

    // Assignment operator
    void operator=(const SStrategyPerformance& other)
    {
        name = other.name;
        total_signals = other.total_signals;
        successful_trades = other.successful_trades;
        failed_trades = other.failed_trades;
        total_profit = other.total_profit;
        total_loss = other.total_loss;
        win_rate = other.win_rate;
        profit_factor = other.profit_factor;
        avg_profit_per_trade = other.avg_profit_per_trade;
        last_signal_time = other.last_signal_time;
        is_enabled = other.is_enabled;
        weight = other.weight;
    }
};

//+------------------------------------------------------------------+
//| Combined Signal Structure                                        |
//+------------------------------------------------------------------+
struct SCombinedSignal
{
    bool              is_valid;
    bool              is_long;
    double            entry_price;
    double            stop_loss;
    double            take_profit;
    double            combined_strength;
    string            contributing_strategies;
    int               strategy_count;
    ENUM_STRATEGY_TYPE primary_strategy;

    // Constructor
    SCombinedSignal()
    {
        is_valid = false;
        is_long = false;
        entry_price = 0.0;
        stop_loss = 0.0;
        take_profit = 0.0;
        combined_strength = 0.0;
        contributing_strategies = "";
        strategy_count = 0;
        primary_strategy = STRATEGY_ADMIRAL;
    }

    // Copy constructor
    SCombinedSignal(const SCombinedSignal& other)
    {
        is_valid = other.is_valid;
        is_long = other.is_long;
        entry_price = other.entry_price;
        stop_loss = other.stop_loss;
        take_profit = other.take_profit;
        combined_strength = other.combined_strength;
        contributing_strategies = other.contributing_strategies;
        strategy_count = other.strategy_count;
        primary_strategy = other.primary_strategy;
    }

    // Assignment operator
    void operator=(const SCombinedSignal& other)
    {
        is_valid = other.is_valid;
        is_long = other.is_long;
        entry_price = other.entry_price;
        stop_loss = other.stop_loss;
        take_profit = other.take_profit;
        combined_strength = other.combined_strength;
        contributing_strategies = other.contributing_strategies;
        strategy_count = other.strategy_count;
        primary_strategy = other.primary_strategy;
    }
};

//+------------------------------------------------------------------+
//| Strategy Manager Class                                          |
//+------------------------------------------------------------------+
class CStrategyManager
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    
    // Strategy instances
    CAdmiralStrategy* m_admiral_strategy;
    CTrendFollowingStrategy* m_trend_following_strategy;
    
    // Strategy performance tracking
    SStrategyPerformance m_performance[STRATEGY_COUNT];
    
    // Configuration
    bool              m_use_signal_combination;
    double            m_min_combined_strength;
    bool              m_require_consensus;
    int               m_min_consensus_count;
    
    // Signal combination weights
    double            m_strategy_weights[STRATEGY_COUNT];
    
    // Internal state
    bool              m_initialized;
    datetime          m_last_update_time;
    
    // Statistics
    int               m_total_combined_signals;
    int               m_successful_combined_trades;
    double            m_total_combined_profit;

public:
    //--- Constructor/Destructor
                      CStrategyManager(string symbol, ENUM_TIMEFRAMES timeframe);
                     ~CStrategyManager();
    
    //--- Initialization
    bool              Initialize();
    void              Deinitialize();
    
    //--- Strategy Management
    bool              SetAdmiralStrategy(CAdmiralStrategy* strategy);
    bool              SetTrendFollowingStrategy(CTrendFollowingStrategy* strategy);
    void              EnableStrategy(ENUM_STRATEGY_TYPE strategy_type, bool enable = true);
    void              SetStrategyWeight(ENUM_STRATEGY_TYPE strategy_type, double weight);
    bool              IsStrategyEnabled(ENUM_STRATEGY_TYPE strategy_type);
    
    //--- Configuration
    void              SetUseCombination(bool use_combination) { m_use_signal_combination = use_combination; }
    void              SetMinCombinedStrength(double min_strength) { m_min_combined_strength = min_strength; }
    void              SetRequireConsensus(bool require_consensus, int min_count = 2);
    
    //--- Signal Processing
    SCombinedSignal   GetCombinedSignal();
    SAdmiralSignal    ConvertToAdmiralSignal(const SCombinedSignal& combined_signal);
    
    //--- Performance Tracking
    void              UpdateStrategyPerformance(ENUM_STRATEGY_TYPE strategy_type, bool trade_success, double profit);
    SStrategyPerformance GetStrategyPerformance(ENUM_STRATEGY_TYPE strategy_type);
    void              ResetPerformanceStats();
    
    //--- Information Methods
    string            GetStrategyName(ENUM_STRATEGY_TYPE strategy_type);
    string            GetPerformanceReport();
    string            GetCombinedSignalInfo(const SCombinedSignal& signal);

    //--- Strategy Access Methods
    CAdmiralStrategy* GetAdmiralStrategy() { return m_admiral_strategy; }
    CTrendFollowingStrategy* GetTrendFollowingStrategy() { return m_trend_following_strategy; }
    
    //--- Utility Methods
    bool              UpdateAllStrategies();
    void              PrintStrategyStatistics();

private:
    //--- Internal Methods
    void              InitializePerformanceTracking();
    void              InitializeDefaultWeights();
    SCombinedSignal   CombineSignals();
    double            CalculateCombinedStrength(const SAdmiralSignal& admiral_signal);
    bool              ValidateCombinedSignal(const SCombinedSignal& signal);
    void              UpdateCombinedStatistics(bool trade_success, double profit);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStrategyManager::CStrategyManager(string symbol, ENUM_TIMEFRAMES timeframe)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    
    // Initialize strategy instances
    m_admiral_strategy = NULL;
    m_trend_following_strategy = NULL;
    
    // Initialize configuration
    m_use_signal_combination = false;  // Default: use Admiral strategy only
    m_min_combined_strength = 0.7;
    m_require_consensus = false;
    m_min_consensus_count = 2;
    
    // Initialize state
    m_initialized = false;
    m_last_update_time = 0;
    
    // Initialize statistics
    m_total_combined_signals = 0;
    m_successful_combined_trades = 0;
    m_total_combined_profit = 0.0;
    
    // Initialize performance tracking and weights
    InitializePerformanceTracking();
    InitializeDefaultWeights();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStrategyManager::~CStrategyManager()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize Strategy Manager                                      |
//+------------------------------------------------------------------+
bool CStrategyManager::Initialize()
{
    if(m_initialized)
        return true;
    
    Print("StrategyManager: Initializing for symbol ", m_symbol, " on timeframe ", EnumToString(m_timeframe));
    
    // Validate that Admiral strategy is set
    if(m_admiral_strategy == NULL)
    {
        Print("StrategyManager: ERROR - Admiral strategy not set");
        return false;
    }
    
    // Initialize Admiral strategy if not already done
    if(!m_admiral_strategy.Initialize())
    {
        Print("StrategyManager: ERROR - Failed to initialize Admiral strategy");
        return false;
    }

    // Initialize TrendFollowing strategy if available
    if(m_trend_following_strategy != NULL)
    {
        if(!m_trend_following_strategy.Initialize())
        {
            Print("StrategyManager: ERROR - Failed to initialize TrendFollowing strategy");
            return false;
        }
        Print("StrategyManager: TrendFollowing strategy initialized successfully");
    }

    m_initialized = true;
    Print("StrategyManager: Successfully initialized");
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize Strategy Manager                                   |
//+------------------------------------------------------------------+
void CStrategyManager::Deinitialize()
{
    if(!m_initialized)
        return;
    
    Print("StrategyManager: Deinitializing...");
    
    // Note: We don't delete m_admiral_strategy as it's managed externally
    m_admiral_strategy = NULL;
    
    m_initialized = false;
    Print("StrategyManager: Deinitialized");
}

//+------------------------------------------------------------------+
//| Set Admiral Strategy                                            |
//+------------------------------------------------------------------+
bool CStrategyManager::SetAdmiralStrategy(CAdmiralStrategy* strategy)
{
    if(strategy == NULL)
    {
        Print("StrategyManager: ERROR - Cannot set NULL Admiral strategy");
        return false;
    }
    
    m_admiral_strategy = strategy;
    m_performance[STRATEGY_ADMIRAL].name = "Admiral Pivot Points";
    // Don't automatically enable - will be set by EnableStrategy() call
    
    Print("StrategyManager: Admiral strategy set successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Set Trend Following Strategy                                   |
//+------------------------------------------------------------------+
bool CStrategyManager::SetTrendFollowingStrategy(CTrendFollowingStrategy* strategy)
{
    if(strategy == NULL)
    {
        Print("StrategyManager: ERROR - Cannot set NULL Trend Following strategy");
        return false;
    }

    m_trend_following_strategy = strategy;
    m_performance[STRATEGY_TREND_FOLLOWING].name = "Trend Following";
    // Don't automatically enable - will be set by EnableStrategy() call

    Print("StrategyManager: Trend Following strategy set successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Enable/Disable Strategy                                         |
//+------------------------------------------------------------------+
void CStrategyManager::EnableStrategy(ENUM_STRATEGY_TYPE strategy_type, bool enable = true)
{
    if(strategy_type >= STRATEGY_COUNT)
    {
        Print("StrategyManager: EnableStrategy - Invalid strategy type: ", strategy_type);
        return;
    }

    Print("StrategyManager: EnableStrategy called - Type: ", strategy_type, ", Enable: ", enable);
    Print("StrategyManager: Before change - is_enabled = ", m_performance[strategy_type].is_enabled);

    m_performance[strategy_type].is_enabled = enable;

    Print("StrategyManager: After change - is_enabled = ", m_performance[strategy_type].is_enabled);

    string status = enable ? "enabled" : "disabled";
    Print("StrategyManager: Strategy ", GetStrategyName(strategy_type), " ", status);
}

//+------------------------------------------------------------------+
//| Set Strategy Weight                                             |
//+------------------------------------------------------------------+
void CStrategyManager::SetStrategyWeight(ENUM_STRATEGY_TYPE strategy_type, double weight)
{
    if(strategy_type >= STRATEGY_COUNT)
        return;

    weight = MathMax(0.0, MathMin(2.0, weight)); // Clamp between 0.0 and 2.0
    m_strategy_weights[strategy_type] = weight;
    m_performance[strategy_type].weight = weight;

    Print("StrategyManager: Strategy ", GetStrategyName(strategy_type), " weight set to ", weight);
}

//+------------------------------------------------------------------+
//| Check if Strategy is Enabled                                   |
//+------------------------------------------------------------------+
bool CStrategyManager::IsStrategyEnabled(ENUM_STRATEGY_TYPE strategy_type)
{
    if(strategy_type >= STRATEGY_COUNT)
    {
        Print("StrategyManager: IsStrategyEnabled - Invalid strategy type: ", strategy_type);
        return false;
    }

    bool enabled = m_performance[strategy_type].is_enabled;

    // Debug logging for Admiral strategy specifically
    if(strategy_type == STRATEGY_ADMIRAL)
    {
        static int check_count = 0;
        check_count++;
        if(check_count <= 10) // Only log first 10 checks to avoid spam
        {
            Print("StrategyManager: IsStrategyEnabled(ADMIRAL) check #", check_count, " = ", enabled);
        }
    }

    return enabled;
}

//+------------------------------------------------------------------+
//| Set Require Consensus                                          |
//+------------------------------------------------------------------+
void CStrategyManager::SetRequireConsensus(bool require_consensus, int min_count = 2)
{
    m_require_consensus = require_consensus;
    m_min_consensus_count = MathMax(1, MathMin(STRATEGY_COUNT, min_count));

    Print("StrategyManager: Consensus requirement set to ", require_consensus,
          " with minimum count ", m_min_consensus_count);
}

//+------------------------------------------------------------------+
//| Get Combined Signal                                             |
//+------------------------------------------------------------------+
SCombinedSignal CStrategyManager::GetCombinedSignal()
{
    SCombinedSignal combined_signal;

    if(!m_initialized)
    {
        Print("StrategyManager: ERROR - Not initialized");
        return combined_signal;
    }

    // Update all strategies first
    if(!UpdateAllStrategies())
    {
        Print("StrategyManager: ERROR - Failed to update strategies");
        return combined_signal;
    }

    // Debug logging
    Print("StrategyManager: GetCombinedSignal - Admiral enabled: ", IsStrategyEnabled(STRATEGY_ADMIRAL),
          ", TrendFollowing enabled: ", IsStrategyEnabled(STRATEGY_TREND_FOLLOWING),
          ", Use combination: ", m_use_signal_combination);

    // If signal combination is disabled, use Admiral strategy only
    if(!m_use_signal_combination)
    {
        // EXTRA SAFETY CHECK: Double-check if Admiral is really enabled
        bool admiral_really_enabled = IsStrategyEnabled(STRATEGY_ADMIRAL);
        Print("StrategyManager: Admiral double-check - Enabled: ", admiral_really_enabled);

        if(m_admiral_strategy != NULL && admiral_really_enabled)
        {
            Print("StrategyManager: Checking Admiral strategy signal...");
            SAdmiralSignal admiral_signal = m_admiral_strategy.CheckEntrySignal();
            if(admiral_signal.is_valid)
            {
                Print("StrategyManager: Admiral signal found - using it");
                combined_signal.is_valid = true;
                combined_signal.is_long = admiral_signal.is_long;
                combined_signal.entry_price = admiral_signal.entry_price;
                combined_signal.stop_loss = admiral_signal.stop_loss;
                combined_signal.take_profit = admiral_signal.take_profit;
                combined_signal.combined_strength = admiral_signal.signal_strength;
                combined_signal.contributing_strategies = "Admiral";
                combined_signal.strategy_count = 1;
                combined_signal.primary_strategy = STRATEGY_ADMIRAL;
            }
            else
            {
                Print("StrategyManager: No Admiral signal found");
            }
        }
        else
        {
            Print("StrategyManager: Admiral strategy - Available: ", m_admiral_strategy != NULL,
                  ", Enabled: ", IsStrategyEnabled(STRATEGY_ADMIRAL));
        }

        // Check TrendFollowing strategy if enabled
        if(m_trend_following_strategy != NULL && IsStrategyEnabled(STRATEGY_TREND_FOLLOWING))
        {
            Print("StrategyManager: Checking TrendFollowing strategy signal...");
            SStrategySignal trend_signal = m_trend_following_strategy.CheckEntrySignal();
            if(trend_signal.is_valid && !combined_signal.is_valid) // Only use if no Admiral signal
            {
                Print("StrategyManager: TrendFollowing signal found - using it");
                combined_signal.is_valid = true;
                combined_signal.is_long = trend_signal.is_long;
                combined_signal.entry_price = trend_signal.entry_price;
                combined_signal.stop_loss = trend_signal.stop_loss;
                combined_signal.take_profit = trend_signal.take_profit;
                combined_signal.combined_strength = trend_signal.signal_strength;
                combined_signal.contributing_strategies = "TrendFollowing";
                combined_signal.strategy_count = 1;
                combined_signal.primary_strategy = STRATEGY_TREND_FOLLOWING;
            }
            else if(trend_signal.is_valid)
            {
                Print("StrategyManager: TrendFollowing signal found but Admiral signal already exists");
            }
            else
            {
                Print("StrategyManager: No TrendFollowing signal found");
            }
        }
        else
        {
            Print("StrategyManager: TrendFollowing strategy - Available: ", m_trend_following_strategy != NULL,
                  ", Enabled: ", IsStrategyEnabled(STRATEGY_TREND_FOLLOWING));
        }

        return combined_signal;
    }

    // Use signal combination logic
    combined_signal = CombineSignals();

    // Validate combined signal
    if(combined_signal.is_valid && !ValidateCombinedSignal(combined_signal))
    {
        Print("StrategyManager: Combined signal validation failed");
        combined_signal.is_valid = false;
    }

    return combined_signal;
}

//+------------------------------------------------------------------+
//| Convert Combined Signal to Admiral Signal                      |
//+------------------------------------------------------------------+
SAdmiralSignal CStrategyManager::ConvertToAdmiralSignal(const SCombinedSignal& combined_signal)
{
    SAdmiralSignal admiral_signal;

    if(!combined_signal.is_valid)
        return admiral_signal;

    admiral_signal.is_valid = true;
    admiral_signal.is_long = combined_signal.is_long;
    admiral_signal.entry_price = combined_signal.entry_price;
    admiral_signal.stop_loss = combined_signal.stop_loss;
    admiral_signal.take_profit = combined_signal.take_profit;
    admiral_signal.signal_strength = combined_signal.combined_strength;
    admiral_signal.signal_description = "COMBINED: " + combined_signal.contributing_strategies;

    return admiral_signal;
}

//+------------------------------------------------------------------+
//| Update Strategy Performance                                     |
//+------------------------------------------------------------------+
void CStrategyManager::UpdateStrategyPerformance(ENUM_STRATEGY_TYPE strategy_type, bool trade_success, double profit)
{
    if(strategy_type >= STRATEGY_COUNT)
        return;

    if(trade_success)
    {
        m_performance[strategy_type].successful_trades++;
        m_performance[strategy_type].total_profit += profit;
    }
    else
    {
        m_performance[strategy_type].failed_trades++;
        m_performance[strategy_type].total_loss += MathAbs(profit);
    }

    // Update calculated metrics
    int total_trades = m_performance[strategy_type].successful_trades + m_performance[strategy_type].failed_trades;
    if(total_trades > 0)
    {
        m_performance[strategy_type].win_rate = (double)m_performance[strategy_type].successful_trades / total_trades * 100.0;
        m_performance[strategy_type].avg_profit_per_trade = (m_performance[strategy_type].total_profit - m_performance[strategy_type].total_loss) / total_trades;
    }

    if(m_performance[strategy_type].total_loss > 0)
        m_performance[strategy_type].profit_factor = m_performance[strategy_type].total_profit / m_performance[strategy_type].total_loss;
    else
        m_performance[strategy_type].profit_factor = m_performance[strategy_type].total_profit > 0 ? 999.0 : 0.0;

    // Update combined statistics if this was a combined signal
    if(m_use_signal_combination)
        UpdateCombinedStatistics(trade_success, profit);
}

//+------------------------------------------------------------------+
//| Get Strategy Performance                                        |
//+------------------------------------------------------------------+
SStrategyPerformance CStrategyManager::GetStrategyPerformance(ENUM_STRATEGY_TYPE strategy_type)
{
    SStrategyPerformance empty_perf;

    if(strategy_type >= STRATEGY_COUNT)
        return empty_perf;

    return m_performance[strategy_type];
}

//+------------------------------------------------------------------+
//| Reset Performance Statistics                                    |
//+------------------------------------------------------------------+
void CStrategyManager::ResetPerformanceStats()
{
    for(int i = 0; i < STRATEGY_COUNT; i++)
    {
        m_performance[i].total_signals = 0;
        m_performance[i].successful_trades = 0;
        m_performance[i].failed_trades = 0;
        m_performance[i].total_profit = 0.0;
        m_performance[i].total_loss = 0.0;
        m_performance[i].win_rate = 0.0;
        m_performance[i].profit_factor = 0.0;
        m_performance[i].avg_profit_per_trade = 0.0;
        m_performance[i].last_signal_time = 0;
    }

    // Reset combined statistics
    m_total_combined_signals = 0;
    m_successful_combined_trades = 0;
    m_total_combined_profit = 0.0;

    Print("StrategyManager: Performance statistics reset");
}

//+------------------------------------------------------------------+
//| Get Strategy Name                                               |
//+------------------------------------------------------------------+
string CStrategyManager::GetStrategyName(ENUM_STRATEGY_TYPE strategy_type)
{
    switch(strategy_type)
    {
        case STRATEGY_ADMIRAL:        return "Admiral Pivot Points";
        case STRATEGY_TREND_FOLLOWING: return "Trend Following";
        case STRATEGY_BREAKOUT:       return "Breakout Strategy";
        case STRATEGY_MEAN_REVERSION: return "Mean Reversion Strategy";
        case STRATEGY_MOMENTUM:       return "Momentum Strategy";
        default:                      return "Unknown Strategy";
    }
}

//+------------------------------------------------------------------+
//| Get Performance Report                                          |
//+------------------------------------------------------------------+
string CStrategyManager::GetPerformanceReport()
{
    string report = "=== STRATEGY MANAGER PERFORMANCE REPORT ===\n";

    for(int i = 0; i < STRATEGY_COUNT; i++)
    {
        if(!m_performance[i].is_enabled && m_performance[i].successful_trades == 0 && m_performance[i].failed_trades == 0)
            continue; // Skip unused strategies

        report += StringFormat("%s:\n", m_performance[i].name);
        report += StringFormat("  Status: %s | Weight: %.2f\n",
                              m_performance[i].is_enabled ? "ENABLED" : "DISABLED", m_performance[i].weight);
        report += StringFormat("  Trades: %d (%d wins, %d losses)\n",
                              m_performance[i].successful_trades + m_performance[i].failed_trades,
                              m_performance[i].successful_trades, m_performance[i].failed_trades);
        report += StringFormat("  Win Rate: %.1f%% | Profit Factor: %.2f\n",
                              m_performance[i].win_rate, m_performance[i].profit_factor);
        report += StringFormat("  Total P&L: %.2f | Avg per Trade: %.2f\n",
                              m_performance[i].total_profit - m_performance[i].total_loss, m_performance[i].avg_profit_per_trade);
        report += "\n";
    }

    // Add combined statistics if using combination
    if(m_use_signal_combination)
    {
        report += "COMBINED SIGNALS:\n";
        report += StringFormat("  Total Signals: %d\n", m_total_combined_signals);
        report += StringFormat("  Successful Trades: %d\n", m_successful_combined_trades);
        report += StringFormat("  Total Profit: %.2f\n", m_total_combined_profit);
        if(m_total_combined_signals > 0)
        {
            double combined_win_rate = (double)m_successful_combined_trades / m_total_combined_signals * 100.0;
            report += StringFormat("  Combined Win Rate: %.1f%%\n", combined_win_rate);
        }
    }

    return report;
}

//+------------------------------------------------------------------+
//| Get Combined Signal Info                                        |
//+------------------------------------------------------------------+
string CStrategyManager::GetCombinedSignalInfo(const SCombinedSignal& signal)
{
    if(!signal.is_valid)
        return "No valid combined signal";

    string info = StringFormat("COMBINED SIGNAL: %s | Strength: %.2f\n",
                              signal.is_long ? "LONG" : "SHORT", signal.combined_strength);
    info += StringFormat("Entry: %.5f | SL: %.5f | TP: %.5f\n",
                        signal.entry_price, signal.stop_loss, signal.take_profit);
    info += StringFormat("Contributing Strategies (%d): %s\n",
                        signal.strategy_count, signal.contributing_strategies);
    info += StringFormat("Primary Strategy: %s", GetStrategyName(signal.primary_strategy));

    return info;
}

//+------------------------------------------------------------------+
//| Update All Strategies                                           |
//+------------------------------------------------------------------+
bool CStrategyManager::UpdateAllStrategies()
{
    bool success = true;

    // Update Admiral strategy
    if(m_admiral_strategy != NULL && IsStrategyEnabled(STRATEGY_ADMIRAL))
    {
        if(!m_admiral_strategy.UpdateSignals())
        {
            Print("StrategyManager: Failed to update Admiral strategy");
            success = false;
        }
    }

    // Update Trend Following strategy
    if(m_trend_following_strategy != NULL && IsStrategyEnabled(STRATEGY_TREND_FOLLOWING))
    {
        if(!m_trend_following_strategy.UpdateSignals())
        {
            Print("StrategyManager: Failed to update Trend Following strategy - continuing with other strategies");
            // Don't fail completely, just log the issue and continue
            // success = false; // Commented out to allow other strategies to work
        }
    }

    // TODO: Add other strategy updates here when implemented

    m_last_update_time = TimeCurrent();
    return success;
}

//+------------------------------------------------------------------+
//| Print Strategy Statistics                                       |
//+------------------------------------------------------------------+
void CStrategyManager::PrintStrategyStatistics()
{
    Print(GetPerformanceReport());
}

//+------------------------------------------------------------------+
//| Initialize Performance Tracking                                |
//+------------------------------------------------------------------+
void CStrategyManager::InitializePerformanceTracking()
{
    // Initialize strategy names (all disabled by default - will be enabled by EnableStrategy calls)
    m_performance[STRATEGY_ADMIRAL].name = "Admiral Pivot Points";
    m_performance[STRATEGY_ADMIRAL].is_enabled = false;

    m_performance[STRATEGY_TREND_FOLLOWING].name = "Trend Following";
    m_performance[STRATEGY_TREND_FOLLOWING].is_enabled = false;

    m_performance[STRATEGY_BREAKOUT].name = "Breakout Strategy";
    m_performance[STRATEGY_BREAKOUT].is_enabled = false;

    m_performance[STRATEGY_MEAN_REVERSION].name = "Mean Reversion Strategy";
    m_performance[STRATEGY_MEAN_REVERSION].is_enabled = false;

    m_performance[STRATEGY_MOMENTUM].name = "Momentum Strategy";
    m_performance[STRATEGY_MOMENTUM].is_enabled = false;

    // Reset all performance metrics
    for(int i = 0; i < STRATEGY_COUNT; i++)
    {
        m_performance[i].total_signals = 0;
        m_performance[i].successful_trades = 0;
        m_performance[i].failed_trades = 0;
        m_performance[i].total_profit = 0.0;
        m_performance[i].total_loss = 0.0;
        m_performance[i].win_rate = 0.0;
        m_performance[i].profit_factor = 0.0;
        m_performance[i].avg_profit_per_trade = 0.0;
        m_performance[i].last_signal_time = 0;
    }
}

//+------------------------------------------------------------------+
//| Initialize Default Weights                                     |
//+------------------------------------------------------------------+
void CStrategyManager::InitializeDefaultWeights()
{
    // Set default weights
    m_strategy_weights[STRATEGY_ADMIRAL] = 1.0;        // Primary strategy
    m_strategy_weights[STRATEGY_TREND_FOLLOWING] = 0.9; // High priority
    m_strategy_weights[STRATEGY_BREAKOUT] = 0.8;       // Secondary
    m_strategy_weights[STRATEGY_MEAN_REVERSION] = 0.6; // Tertiary
    m_strategy_weights[STRATEGY_MOMENTUM] = 0.7;       // Secondary

    // Update performance structure weights
    for(int i = 0; i < STRATEGY_COUNT; i++)
    {
        m_performance[i].weight = m_strategy_weights[i];
    }
}

//+------------------------------------------------------------------+
//| Combine Signals from Multiple Strategies                       |
//+------------------------------------------------------------------+
SCombinedSignal CStrategyManager::CombineSignals()
{
    SCombinedSignal combined_signal;

    // Collect signals from all enabled strategies
    SAdmiralSignal admiral_signal;
    SStrategySignal trend_signal;

    bool admiral_valid = false;
    bool trend_valid = false;

    // Get Admiral signal
    if(m_admiral_strategy != NULL && IsStrategyEnabled(STRATEGY_ADMIRAL))
    {
        admiral_signal = m_admiral_strategy.CheckEntrySignal();
        admiral_valid = admiral_signal.is_valid;
    }

    // Get Trend Following signal
    if(m_trend_following_strategy != NULL && IsStrategyEnabled(STRATEGY_TREND_FOLLOWING))
    {
        trend_signal = m_trend_following_strategy.CheckEntrySignal();
        trend_valid = trend_signal.is_valid;
    }

    // Combine signals based on availability and consensus requirements
    if(admiral_valid && trend_valid)
    {
        // Both strategies have signals - check for consensus
        if(admiral_signal.is_long == trend_signal.is_long)
        {
            // Consensus found - combine signals
            combined_signal.is_valid = true;
            combined_signal.is_long = admiral_signal.is_long;

            // Use weighted average for entry price
            double admiral_weight = m_strategy_weights[STRATEGY_ADMIRAL];
            double trend_weight = m_strategy_weights[STRATEGY_TREND_FOLLOWING];
            double total_weight = admiral_weight + trend_weight;

            combined_signal.entry_price = (admiral_signal.entry_price * admiral_weight + trend_signal.entry_price * trend_weight) / total_weight;

            // Use more conservative stop loss (further from entry)
            if(combined_signal.is_long)
                combined_signal.stop_loss = MathMin(admiral_signal.stop_loss, trend_signal.stop_loss);
            else
                combined_signal.stop_loss = MathMax(admiral_signal.stop_loss, trend_signal.stop_loss);

            // Use more aggressive take profit (closer to entry) or weighted average
            combined_signal.take_profit = (admiral_signal.take_profit * admiral_weight + trend_signal.take_profit * trend_weight) / total_weight;

            // Combine signal strengths
            combined_signal.combined_strength = (admiral_signal.signal_strength * admiral_weight + trend_signal.signal_strength * trend_weight) / total_weight;

            combined_signal.contributing_strategies = "Admiral+TrendFollowing";
            combined_signal.strategy_count = 2;
            combined_signal.primary_strategy = admiral_signal.signal_strength > trend_signal.signal_strength ? STRATEGY_ADMIRAL : STRATEGY_TREND_FOLLOWING;

            // Update signal counts
            m_performance[STRATEGY_ADMIRAL].total_signals++;
            m_performance[STRATEGY_ADMIRAL].last_signal_time = TimeCurrent();
            m_performance[STRATEGY_TREND_FOLLOWING].total_signals++;
            m_performance[STRATEGY_TREND_FOLLOWING].last_signal_time = TimeCurrent();
        }
        else if(!m_require_consensus)
        {
            // No consensus but consensus not required - use stronger signal
            if(admiral_signal.signal_strength > trend_signal.signal_strength)
            {
                // Use Admiral signal
                combined_signal.is_valid = true;
                combined_signal.is_long = admiral_signal.is_long;
                combined_signal.entry_price = admiral_signal.entry_price;
                combined_signal.stop_loss = admiral_signal.stop_loss;
                combined_signal.take_profit = admiral_signal.take_profit;
                combined_signal.combined_strength = admiral_signal.signal_strength * m_strategy_weights[STRATEGY_ADMIRAL];
                combined_signal.contributing_strategies = "Admiral";
                combined_signal.strategy_count = 1;
                combined_signal.primary_strategy = STRATEGY_ADMIRAL;

                m_performance[STRATEGY_ADMIRAL].total_signals++;
                m_performance[STRATEGY_ADMIRAL].last_signal_time = TimeCurrent();
            }
            else
            {
                // Use Trend Following signal
                combined_signal.is_valid = true;
                combined_signal.is_long = trend_signal.is_long;
                combined_signal.entry_price = trend_signal.entry_price;
                combined_signal.stop_loss = trend_signal.stop_loss;
                combined_signal.take_profit = trend_signal.take_profit;
                combined_signal.combined_strength = trend_signal.signal_strength * m_strategy_weights[STRATEGY_TREND_FOLLOWING];
                combined_signal.contributing_strategies = "TrendFollowing";
                combined_signal.strategy_count = 1;
                combined_signal.primary_strategy = STRATEGY_TREND_FOLLOWING;

                m_performance[STRATEGY_TREND_FOLLOWING].total_signals++;
                m_performance[STRATEGY_TREND_FOLLOWING].last_signal_time = TimeCurrent();
            }
        }
    }
    else if(admiral_valid && !m_require_consensus)
    {
        // Only Admiral signal available
        combined_signal.is_valid = true;
        combined_signal.is_long = admiral_signal.is_long;
        combined_signal.entry_price = admiral_signal.entry_price;
        combined_signal.stop_loss = admiral_signal.stop_loss;
        combined_signal.take_profit = admiral_signal.take_profit;
        combined_signal.combined_strength = admiral_signal.signal_strength * m_strategy_weights[STRATEGY_ADMIRAL];
        combined_signal.contributing_strategies = "Admiral";
        combined_signal.strategy_count = 1;
        combined_signal.primary_strategy = STRATEGY_ADMIRAL;

        m_performance[STRATEGY_ADMIRAL].total_signals++;
        m_performance[STRATEGY_ADMIRAL].last_signal_time = TimeCurrent();
    }
    else if(trend_valid && !m_require_consensus)
    {
        // Only Trend Following signal available
        combined_signal.is_valid = true;
        combined_signal.is_long = trend_signal.is_long;
        combined_signal.entry_price = trend_signal.entry_price;
        combined_signal.stop_loss = trend_signal.stop_loss;
        combined_signal.take_profit = trend_signal.take_profit;
        combined_signal.combined_strength = trend_signal.signal_strength * m_strategy_weights[STRATEGY_TREND_FOLLOWING];
        combined_signal.contributing_strategies = "TrendFollowing";
        combined_signal.strategy_count = 1;
        combined_signal.primary_strategy = STRATEGY_TREND_FOLLOWING;

        m_performance[STRATEGY_TREND_FOLLOWING].total_signals++;
        m_performance[STRATEGY_TREND_FOLLOWING].last_signal_time = TimeCurrent();
    }

    // TODO: Add logic for combining multiple strategy signals when other strategies are implemented
    // This would include:
    // 1. Collecting signals from all enabled strategies
    // 2. Checking for consensus if required
    // 3. Weighting signals based on strategy weights
    // 4. Calculating combined strength
    // 5. Determining optimal entry, SL, and TP levels

    return combined_signal;
}

//+------------------------------------------------------------------+
//| Calculate Combined Signal Strength                             |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateCombinedStrength(const SAdmiralSignal& admiral_signal)
{
    // For now, just apply Admiral strategy weight
    double combined_strength = admiral_signal.signal_strength * m_strategy_weights[STRATEGY_ADMIRAL];

    // TODO: When other strategies are added, this will combine strengths from multiple sources
    // Formula could be: weighted_average or maximum or consensus-based

    return MathMin(1.0, combined_strength); // Cap at 1.0
}

//+------------------------------------------------------------------+
//| Validate Combined Signal                                        |
//+------------------------------------------------------------------+
bool CStrategyManager::ValidateCombinedSignal(const SCombinedSignal& signal)
{
    // Check minimum strength requirement
    if(signal.combined_strength < m_min_combined_strength)
    {
        Print("StrategyManager: Combined signal strength too low: ", signal.combined_strength);
        return false;
    }

    // Check consensus requirement
    if(m_require_consensus && signal.strategy_count < m_min_consensus_count)
    {
        Print("StrategyManager: Insufficient consensus: ", signal.strategy_count, " < ", m_min_consensus_count);
        return false;
    }

    // Validate price levels
    if(signal.entry_price <= 0 || signal.stop_loss <= 0 || signal.take_profit <= 0)
    {
        Print("StrategyManager: Invalid price levels in combined signal");
        return false;
    }

    // Validate SL and TP distances
    double sl_distance = MathAbs(signal.entry_price - signal.stop_loss);
    double tp_distance = MathAbs(signal.take_profit - signal.entry_price);

    if(sl_distance <= 0 || tp_distance <= 0)
    {
        Print("StrategyManager: Invalid SL/TP distances");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Update Combined Statistics                                      |
//+------------------------------------------------------------------+
void CStrategyManager::UpdateCombinedStatistics(bool trade_success, double profit)
{
    m_total_combined_signals++;

    if(trade_success)
    {
        m_successful_combined_trades++;
    }

    m_total_combined_profit += profit;
}
