//+------------------------------------------------------------------+
//|                                                 StrategyBase.mqh |
//|                           Base Class for All Trading Strategies  |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

#include "SignalStructures.mqh"
#include "TradingRegimeManager.mqh"

//+------------------------------------------------------------------+
//| Strategy Signal Structure (Compatible with SAdmiralSignal)      |
//+------------------------------------------------------------------+
struct SStrategySignal
{
    bool              is_valid;
    bool              is_long;
    double            entry_price;
    double            stop_loss;
    double            take_profit;
    double            signal_strength;
    string            signal_description;
    double            confidence;          // Additional confidence metric (0.0-1.0)
    string            strategy_name;       // Name of strategy that generated signal
    datetime          signal_time;         // When signal was generated
    
    // Default constructor
    SStrategySignal()
    {
        is_valid = false;
        is_long = false;
        entry_price = 0.0;
        stop_loss = 0.0;
        take_profit = 0.0;
        signal_strength = 0.0;
        signal_description = "";
        confidence = 0.0;
        strategy_name = "";
        signal_time = 0;
    }
    
    // Copy constructor
    SStrategySignal(const SStrategySignal& other)
    {
        is_valid = other.is_valid;
        is_long = other.is_long;
        entry_price = other.entry_price;
        stop_loss = other.stop_loss;
        take_profit = other.take_profit;
        signal_strength = other.signal_strength;
        signal_description = other.signal_description;
        confidence = other.confidence;
        strategy_name = other.strategy_name;
        signal_time = other.signal_time;
    }
    
    // Assignment operator
    void operator=(const SStrategySignal& other)
    {
        is_valid = other.is_valid;
        is_long = other.is_long;
        entry_price = other.entry_price;
        stop_loss = other.stop_loss;
        take_profit = other.take_profit;
        signal_strength = other.signal_strength;
        signal_description = other.signal_description;
        confidence = other.confidence;
        strategy_name = other.strategy_name;
        signal_time = other.signal_time;
    }
    
    // Convert to SAdmiralSignal for compatibility
    SAdmiralSignal ToAdmiralSignal()
    {
        SAdmiralSignal admiral_signal;
        admiral_signal.is_valid = is_valid;
        admiral_signal.is_long = is_long;
        admiral_signal.entry_price = entry_price;
        admiral_signal.stop_loss = stop_loss;
        admiral_signal.take_profit = take_profit;
        admiral_signal.signal_strength = signal_strength;
        admiral_signal.signal_description = signal_description + " [" + strategy_name + "]";
        return admiral_signal;
    }
};

//+------------------------------------------------------------------+
//| Strategy Performance Statistics                                 |
//+------------------------------------------------------------------+
struct SStrategyStats
{
    int               total_signals;
    int               successful_trades;
    int               failed_trades;
    double            total_profit;
    double            total_loss;
    double            win_rate;
    double            profit_factor;
    double            avg_profit_per_trade;
    double            max_drawdown;
    double            current_drawdown;
    datetime          last_signal_time;
    datetime          last_trade_time;
    
    // Constructor
    SStrategyStats()
    {
        total_signals = 0;
        successful_trades = 0;
        failed_trades = 0;
        total_profit = 0.0;
        total_loss = 0.0;
        win_rate = 0.0;
        profit_factor = 0.0;
        avg_profit_per_trade = 0.0;
        max_drawdown = 0.0;
        current_drawdown = 0.0;
        last_signal_time = 0;
        last_trade_time = 0;
    }
    
    // Copy constructor
    SStrategyStats(const SStrategyStats& other)
    {
        total_signals = other.total_signals;
        successful_trades = other.successful_trades;
        failed_trades = other.failed_trades;
        total_profit = other.total_profit;
        total_loss = other.total_loss;
        win_rate = other.win_rate;
        profit_factor = other.profit_factor;
        avg_profit_per_trade = other.avg_profit_per_trade;
        max_drawdown = other.max_drawdown;
        current_drawdown = other.current_drawdown;
        last_signal_time = other.last_signal_time;
        last_trade_time = other.last_trade_time;
    }
    
    // Assignment operator
    void operator=(const SStrategyStats& other)
    {
        total_signals = other.total_signals;
        successful_trades = other.successful_trades;
        failed_trades = other.failed_trades;
        total_profit = other.total_profit;
        total_loss = other.total_loss;
        win_rate = other.win_rate;
        profit_factor = other.profit_factor;
        avg_profit_per_trade = other.avg_profit_per_trade;
        max_drawdown = other.max_drawdown;
        current_drawdown = other.current_drawdown;
        last_signal_time = other.last_signal_time;
        last_trade_time = other.last_trade_time;
    }
};

