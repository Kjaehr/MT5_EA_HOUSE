//+------------------------------------------------------------------+
//|                                                ConfigManager.mqh |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Configuration structure for trading parameters                   |
//+------------------------------------------------------------------+
struct STradingConfig
{
    // Basic trading parameters
    double            lot_size;
    int               stop_loss;
    int               take_profit;
    int               magic_number;

    // Time parameters
    int               start_hour;
    int               end_hour;
    int               start_delay_minutes;

    // Risk management
    int               max_daily_trades;
    double            max_daily_loss;
    double            risk_per_trade;
    int               max_consec_loss;
    double            max_daily_loss_percent;
    int               minutes_between_trades;
    double            max_spread_points;

    // Strategy parameters
    bool              use_breakout_strategy;
    bool              use_both_strategies;
    bool              use_scalping_mode;

    // Indicator parameters
    int               rsi_period;
    int               ma_fast;
    int               ma_slow;
    int               breakout_bars;
    double            retest_buffer;
    double            range_multiplier;
    double            min_range_quality;
};

//+------------------------------------------------------------------+
//| Configuration Manager class                                      |
//+------------------------------------------------------------------+
class CConfigManager
{
private:
    STradingConfig    m_config;           // Current configuration
    string            m_config_file;      // Configuration file name
    bool              m_is_loaded;        // Configuration loaded flag

    //--- Internal methods
    bool              LoadFromFile();
    bool              SaveToFile();
    void              SetDefaults();
    bool              ValidateConfig();

public:
    //--- Constructor/Destructor
                      CConfigManager(string config_file = "ea_config.txt");
                     ~CConfigManager();

    //--- Configuration access methods
    STradingConfig    GetConfig() { return m_config; }
    bool              IsLoaded() { return m_is_loaded; }

    //--- Individual parameter getters
    double            GetLotSize() { return m_config.lot_size; }
    int               GetStopLoss() { return m_config.stop_loss; }
    int               GetTakeProfit() { return m_config.take_profit; }
    int               GetMagicNumber() { return m_config.magic_number; }
    int               GetStartHour() { return m_config.start_hour; }
    int               GetEndHour() { return m_config.end_hour; }
    int               GetMaxDailyTrades() { return m_config.max_daily_trades; }
    double            GetMaxDailyLoss() { return m_config.max_daily_loss; }
    double            GetRiskPerTrade() { return m_config.risk_per_trade; }
    int               GetMaxConsecLoss() { return m_config.max_consec_loss; }
    bool              GetUseBreakoutStrategy() { return m_config.use_breakout_strategy; }
    bool              GetUseBothStrategies() { return m_config.use_both_strategies; }
    bool              GetUseScalpingMode() { return m_config.use_scalping_mode; }
    int               GetRSIPeriod() { return m_config.rsi_period; }
    int               GetMAFast() { return m_config.ma_fast; }
    int               GetMASlow() { return m_config.ma_slow; }
    int               GetBreakoutBars() { return m_config.breakout_bars; }
    double            GetRetestBuffer() { return m_config.retest_buffer; }
    double            GetRangeMultiplier() { return m_config.range_multiplier; }
    double            GetMinRangeQuality() { return m_config.min_range_quality; }
    double            GetMaxSpreadPoints() { return m_config.max_spread_points; }
    double            GetMaxDailyLossPercent() { return m_config.max_daily_loss_percent; }
    int               GetMinutesBetweenTrades() { return m_config.minutes_between_trades; }

    //--- Individual parameter setters
    void              SetLotSize(double value) { m_config.lot_size = value; }
    void              SetStopLoss(int value) { m_config.stop_loss = value; }
    void              SetTakeProfit(int value) { m_config.take_profit = value; }
    void              SetMagicNumber(int value) { m_config.magic_number = value; }
    void              SetRiskPerTrade(double value) { m_config.risk_per_trade = value; }
    void              SetMaxDailyTrades(int value) { m_config.max_daily_trades = value; }
    void              SetMaxDailyLoss(double value) { m_config.max_daily_loss = value; }

