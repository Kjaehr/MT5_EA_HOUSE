//+------------------------------------------------------------------+
//|                                                 StrategyBase.mqh |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"

#include "Logger.mqh"
#include "ConfigManager.mqh"
#include "TradeManager.mqh"

//--- Signal structure
struct SSignal
{
    bool              is_valid;           // Signal validity
    ENUM_ORDER_TYPE   signal_type;       // Signal type (buy/sell)
    double            entry_price;        // Entry price
    double            stop_loss;          // Stop loss price
    double            take_profit;        // Take profit price
    double            confidence;         // Signal confidence (0-1)
    string            reason;             // Signal reason/description
    datetime          signal_time;        // Signal generation time
};

//--- Strategy statistics
struct SStrategyStats
{
    int               total_signals;      // Total signals generated
    int               successful_trades;  // Successful trades
    int               failed_trades;      // Failed trades
    double            total_profit;       // Total profit
    double            total_loss;         // Total loss
    double            win_rate;           // Win rate percentage
    double            profit_factor;      // Profit factor
    double            max_drawdown;       // Maximum drawdown
    datetime          last_signal_time;   // Last signal time
};

//+------------------------------------------------------------------+
//| Base strategy class - interface for all strategies              |
//+------------------------------------------------------------------+
class CStrategyBase
{
protected:
    string            m_name;             // Strategy name
    string            m_symbol;           // Trading symbol
    ENUM_TIMEFRAMES   m_timeframe;        // Strategy timeframe
    CLogger*          m_logger;           // Logger reference
    CConfigManager*   m_config;           // Configuration reference
    CTradeManager*    m_trade_manager;    // Trade manager reference
    SStrategyStats    m_stats;            // Strategy statistics
    bool              m_enabled;          // Strategy enabled flag

    //--- Internal methods
    virtual void      UpdateStatistics(bool trade_success, double profit);
    virtual bool      ValidateMarketConditions();

public:
    //--- Constructor/Destructor
                      CStrategyBase(string name, string symbol, ENUM_TIMEFRAMES timeframe);
    virtual          ~CStrategyBase();

    //--- Configuration methods
    void              SetLogger(CLogger* logger) { m_logger = logger; }
    void              SetConfig(CConfigManager* config) { m_config = config; }
    void              SetTradeManager(CTradeManager* trade_manager) { m_trade_manager = trade_manager; }
    void              Enable() { m_enabled = true; }
    void              Disable() { m_enabled = false; }
    bool              IsEnabled() { return m_enabled; }

    //--- Strategy interface (must be implemented by derived classes)
    virtual bool      Initialize() = 0;
    virtual void      Deinitialize() = 0;
    virtual SSignal   CheckSignal() = 0;
    virtual bool      ShouldExit(SPositionInfo& position) = 0;

    //--- Information methods
    string            GetName() { return m_name; }
    string            GetSymbol() { return m_symbol; }
    ENUM_TIMEFRAMES   GetTimeframe() { return m_timeframe; }
    SStrategyStats    GetStatistics() { return m_stats; }

    //--- Statistics methods
    void              ResetStatistics();
    void              PrintStatistics();
    double            GetWinRate();
    double            GetProfitFactor();

    //--- Utility methods
    virtual string    GetStrategyInfo();
    virtual void      OnTick() {}  // Optional tick processing
    virtual void      OnTimer() {} // Optional timer processing
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStrategyBase::CStrategyBase(string name, string symbol, ENUM_TIMEFRAMES timeframe)
{
    m_name = name;
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_logger = NULL;
    m_config = NULL;
    m_trade_manager = NULL;
    m_enabled = true;

    // Initialize statistics
    ResetStatistics();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStrategyBase::~CStrategyBase()
{
    if(m_logger != NULL)
    {
        m_logger.Info("Strategy " + m_name + " destroyed");
    }
}

//+------------------------------------------------------------------+
//| Reset strategy statistics                                        |
//+------------------------------------------------------------------+
void CStrategyBase::ResetStatistics()
{
    m_stats.total_signals = 0;
    m_stats.successful_trades = 0;
    m_stats.failed_trades = 0;
    m_stats.total_profit = 0.0;
    m_stats.total_loss = 0.0;
    m_stats.win_rate = 0.0;
    m_stats.profit_factor = 0.0;
    m_stats.max_drawdown = 0.0;
    m_stats.last_signal_time = 0;
}

//+------------------------------------------------------------------+
//| Update strategy statistics                                       |
//+------------------------------------------------------------------+
void CStrategyBase::UpdateStatistics(bool trade_success, double profit)
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
    }

    // Calculate win rate
    int total_trades = m_stats.successful_trades + m_stats.failed_trades;
    if(total_trades > 0)
    {
        m_stats.win_rate = (double)m_stats.successful_trades / total_trades * 100.0;
    }

    // Calculate profit factor
    if(m_stats.total_loss > 0)
    {
        m_stats.profit_factor = m_stats.total_profit / m_stats.total_loss;
    }
}

//+------------------------------------------------------------------+
//| Validate market conditions                                       |
//+------------------------------------------------------------------+
bool CStrategyBase::ValidateMarketConditions()
{
    // Basic market validation - can be overridden by derived classes
    double spread_points = 0;
    if(m_trade_manager != NULL)
    {
        spread_points = m_trade_manager.GetSpreadPoints();
    }

    if(m_config != NULL && spread_points > m_config.GetMaxSpreadPoints())
    {
        if(m_logger != NULL)
        {
            m_logger.Warning(StringFormat("Spread too wide: %.1f points (max: %.1f)",
                             spread_points, m_config.GetMaxSpreadPoints()));
        }
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Get win rate                                                     |
//+------------------------------------------------------------------+
double CStrategyBase::GetWinRate()
{
    return m_stats.win_rate;
}

//+------------------------------------------------------------------+
//| Get profit factor                                                |
//+------------------------------------------------------------------+
double CStrategyBase::GetProfitFactor()
{
    return m_stats.profit_factor;
}

//+------------------------------------------------------------------+
//| Print strategy statistics                                        |
//+------------------------------------------------------------------+
void CStrategyBase::PrintStatistics()
{
    if(m_logger != NULL)
    {
        m_logger.Info("=== " + m_name + " STATISTICS ===");
        m_logger.Info("Total Signals: " + IntegerToString(m_stats.total_signals));
        m_logger.Info("Successful Trades: " + IntegerToString(m_stats.successful_trades));
        m_logger.Info("Failed Trades: " + IntegerToString(m_stats.failed_trades));
        m_logger.Info("Win Rate: " + DoubleToString(m_stats.win_rate, 2) + "%");
        m_logger.Info("Profit Factor: " + DoubleToString(m_stats.profit_factor, 2));
        m_logger.Info("Total Profit: " + DoubleToString(m_stats.total_profit, 2));
        m_logger.Info("Total Loss: " + DoubleToString(m_stats.total_loss, 2));
        m_logger.Info("========================");
    }
}

//+------------------------------------------------------------------+
//| Get strategy information                                         |
//+------------------------------------------------------------------+
string CStrategyBase::GetStrategyInfo()
{
    return StringFormat("%s [%s:%s] - Signals:%d WinRate:%.1f%% PF:%.2f",
                       m_name, m_symbol, EnumToString(m_timeframe),
                       m_stats.total_signals, m_stats.win_rate, m_stats.profit_factor);
}