//+------------------------------------------------------------------+
//| Strategy Risk Management Parameters                             |
//+------------------------------------------------------------------+
struct SStrategyRiskParams
{
    double            min_signal_strength;     // Minimum signal strength to trade
    double            max_risk_per_trade;      // Maximum risk per trade (%)
    double            stop_loss_buffer_pips;   // Additional SL buffer in pips
    double            take_profit_ratio;       // TP/SL ratio
    bool              use_dynamic_stops;       // Use dynamic stop management
    bool              use_trailing_stops;      // Use trailing stops
    double            trailing_start_ratio;    // When to start trailing (R multiple)
    double            trailing_step_pips;      // Trailing step in pips
    int               max_trades_per_day;      // Maximum trades per day for this strategy
    bool              allow_weekend_trading;   // Allow trading on weekends
    
    // Constructor
    SStrategyRiskParams()
    {
        min_signal_strength = 0.7;
        max_risk_per_trade = 1.0;
        stop_loss_buffer_pips = 5.0;
        take_profit_ratio = 2.0;
        use_dynamic_stops = true;
        use_trailing_stops = false;
        trailing_start_ratio = 1.0;
        trailing_step_pips = 5.0;
        max_trades_per_day = 3;
        allow_weekend_trading = false;
    }
    
    // Copy constructor
    SStrategyRiskParams(const SStrategyRiskParams& other)
    {
        min_signal_strength = other.min_signal_strength;
        max_risk_per_trade = other.max_risk_per_trade;
        stop_loss_buffer_pips = other.stop_loss_buffer_pips;
        take_profit_ratio = other.take_profit_ratio;
        use_dynamic_stops = other.use_dynamic_stops;
        use_trailing_stops = other.use_trailing_stops;
        trailing_start_ratio = other.trailing_start_ratio;
        trailing_step_pips = other.trailing_step_pips;
        max_trades_per_day = other.max_trades_per_day;
        allow_weekend_trading = other.allow_weekend_trading;
    }
    
    // Assignment operator
    void operator=(const SStrategyRiskParams& other)
    {
        min_signal_strength = other.min_signal_strength;
        max_risk_per_trade = other.max_risk_per_trade;
        stop_loss_buffer_pips = other.stop_loss_buffer_pips;
        take_profit_ratio = other.take_profit_ratio;
        use_dynamic_stops = other.use_dynamic_stops;
        use_trailing_stops = other.use_trailing_stops;
        trailing_start_ratio = other.trailing_start_ratio;
        trailing_step_pips = other.trailing_step_pips;
        max_trades_per_day = other.max_trades_per_day;
        allow_weekend_trading = other.allow_weekend_trading;
    }
};

//+------------------------------------------------------------------+
//| Base Strategy Class - Interface for All Strategies             |
//+------------------------------------------------------------------+
class CStrategyBase
{
protected:
    // Core properties
    string            m_name;                  // Strategy name
    string            m_symbol;                // Trading symbol
    ENUM_TIMEFRAMES   m_timeframe;             // Strategy timeframe
    bool              m_enabled;               // Strategy enabled flag
    bool              m_initialized;           // Initialization status
    double            m_weight;                // Strategy weight for signal combination
    
    // Risk management
    SStrategyRiskParams m_risk_params;         // Individual risk parameters
    
    // Performance tracking
    SStrategyStats    m_stats;                 // Strategy statistics
    
    // Signal data
    SStrategySignal   m_current_signal;        // Current signal
    datetime          m_last_signal_time;      // Last signal generation time
    
    // Daily tracking
    int               m_daily_trades;          // Trades today
    datetime          m_last_daily_reset;      // Last daily reset time
    
    // Regime integration
    CTradingRegimeManager* m_regime_manager;   // Reference to regime manager

public:
    //--- Constructor/Destructor
                      CStrategyBase(string name, string symbol, ENUM_TIMEFRAMES timeframe);
    virtual          ~CStrategyBase();
    
    //--- Core Strategy Interface (must be implemented by derived classes)
    virtual bool      Initialize() = 0;
    virtual void      Deinitialize() {} // Default empty implementation to avoid pure virtual call
    virtual bool      UpdateSignals() = 0;
    virtual SStrategySignal CheckEntrySignal() = 0;
    virtual bool      ShouldExit(bool is_long_position) = 0;
    
    //--- Configuration Methods
    void              Enable() { m_enabled = true; }
    void              Disable() { m_enabled = false; }
    bool              IsEnabled() const { return m_enabled; }
    bool              IsInitialized() const { return m_initialized; }
    