    //--- Configuration management
    bool              LoadConfiguration();
    bool              SaveConfiguration();
    void              ResetToDefaults();
    bool              UpdateFromInputs(double lot_size, int stop_loss, int take_profit, int magic_number,
                                      int start_hour, int end_hour, int max_daily_trades, double max_daily_loss,
                                      bool use_breakout, bool use_both, bool use_scalping,
                                      int rsi_period, int ma_fast, int ma_slow, int breakout_bars,
                                      double retest_buffer, double range_multiplier, double min_range_quality,
                                      double risk_per_trade, int max_consec_loss, double max_daily_loss_percent,
                                      int minutes_between_trades, double max_spread_points, int start_delay_minutes);

    //--- Utility methods
    string            ConfigToString();
    void              PrintConfiguration();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CConfigManager::CConfigManager(string config_file)
{
    m_config_file = config_file;
    m_is_loaded = false;
    SetDefaults();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CConfigManager::~CConfigManager()
{
    // Cleanup if needed
}

//+------------------------------------------------------------------+
//| Set default configuration values                                 |
//+------------------------------------------------------------------+
void CConfigManager::SetDefaults()
{
    m_config.lot_size = 0.1;
    m_config.stop_loss = 30;
    m_config.take_profit = 60;
    m_config.magic_number = 789123;
    m_config.start_hour = 8;
    m_config.end_hour = 12;
    m_config.start_delay_minutes = 15;
    m_config.max_daily_trades = 15;
    m_config.max_daily_loss = 250.0;
    m_config.risk_per_trade = 0.005;
    m_config.max_consec_loss = 3;
    m_config.max_daily_loss_percent = 0.02;
    m_config.minutes_between_trades = 10;
    m_config.max_spread_points = 50.0;
    m_config.use_breakout_strategy = true;
    m_config.use_both_strategies = false;
    m_config.use_scalping_mode = false;
    m_config.rsi_period = 9;
    m_config.ma_fast = 5;
    m_config.ma_slow = 13;
    m_config.breakout_bars = 4;
    m_config.retest_buffer = 2.0;
    m_config.range_multiplier = 1.25;
    m_config.min_range_quality = 0.33;
}

//+------------------------------------------------------------------+
//| Load configuration from file                                     |
//+------------------------------------------------------------------+
bool CConfigManager::LoadFromFile()
{
    // For now, return false - file loading will be implemented later
    return false;
}

//+------------------------------------------------------------------+
//| Save configuration to file                                       |
//+------------------------------------------------------------------+
bool CConfigManager::SaveToFile()
{
    // For now, return false - file saving will be implemented later
    return false;
}

//+------------------------------------------------------------------+
//| Validate configuration values                                    |
//+------------------------------------------------------------------+
bool CConfigManager::ValidateConfig()
{
    if(m_config.lot_size <= 0) return false;
    if(m_config.stop_loss <= 0) return false;
    if(m_config.take_profit <= 0) return false;
    if(m_config.magic_number <= 0) return false;
    if(m_config.start_hour < 0 || m_config.start_hour > 23) return false;
    if(m_config.end_hour < 0 || m_config.end_hour > 23) return false;
    if(m_config.max_daily_trades <= 0) return false;
    if(m_config.max_daily_loss <= 0) return false;
    if(m_config.risk_per_trade <= 0 || m_config.risk_per_trade > 0.1) return false;
    if(m_config.max_consec_loss <= 0) return false;
    if(m_config.rsi_period <= 0) return false;
    if(m_config.ma_fast <= 0) return false;
    if(m_config.ma_slow <= 0) return false;
    if(m_config.breakout_bars <= 0) return false;

    return true;
}

//+------------------------------------------------------------------+
//| Load configuration (public method)                               |
//+------------------------------------------------------------------+
bool CConfigManager::LoadConfiguration()
{
    m_is_loaded = LoadFromFile();
    if(!m_is_loaded)
    {
        SetDefaults();
        m_is_loaded = true;
    }
    return ValidateConfig();
}

//+------------------------------------------------------------------+
//| Save configuration (public method)                               |
//+------------------------------------------------------------------+
bool CConfigManager::SaveConfiguration()
{
    if(!ValidateConfig()) return false;
    return SaveToFile();
}

//+------------------------------------------------------------------+
//| Reset to default values                                          |
//+------------------------------------------------------------------+
void CConfigManager::ResetToDefaults()
{
    SetDefaults();
    m_is_loaded = true;
}

//+------------------------------------------------------------------+
//| Update configuration from input parameters                       |
//+------------------------------------------------------------------+
bool CConfigManager::UpdateFromInputs(double lot_size, int stop_loss, int take_profit, int magic_number,
                                      int start_hour, int end_hour, int max_daily_trades, double max_daily_loss,
                                      bool use_breakout, bool use_both, bool use_scalping,
                                      int rsi_period, int ma_fast, int ma_slow, int breakout_bars,
                                      double retest_buffer, double range_multiplier, double min_range_quality,
                                      double risk_per_trade, int max_consec_loss, double max_daily_loss_percent,
                                      int minutes_between_trades, double max_spread_points, int start_delay_minutes)
{
    m_config.lot_size = lot_size;
    m_config.stop_loss = stop_loss;
    m_config.take_profit = take_profit;
    m_config.magic_number = magic_number;
    m_config.start_hour = start_hour;
    m_config.end_hour = end_hour;
    m_config.start_delay_minutes = start_delay_minutes;
    m_config.max_daily_trades = max_daily_trades;
    m_config.max_daily_loss = max_daily_loss;
    m_config.risk_per_trade = risk_per_trade;
    m_config.max_consec_loss = max_consec_loss;
    m_config.max_daily_loss_percent = max_daily_loss_percent;
    m_config.minutes_between_trades = minutes_between_trades;
    m_config.max_spread_points = max_spread_points;
    m_config.use_breakout_strategy = use_breakout;
    m_config.use_both_strategies = use_both;
    m_config.use_scalping_mode = use_scalping;
    m_config.rsi_period = rsi_period;
    m_config.ma_fast = ma_fast;
    m_config.ma_slow = ma_slow;
    m_config.breakout_bars = breakout_bars;
    m_config.retest_buffer = retest_buffer;
    m_config.range_multiplier = range_multiplier;
    m_config.min_range_quality = min_range_quality;

    m_is_loaded = true;
    return ValidateConfig();
}

//+------------------------------------------------------------------+
//| Convert configuration to string                                  |
//+------------------------------------------------------------------+
string CConfigManager::ConfigToString()
{
    return StringFormat("Config: LotSize=%.2f SL=%d TP=%d Magic=%d StartHour=%d EndHour=%d MaxTrades=%d MaxLoss=%.2f Risk=%.3f",
                       m_config.lot_size, m_config.stop_loss, m_config.take_profit, m_config.magic_number,
                       m_config.start_hour, m_config.end_hour, m_config.max_daily_trades, m_config.max_daily_loss,
                       m_config.risk_per_trade);
}

//+------------------------------------------------------------------+
//| Print configuration to log                                       |
//+------------------------------------------------------------------+
void CConfigManager::PrintConfiguration()
{
    Print("=== EA CONFIGURATION ===");
    Print("Lot Size: ", m_config.lot_size);
    Print("Stop Loss: ", m_config.stop_loss);
    Print("Take Profit: ", m_config.take_profit);
    Print("Magic Number: ", m_config.magic_number);
    Print("Trading Hours: ", m_config.start_hour, " - ", m_config.end_hour);
    Print("Max Daily Trades: ", m_config.max_daily_trades);
    Print("Max Daily Loss: ", m_config.max_daily_loss);
    Print("Risk Per Trade: ", m_config.risk_per_trade);
    Print("Max Consecutive Losses: ", m_config.max_consec_loss);
    Print("Use Breakout Strategy: ", m_config.use_breakout_strategy);
    Print("Use Both Strategies: ", m_config.use_both_strategies);
    Print("Use Scalping Mode: ", m_config.use_scalping_mode);
    Print("RSI Period: ", m_config.rsi_period);
    Print("MA Fast: ", m_config.ma_fast);
    Print("MA Slow: ", m_config.ma_slow);
    Print("Breakout Bars: ", m_config.breakout_bars);
    Print("========================");
}