    void              SetWeight(double weight) { m_weight = MathMax(0.0, MathMin(2.0, weight)); }
    double            GetWeight() const { return m_weight; }
    
    //--- Risk Management
    void              SetRiskParams(const SStrategyRiskParams& params) { m_risk_params = params; }
    SStrategyRiskParams GetRiskParams() const { return m_risk_params; }
    
    //--- Performance Tracking
    void              UpdatePerformance(bool trade_success, double profit);
    SStrategyStats    GetStatistics() const { return m_stats; }
    void              ResetStatistics();
    
    //--- Information Methods
    string            GetName() const { return m_name; }
    string            GetSymbol() const { return m_symbol; }
    ENUM_TIMEFRAMES   GetTimeframe() const { return m_timeframe; }
    
    //--- Regime Manager Integration
    void              SetRegimeManager(CTradingRegimeManager* regime_manager) { m_regime_manager = regime_manager; }
    CTradingRegimeManager* GetRegimeManager() const { return m_regime_manager; }
    
    //--- Utility Methods
    virtual string    GetStrategyInfo();
    string            GetPerformanceReport();
    bool              CanTradeToday();
    void              CheckDailyReset();
    void              RegisterTradeExecution(); // Call when a trade is actually executed

protected:
    //--- Internal Methods (can be overridden by derived classes)
    virtual bool      ValidateSignal(const SStrategySignal& signal);
    virtual void      ResetSignal(SStrategySignal& signal);
    virtual double    CalculateStopLoss(bool is_long, double entry_price);
    virtual double    CalculateTakeProfit(bool is_long, double entry_price, double stop_loss);
    virtual bool      ValidateMarketConditions();
    virtual void      UpdateDailyStatistics();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStrategyBase::CStrategyBase(string name, string symbol, ENUM_TIMEFRAMES timeframe)
{
    m_name = name;
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_enabled = true;
    m_initialized = false;
    m_weight = 1.0;

    // Initialize risk parameters with defaults
    m_risk_params = SStrategyRiskParams();

    // Initialize statistics
    m_stats = SStrategyStats();

    // Initialize signal data
    ResetSignal(m_current_signal);
    m_last_signal_time = 0;

    // Initialize daily tracking
    m_daily_trades = 0;
    m_last_daily_reset = 0;

    // Initialize regime manager reference
    m_regime_manager = NULL;

    Print("StrategyBase: Created strategy '", m_name, "' for ", m_symbol, " on ", EnumToString(m_timeframe));
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStrategyBase::~CStrategyBase()
{
    // Don't call virtual functions in destructor to avoid pure virtual function call
    // Derived classes should call their own Deinitialize() in their destructors
    Print("StrategyBase: Destroyed strategy '", m_name, "'");
}

//+------------------------------------------------------------------+
//| Update Performance Statistics                                   |
//+------------------------------------------------------------------+
void CStrategyBase::UpdatePerformance(bool trade_success, double profit)
{
    if(trade_success)
    {
        m_stats.successful_trades++;
        if(profit > 0)
            m_stats.total_profit += profit;
        else
            m_stats.total_loss += MathAbs(profit);
    }
    else
    {
        m_stats.failed_trades++;
        m_stats.total_loss += MathAbs(profit);
    }

    // Update calculated metrics
    int total_trades = m_stats.successful_trades + m_stats.failed_trades;
    if(total_trades > 0)
    {
        m_stats.win_rate = (double)m_stats.successful_trades / total_trades * 100.0;
        m_stats.avg_profit_per_trade = (m_stats.total_profit - m_stats.total_loss) / total_trades;
    }

    // Update profit factor
    if(m_stats.total_loss > 0)
        m_stats.profit_factor = m_stats.total_profit / m_stats.total_loss;
    else
        m_stats.profit_factor = m_stats.total_profit > 0 ? 999.0 : 0.0;

    // Update drawdown (simplified)
    double current_pnl = m_stats.total_profit - m_stats.total_loss;
    if(current_pnl < 0)
    {
        m_stats.current_drawdown = MathAbs(current_pnl);
        if(m_stats.current_drawdown > m_stats.max_drawdown)
            m_stats.max_drawdown = m_stats.current_drawdown;
    }
    else
    {
        m_stats.current_drawdown = 0.0;
    }

    m_stats.last_trade_time = TimeCurrent();

    Print("StrategyBase: Updated performance for '", m_name, "' - Win Rate: ", m_stats.win_rate, "%, PF: ", m_stats.profit_factor);
}

//+------------------------------------------------------------------+
//| Reset Performance Statistics                                    |
//+------------------------------------------------------------------+
void CStrategyBase::ResetStatistics()
{
    m_stats = SStrategyStats();
    m_daily_trades = 0;
    Print("StrategyBase: Reset statistics for '", m_name, "'");
}

//+------------------------------------------------------------------+
//| Get Strategy Information                                        |
//+------------------------------------------------------------------+
string CStrategyBase::GetStrategyInfo()
{
    string info = StringFormat("=== %s Strategy Info ===\n", m_name);
    info += StringFormat("Symbol: %s | Timeframe: %s\n", m_symbol, EnumToString(m_timeframe));
    info += StringFormat("Status: %s | Weight: %.2f\n", m_enabled ? "ENABLED" : "DISABLED", m_weight);
    info += StringFormat("Initialized: %s\n", m_initialized ? "YES" : "NO");

    // Risk parameters
    info += StringFormat("Min Signal Strength: %.2f\n", m_risk_params.min_signal_strength);
    info += StringFormat("Max Risk per Trade: %.1f%%\n", m_risk_params.max_risk_per_trade);
    info += StringFormat("Max Trades per Day: %d\n", m_risk_params.max_trades_per_day);

    // Current signal
    if(m_current_signal.is_valid)
    {
        info += StringFormat("Current Signal: %s | Strength: %.2f\n",
                            m_current_signal.is_long ? "LONG" : "SHORT",
                            m_current_signal.signal_strength);
    }
    else
    {
        info += "Current Signal: None\n";
    }

    return info;
}

//+------------------------------------------------------------------+
//| Get Performance Report                                          |
//+------------------------------------------------------------------+
string CStrategyBase::GetPerformanceReport()
{
    string report = StringFormat("=== %s Performance Report ===\n", m_name);

    int total_trades = m_stats.successful_trades + m_stats.failed_trades;
    report += StringFormat("Total Signals: %d\n", m_stats.total_signals);
    report += StringFormat("Total Trades: %d (%d wins, %d losses)\n",
                          total_trades, m_stats.successful_trades, m_stats.failed_trades);

    if(total_trades > 0)
    {
        report += StringFormat("Win Rate: %.1f%%\n", m_stats.win_rate);
        report += StringFormat("Profit Factor: %.2f\n", m_stats.profit_factor);
        report += StringFormat("Avg Profit per Trade: %.2f\n", m_stats.avg_profit_per_trade);
    }

    report += StringFormat("Total Profit: %.2f\n", m_stats.total_profit);
    report += StringFormat("Total Loss: %.2f\n", m_stats.total_loss);
    report += StringFormat("Net P&L: %.2f\n", m_stats.total_profit - m_stats.total_loss);
    report += StringFormat("Max Drawdown: %.2f\n", m_stats.max_drawdown);
    report += StringFormat("Current Drawdown: %.2f\n", m_stats.current_drawdown);

    if(m_stats.last_signal_time > 0)
        report += StringFormat("Last Signal: %s\n", TimeToString(m_stats.last_signal_time));
    if(m_stats.last_trade_time > 0)
        report += StringFormat("Last Trade: %s\n", TimeToString(m_stats.last_trade_time));

    return report;
}

//+------------------------------------------------------------------+
//| Check if Strategy Can Trade Today                              |
//+------------------------------------------------------------------+
bool CStrategyBase::CanTradeToday()
{
    CheckDailyReset();

    // Check if strategy is enabled
    if(!m_enabled || !m_initialized)
        return false;

    // Check daily trade limit
    if(m_daily_trades >= m_risk_params.max_trades_per_day)
    {
        if(m_daily_trades == m_risk_params.max_trades_per_day) // Only print once
            Print("StrategyBase: Daily trade limit reached for '", m_name, "' (", m_daily_trades, "/", m_risk_params.max_trades_per_day, ")");
        return false;
    }

    // Check weekend trading
    if(!m_risk_params.allow_weekend_trading)
    {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        if(dt.day_of_week == 0 || dt.day_of_week == 6) // Sunday or Saturday
            return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check Daily Reset                                              |
//+------------------------------------------------------------------+
void CStrategyBase::CheckDailyReset()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", dt.year, dt.mon, dt.day));

    if(m_last_daily_reset != today)
    {
        m_daily_trades = 0;
        m_last_daily_reset = today;
        Print("StrategyBase: Daily reset for '", m_name, "'");
    }
}

//+------------------------------------------------------------------+
//| Register Trade Execution                                        |
//+------------------------------------------------------------------+
void CStrategyBase::RegisterTradeExecution()
{
    CheckDailyReset(); // Ensure daily counter is current
    m_daily_trades++;
    Print("StrategyBase: Trade registered for '", m_name, "' (", m_daily_trades, "/", m_risk_params.max_trades_per_day, ")");
}

//+------------------------------------------------------------------+
//| Validate Signal                                                |
//+------------------------------------------------------------------+
bool CStrategyBase::ValidateSignal(const SStrategySignal& signal)
{
    if(!signal.is_valid)
        return false;

    // Check signal strength
    if(signal.signal_strength < m_risk_params.min_signal_strength)
    {
        Print("StrategyBase: Signal strength too low for '", m_name, "': ", signal.signal_strength, " < ", m_risk_params.min_signal_strength);
        return false;
    }

    // Check confidence
    if(signal.confidence < 0.0 || signal.confidence > 1.0)
    {
        Print("StrategyBase: Invalid confidence level for '", m_name, "': ", signal.confidence);
        return false;
    }

    // Check price levels
    if(signal.entry_price <= 0 || signal.stop_loss <= 0 || signal.take_profit <= 0)
    {
        Print("StrategyBase: Invalid price levels for '", m_name, "'");
        return false;
    }

    // Check SL and TP distances
    double sl_distance = MathAbs(signal.entry_price - signal.stop_loss);
    double tp_distance = MathAbs(signal.take_profit - signal.entry_price);

    if(sl_distance <= 0 || tp_distance <= 0)
    {
        Print("StrategyBase: Invalid SL/TP distances for '", m_name, "'");
        return false;
    }

    // Check if regime manager allows trading
    if(m_regime_manager != NULL)
    {
        if(!m_regime_manager.CanOpenNewTrade())
        {
            Print("StrategyBase: Regime manager restricts trading for '", m_name, "'");
            return false;
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Reset Signal Structure                                         |
//+------------------------------------------------------------------+
void CStrategyBase::ResetSignal(SStrategySignal& signal)
{
    signal = SStrategySignal();
    signal.strategy_name = m_name;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss                                            |
//+------------------------------------------------------------------+
double CStrategyBase::CalculateStopLoss(bool is_long, double entry_price)
{
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double pip_size = point * 10; // For most forex pairs, adjust as needed

    // Basic stop loss calculation with buffer
    double buffer = m_risk_params.stop_loss_buffer_pips * pip_size;

    double stop_loss;
    if(is_long)
        stop_loss = entry_price - buffer;
    else
        stop_loss = entry_price + buffer;

    // Use regime manager if available for optimal SL
    if(m_regime_manager != NULL)
    {
        ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
        if(current_regime != REGIME_NONE)
        {
            double regime_sl = m_regime_manager.GetOptimalStopLoss(current_regime, is_long, entry_price);
            if(regime_sl > 0)
                stop_loss = regime_sl;
        }
    }

    return stop_loss;
}

//+------------------------------------------------------------------+
//| Calculate Take Profit                                          |
//+------------------------------------------------------------------+
double CStrategyBase::CalculateTakeProfit(bool is_long, double entry_price, double stop_loss)
{
    double sl_distance = MathAbs(entry_price - stop_loss);
    double tp_distance = sl_distance * m_risk_params.take_profit_ratio;

    double take_profit;
    if(is_long)
        take_profit = entry_price + tp_distance;
    else
        take_profit = entry_price - tp_distance;

    // Use regime manager if available for optimal TP
    if(m_regime_manager != NULL)
    {
        ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
        if(current_regime != REGIME_NONE)
        {
            double regime_tp = m_regime_manager.GetOptimalTakeProfit(current_regime, is_long, entry_price, stop_loss);
            if(regime_tp > 0)
                take_profit = regime_tp;
        }
    }

    return take_profit;
}

//+------------------------------------------------------------------+
//| Validate Market Conditions                                     |
//+------------------------------------------------------------------+
bool CStrategyBase::ValidateMarketConditions()
{
    // Check if market is open
    if(!SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE))
    {
        Print("StrategyBase: Market closed for '", m_symbol, "'");
        return false;
    }

    // Check spread conditions
    double spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double max_spread = 50 * SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10; // 50 pips max spread

    if(spread > max_spread)
    {
        Print("StrategyBase: Spread too high for '", m_name, "': ", spread);
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Update Daily Statistics                                        |
//+------------------------------------------------------------------+
void CStrategyBase::UpdateDailyStatistics()
{
    CheckDailyReset();

    // This method can be overridden by derived classes
    // to implement strategy-specific daily statistics updates
}
