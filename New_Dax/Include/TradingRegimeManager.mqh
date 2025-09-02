//+------------------------------------------------------------------+
//|                                         TradingRegimeManager.mqh |
//|                           Advanced Regime-Based Trading Manager  |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Trading Regime Enumeration                                       |
//+------------------------------------------------------------------+
enum ENUM_TRADING_REGIME
{
    REGIME_NONE = 0,           // No trading
    REGIME_TRENDING = 1,       // Trending regime (09:05-11:00)
    REGIME_RANGING = 2,        // Ranging/Mean reversion (12:00-14:30)
    REGIME_VOLATILE = 3,       // Volatile/US volatility (15:30-17:00)
    REGIME_QUIET = 4           // Quiet market conditions
};

//+------------------------------------------------------------------+
//| Regime Configuration Structure                                   |
//+------------------------------------------------------------------+
struct SRegimeConfig
{
    ENUM_TRADING_REGIME regime_type;
    int start_hour;
    int start_minute;
    int end_hour;
    int end_minute;
    int max_trades;
    double min_signal_strength;
    double max_sl_points;
    double target_r_multiple;
    bool allow_runners;
    string description;

    // Constructor
    SRegimeConfig()
    {
        regime_type = REGIME_NONE;
        start_hour = 0;
        start_minute = 0;
        end_hour = 0;
        end_minute = 0;
        max_trades = 0;
        min_signal_strength = 0.0;
        max_sl_points = 0.0;
        target_r_multiple = 0.0;
        allow_runners = false;
        description = "";
    }

    // Copy constructor
    SRegimeConfig(const SRegimeConfig &other)
    {
        regime_type = other.regime_type;
        start_hour = other.start_hour;
        start_minute = other.start_minute;
        end_hour = other.end_hour;
        end_minute = other.end_minute;
        max_trades = other.max_trades;
        min_signal_strength = other.min_signal_strength;
        max_sl_points = other.max_sl_points;
        target_r_multiple = other.target_r_multiple;
        allow_runners = other.allow_runners;
        description = other.description;
    }
};

//+------------------------------------------------------------------+
//| News Event Configuration Structure                               |
//+------------------------------------------------------------------+
struct SNewsEvent
{
    string name;
    int hour;
    int minute;
    int minutes_before;
    int minutes_after;
    int day_of_week;      // 0=any, 1=Monday, 5=Friday
    int day_of_month_min; // 0=any day
    int day_of_month_max; // 0=any day
    bool is_high_impact;

    // Constructor
    SNewsEvent()
    {
        name = "";
        hour = 0;
        minute = 0;
        minutes_before = 0;
        minutes_after = 0;
        day_of_week = 0;
        day_of_month_min = 0;
        day_of_month_max = 0;
        is_high_impact = false;
    }

    // Copy constructor
    SNewsEvent(const SNewsEvent &other)
    {
        name = other.name;
        hour = other.hour;
        minute = other.minute;
        minutes_before = other.minutes_before;
        minutes_after = other.minutes_after;
        day_of_week = other.day_of_week;
        day_of_month_min = other.day_of_month_min;
        day_of_month_max = other.day_of_month_max;
        is_high_impact = other.is_high_impact;
    }
};

//+------------------------------------------------------------------+
//| Trading Regime Manager Class                                     |
//+------------------------------------------------------------------+
class CTradingRegimeManager
{
private:
    string            m_symbol;
    SRegimeConfig     m_regimes[5]; // Index 0 unused, 1-4 for regimes
    SNewsEvent        m_news_events[10]; // High impact news events
    int               m_news_events_count;
    bool              m_use_news_filter;

    // Current state
    ENUM_TRADING_REGIME m_current_regime;
    datetime          m_last_regime_check;
    
    // Trade counting per regime
    int               m_trend_trades_today;
    int               m_mr_trades_today;
    int               m_us_trades_today;
    datetime          m_last_reset_date;
    
    // ATR for volatility assessment
    int               m_atr_handle;
    double            m_current_atr;
    
    bool              m_initialized;

public:
    //--- Constructor/Destructor
                      CTradingRegimeManager(string symbol);
                     ~CTradingRegimeManager();
    
    //--- Initialization
    bool              Initialize();
    void              Deinitialize();
    
    //--- Main regime methods
    bool              UpdateCurrentRegime();
    ENUM_TRADING_REGIME GetCurrentRegime() const { return m_current_regime; }
    SRegimeConfig     GetCurrentRegimeConfig();
    
    //--- Trade management
    bool              CanOpenNewTrade();
    bool              RegisterNewTrade();
    void              ResetDailyCounters();
    
    //--- Regime-specific validation
    bool              ValidateEntryConditions(ENUM_TRADING_REGIME regime, double entry_price);
    bool              ValidateVolatilityConditions();
    double            GetOptimalStopLoss(ENUM_TRADING_REGIME regime, bool is_long, double entry_price);
    double            GetOptimalTakeProfit(ENUM_TRADING_REGIME regime, bool is_long, double entry_price, double sl_price);
    
    //--- Information methods
    string            GetRegimeDescription() const;
    string            GetTradingStatistics();
    bool              IsNewsTime();
    string            GetNewsStatus() const;
    string            GetUpcomingNewsEvents() const;
    
    //--- Seasonal adjustments
    double            GetSeasonalRiskMultiplier() const;
    double            GetSeasonalTargetMultiplier() const;
    string            GetSeasonalDescription() const;

    //--- Volatility-adaptive sizing
    double            GetVolatilityMultiplier() const;
    double            GetCombinedRiskMultiplier() const;
    string            GetVolatilityDescription() const;

    //--- Advanced trailing stops
    double            GetTrailingStopDistance(ENUM_TRADING_REGIME regime, double profit_r) const;
    double            GetBreakevenThreshold(ENUM_TRADING_REGIME regime) const;
    bool              ShouldActivateTrailing(ENUM_TRADING_REGIME regime, double current_profit_r) const;
    string            GetTrailingStopDescription() const;

    //--- Getters
    double            GetCurrentATR() const { return m_current_atr; }
    int               GetTotalTradesToday() const { return m_trend_trades_today + m_mr_trades_today + m_us_trades_today; }

    //--- News filter control
    void              SetNewsFilter(bool enabled) { m_use_news_filter = enabled; }
    bool              IsNewsFilterEnabled() const { return m_use_news_filter; }
    
private:
    //--- Internal methods
    void              InitializeRegimeConfigs();
    void              InitializeNewsEvents();
    bool              IsHighImpactNewsTime(datetime current_time) const;
    ENUM_TRADING_REGIME DetermineRegimeFromTime(datetime current_time);
    bool              IsWithinRegimeHours(const SRegimeConfig &config, datetime current_time);
    void              CheckDailyReset();
    bool              UpdateATR();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradingRegimeManager::CTradingRegimeManager(string symbol)
{
    m_symbol = symbol;
    m_current_regime = REGIME_NONE;
    m_last_regime_check = 0;
    m_use_news_filter = true; // Default to enabled

    // Initialize trade counters
    m_trend_trades_today = 0;
    m_mr_trades_today = 0;
    m_us_trades_today = 0;
    m_last_reset_date = 0;

    m_atr_handle = INVALID_HANDLE;
    m_current_atr = 0.0;
    m_initialized = false;
    
    // Initialize regime configurations
    InitializeRegimeConfigs();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradingRegimeManager::~CTradingRegimeManager()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize regime manager                                        |
//+------------------------------------------------------------------+
bool CTradingRegimeManager::Initialize()
{
    if(StringLen(m_symbol) == 0)
    {
        Print("TradingRegimeManager: Invalid symbol");
        return false;
    }
    
    // Initialize ATR indicator
    m_atr_handle = iATR(m_symbol, PERIOD_M15, 14);
    if(m_atr_handle == INVALID_HANDLE)
    {
        Print("TradingRegimeManager: Failed to create ATR indicator");
        return false;
    }
    
    // Update initial ATR
    if(!UpdateATR())
    {
        Print("TradingRegimeManager: Failed to get initial ATR");
        return false;
    }
    
    // Initialize regime configurations
    InitializeRegimeConfigs();

    // Initialize news events
    InitializeNewsEvents();

    // Reset daily counters
    ResetDailyCounters();

    m_initialized = true;
    Print("TradingRegimeManager: Initialized successfully for ", m_symbol, " with ", m_news_events_count, " news events");

    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize regime manager                                      |
//+------------------------------------------------------------------+
void CTradingRegimeManager::Deinitialize()
{
    if(m_atr_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_atr_handle);
        m_atr_handle = INVALID_HANDLE;
    }
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Initialize regime configurations                                 |
//+------------------------------------------------------------------+
void CTradingRegimeManager::InitializeRegimeConfigs()
{
    // Trending Regime (09:05-11:00 CET)
    m_regimes[REGIME_TRENDING].regime_type = REGIME_TRENDING;
    m_regimes[REGIME_TRENDING].start_hour = 9;
    m_regimes[REGIME_TRENDING].start_minute = 5;
    m_regimes[REGIME_TRENDING].end_hour = 11;
    m_regimes[REGIME_TRENDING].end_minute = 0;
    m_regimes[REGIME_TRENDING].max_trades = 2;
    m_regimes[REGIME_TRENDING].min_signal_strength = 0.7;
    m_regimes[REGIME_TRENDING].max_sl_points = 25.0;
    m_regimes[REGIME_TRENDING].target_r_multiple = 2.0;
    m_regimes[REGIME_TRENDING].allow_runners = true;
    m_regimes[REGIME_TRENDING].description = "Trend Breakout + Retest";

    // Ranging Regime (12:00-14:30 CET)
    m_regimes[REGIME_RANGING].regime_type = REGIME_RANGING;
    m_regimes[REGIME_RANGING].start_hour = 12;
    m_regimes[REGIME_RANGING].start_minute = 0;
    m_regimes[REGIME_RANGING].end_hour = 14;
    m_regimes[REGIME_RANGING].end_minute = 30;
    m_regimes[REGIME_RANGING].max_trades = 1;
    m_regimes[REGIME_RANGING].min_signal_strength = 0.5;
    m_regimes[REGIME_RANGING].max_sl_points = 18.0;
    m_regimes[REGIME_RANGING].target_r_multiple = 1.2;
    m_regimes[REGIME_RANGING].allow_runners = false;
    m_regimes[REGIME_RANGING].description = "Pivot Zone Rejection";

    // Volatile Regime (15:30-17:00 CET)
    m_regimes[REGIME_VOLATILE].regime_type = REGIME_VOLATILE;
    m_regimes[REGIME_VOLATILE].start_hour = 15;
    m_regimes[REGIME_VOLATILE].start_minute = 30;
    m_regimes[REGIME_VOLATILE].end_hour = 17;
    m_regimes[REGIME_VOLATILE].end_minute = 0;
    m_regimes[REGIME_VOLATILE].max_trades = 2;
    m_regimes[REGIME_VOLATILE].min_signal_strength = 0.6;
    m_regimes[REGIME_VOLATILE].max_sl_points = 20.0;
    m_regimes[REGIME_VOLATILE].target_r_multiple = 1.5;
    m_regimes[REGIME_VOLATILE].allow_runners = false;
    m_regimes[REGIME_VOLATILE].description = "Momentum Bursts + Quick BE";

    // Quiet Regime (17:00-09:05 CET) - Low volatility periods
    m_regimes[REGIME_QUIET].regime_type = REGIME_QUIET;
    m_regimes[REGIME_QUIET].start_hour = 17;
    m_regimes[REGIME_QUIET].start_minute = 0;
    m_regimes[REGIME_QUIET].end_hour = 9;
    m_regimes[REGIME_QUIET].end_minute = 5;
    m_regimes[REGIME_QUIET].max_trades = 1;
    m_regimes[REGIME_QUIET].min_signal_strength = 0.8;
    m_regimes[REGIME_QUIET].max_sl_points = 15.0;
    m_regimes[REGIME_QUIET].target_r_multiple = 1.0;
    m_regimes[REGIME_QUIET].allow_runners = false;
    m_regimes[REGIME_QUIET].description = "Quiet Market Scalping";
}

//+------------------------------------------------------------------+
//| Initialize high impact news events                              |
//+------------------------------------------------------------------+
void CTradingRegimeManager::InitializeNewsEvents()
{
    m_news_events_count = 0;

    // German CPI (Monthly - usually 8th-10th at 08:00 CET)
    m_news_events[m_news_events_count].name = "German CPI";
    m_news_events[m_news_events_count].hour = 8;
    m_news_events[m_news_events_count].minute = 0;
    m_news_events[m_news_events_count].minutes_before = 3;
    m_news_events[m_news_events_count].minutes_after = 5;
    m_news_events[m_news_events_count].day_of_week = 0; // Any day
    m_news_events[m_news_events_count].day_of_month_min = 8;
    m_news_events[m_news_events_count].day_of_month_max = 10;
    m_news_events[m_news_events_count].is_high_impact = true;
    m_news_events_count++;

    // German IFO Business Climate (Monthly - around 25th at 10:00 CET)
    m_news_events[m_news_events_count].name = "German IFO";
    m_news_events[m_news_events_count].hour = 10;
    m_news_events[m_news_events_count].minute = 0;
    m_news_events[m_news_events_count].minutes_before = 3;
    m_news_events[m_news_events_count].minutes_after = 5;
    m_news_events[m_news_events_count].day_of_week = 0; // Any day
    m_news_events[m_news_events_count].day_of_month_min = 24;
    m_news_events[m_news_events_count].day_of_month_max = 26;
    m_news_events[m_news_events_count].is_high_impact = true;
    m_news_events_count++;

    // ECB Interest Rate Decision (8 times per year, usually Thursday 14:15 CET)
    m_news_events[m_news_events_count].name = "ECB Rate Decision";
    m_news_events[m_news_events_count].hour = 14;
    m_news_events[m_news_events_count].minute = 15;
    m_news_events[m_news_events_count].minutes_before = 5;
    m_news_events[m_news_events_count].minutes_after = 30;
    m_news_events[m_news_events_count].day_of_week = 4; // Thursday
    m_news_events[m_news_events_count].day_of_month_min = 1;
    m_news_events[m_news_events_count].day_of_month_max = 21; // First 3 weeks
    m_news_events[m_news_events_count].is_high_impact = true;
    m_news_events_count++;

    // US Non-Farm Payrolls (First Friday at 14:30 CET)
    m_news_events[m_news_events_count].name = "US NFP";
    m_news_events[m_news_events_count].hour = 14;
    m_news_events[m_news_events_count].minute = 30;
    m_news_events[m_news_events_count].minutes_before = 5;
    m_news_events[m_news_events_count].minutes_after = 15;
    m_news_events[m_news_events_count].day_of_week = 5; // Friday
    m_news_events[m_news_events_count].day_of_month_min = 1;
    m_news_events[m_news_events_count].day_of_month_max = 7; // First week
    m_news_events[m_news_events_count].is_high_impact = true;
    m_news_events_count++;

    // US CPI (Mid-month at 14:30 CET)
    m_news_events[m_news_events_count].name = "US CPI";
    m_news_events[m_news_events_count].hour = 14;
    m_news_events[m_news_events_count].minute = 30;
    m_news_events[m_news_events_count].minutes_before = 5;
    m_news_events[m_news_events_count].minutes_after = 15;
    m_news_events[m_news_events_count].day_of_week = 0; // Any day
    m_news_events[m_news_events_count].day_of_month_min = 10;
    m_news_events[m_news_events_count].day_of_month_max = 16;
    m_news_events[m_news_events_count].is_high_impact = true;
    m_news_events_count++;

    // FOMC Meeting (8 times per year, usually Wednesday 20:00 CET)
    m_news_events[m_news_events_count].name = "FOMC Meeting";
    m_news_events[m_news_events_count].hour = 20;
    m_news_events[m_news_events_count].minute = 0;
    m_news_events[m_news_events_count].minutes_before = 5;
    m_news_events[m_news_events_count].minutes_after = 30;
    m_news_events[m_news_events_count].day_of_week = 3; // Wednesday
    m_news_events[m_news_events_count].day_of_month_min = 0; // Any day
    m_news_events[m_news_events_count].day_of_month_max = 0;
    m_news_events[m_news_events_count].is_high_impact = true;
    m_news_events_count++;

    // Flash PMI (Around 23rd at 09:30 CET)
    m_news_events[m_news_events_count].name = "Flash PMI";
    m_news_events[m_news_events_count].hour = 9;
    m_news_events[m_news_events_count].minute = 30;
    m_news_events[m_news_events_count].minutes_before = 5;
    m_news_events[m_news_events_count].minutes_after = 10;
    m_news_events[m_news_events_count].day_of_week = 0; // Any day
    m_news_events[m_news_events_count].day_of_month_min = 22;
    m_news_events[m_news_events_count].day_of_month_max = 25;
    m_news_events[m_news_events_count].is_high_impact = true;
    m_news_events_count++;

    Print("TradingRegimeManager: Initialized ", m_news_events_count, " high impact news events");
}

//+------------------------------------------------------------------+
//| Update current trading regime                                   |
//+------------------------------------------------------------------+
bool CTradingRegimeManager::UpdateCurrentRegime()
{
    if(!m_initialized)
        return false;

    datetime current_time = TimeCurrent();

    // Check if we need to update (every minute)
    if(current_time - m_last_regime_check < 60)
        return true;

    m_last_regime_check = current_time;

    // Check for daily reset
    CheckDailyReset();

    // Update ATR
    UpdateATR();

    // Determine current regime
    ENUM_TRADING_REGIME new_regime = DetermineRegimeFromTime(current_time);

    if(new_regime != m_current_regime)
    {
        Print("TradingRegimeManager: Regime changed from ", EnumToString(m_current_regime),
              " to ", EnumToString(new_regime));
        m_current_regime = new_regime;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Get current regime configuration                                |
//+------------------------------------------------------------------+
SRegimeConfig CTradingRegimeManager::GetCurrentRegimeConfig()
{
    if(m_current_regime >= REGIME_TRENDING && m_current_regime <= REGIME_QUIET)
        return m_regimes[m_current_regime];

    // Return empty config for REGIME_NONE
    SRegimeConfig empty_config;
    return empty_config;
}

//+------------------------------------------------------------------+
//| Check if new trade can be opened                                |
//+------------------------------------------------------------------+
bool CTradingRegimeManager::CanOpenNewTrade()
{
    if(!m_initialized || m_current_regime == REGIME_NONE)
        return false;

    // Check regime-specific trade limits
    SRegimeConfig config = GetCurrentRegimeConfig();
    int current_trades = 0;

    switch(m_current_regime)
    {
        case REGIME_TRENDING:
            current_trades = m_trend_trades_today;
            break;
        case REGIME_RANGING:
            current_trades = m_mr_trades_today;
            break;
        case REGIME_VOLATILE:
            current_trades = m_us_trades_today;
            break;
        case REGIME_QUIET:
            current_trades = m_trend_trades_today; // Use trend counter for quiet regime
            break;
        default:
            return false;
    }

    if(current_trades >= config.max_trades)
    {
        Print("TradingRegimeManager: Trade limit reached for regime ", EnumToString(m_current_regime),
              " (", current_trades, "/", config.max_trades, ")");
        return false;
    }

    // Check total daily limit (max 5 trades per day)
    if(GetTotalTradesToday() >= 5)
    {
        Print("TradingRegimeManager: Daily trade limit reached (5)");
        return false;
    }

    // Check volatility conditions
    if(!ValidateVolatilityConditions())
        return false;

    // Check news times
    if(IsNewsTime())
    {
        Print("TradingRegimeManager: News time - no new trades");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Register new trade                                              |
//+------------------------------------------------------------------+
bool CTradingRegimeManager::RegisterNewTrade()
{
    if(!CanOpenNewTrade())
        return false;

    switch(m_current_regime)
    {
        case REGIME_TRENDING:
            m_trend_trades_today++;
            break;
        case REGIME_RANGING:
            m_mr_trades_today++;
            break;
        case REGIME_VOLATILE:
            m_us_trades_today++;
            break;
        case REGIME_QUIET:
            m_trend_trades_today++; // Use trend counter for quiet regime
            break;
        default:
            return false;
    }

    Print("TradingRegimeManager: Registered new trade for regime ", EnumToString(m_current_regime));
    return true;
}

//+------------------------------------------------------------------+
//| Validate volatility conditions                                  |
//+------------------------------------------------------------------+
bool CTradingRegimeManager::ValidateVolatilityConditions()
{
    if(m_current_atr <= 0)
        return false;

    // ATR should be between 8 and 35 points for DAX
    double atr_points = m_current_atr; // ATR is already in price units for DAX

    if(atr_points < 8.0)
    {
        Print("TradingRegimeManager: ATR too low (", atr_points, " < 8.0) - market too quiet");
        return false;
    }

    if(atr_points > 35.0)
    {
        Print("TradingRegimeManager: ATR too high (", atr_points, " > 35.0) - market too volatile");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Get optimal stop loss for regime                                |
//+------------------------------------------------------------------+
double CTradingRegimeManager::GetOptimalStopLoss(ENUM_TRADING_REGIME regime, bool is_long, double entry_price)
{
    if(m_current_atr <= 0)
        return 0.0;

    SRegimeConfig config = m_regimes[regime];

    // Calculate ATR-based SL (1.2 x ATR but capped by regime max)
    double atr_sl_distance = MathMin(1.2 * m_current_atr, config.max_sl_points);

    // Ensure minimum 6 points
    atr_sl_distance = MathMax(atr_sl_distance, 6.0);

    double sl_price;
    if(is_long)
        sl_price = entry_price - atr_sl_distance;
    else
        sl_price = entry_price + atr_sl_distance;

    return sl_price;
}

//+------------------------------------------------------------------+
//| Get optimal take profit for regime                              |
//+------------------------------------------------------------------+
double CTradingRegimeManager::GetOptimalTakeProfit(ENUM_TRADING_REGIME regime, bool is_long, double entry_price, double sl_price)
{
    SRegimeConfig config = m_regimes[regime];

    double sl_distance = MathAbs(entry_price - sl_price);

    // Apply seasonal target multiplier
    double seasonal_target_mult = GetSeasonalTargetMultiplier();
    double adjusted_r_multiple = config.target_r_multiple * seasonal_target_mult;

    double tp_distance = sl_distance * adjusted_r_multiple;

    double tp_price;
    if(is_long)
        tp_price = entry_price + tp_distance;
    else
        tp_price = entry_price - tp_distance;

    Print("TradingRegimeManager: TP calculation - Base R:", config.target_r_multiple,
          " Seasonal mult:", seasonal_target_mult, " Final R:", adjusted_r_multiple);

    return tp_price;
}

//+------------------------------------------------------------------+
//| Reset daily counters                                            |
//+------------------------------------------------------------------+
void CTradingRegimeManager::ResetDailyCounters()
{
    m_trend_trades_today = 0;
    m_mr_trades_today = 0;
    m_us_trades_today = 0;
    m_last_reset_date = TimeCurrent();

    Print("TradingRegimeManager: Daily counters reset");
}

//+------------------------------------------------------------------+
//| Check if daily reset is needed                                  |
//+------------------------------------------------------------------+
void CTradingRegimeManager::CheckDailyReset()
{
    datetime current_time = TimeCurrent();
    MqlDateTime dt_current, dt_last;

    TimeToStruct(current_time, dt_current);
    TimeToStruct(m_last_reset_date, dt_last);

    // Reset if it's a new day
    if(dt_current.day != dt_last.day || dt_current.mon != dt_last.mon || dt_current.year != dt_last.year)
    {
        ResetDailyCounters();
    }
}

//+------------------------------------------------------------------+
//| Determine regime from current time                              |
//+------------------------------------------------------------------+
ENUM_TRADING_REGIME CTradingRegimeManager::DetermineRegimeFromTime(datetime current_time)
{
    // Check each regime
    for(int i = REGIME_TRENDING; i <= REGIME_QUIET; i++)
    {
        if(IsWithinRegimeHours(m_regimes[i], current_time))
            return (ENUM_TRADING_REGIME)i;
    }

    return REGIME_NONE;
}

//+------------------------------------------------------------------+
//| Check if time is within regime hours                            |
//+------------------------------------------------------------------+
bool CTradingRegimeManager::IsWithinRegimeHours(const SRegimeConfig &config, datetime current_time)
{
    MqlDateTime dt;
    TimeToStruct(current_time, dt);

    int current_minutes = dt.hour * 60 + dt.min;
    int start_minutes = config.start_hour * 60 + config.start_minute;
    int end_minutes = config.end_hour * 60 + config.end_minute;

    return (current_minutes >= start_minutes && current_minutes < end_minutes);
}

//+------------------------------------------------------------------+
//| Update ATR indicator                                            |
//+------------------------------------------------------------------+
bool CTradingRegimeManager::UpdateATR()
{
    if(m_atr_handle == INVALID_HANDLE)
        return false;

    double atr_buffer[1];
    if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_buffer) <= 0)
        return false;

    m_current_atr = atr_buffer[0];
    return true;
}

//+------------------------------------------------------------------+
//| Check if current time is high impact news time                  |
//+------------------------------------------------------------------+
bool CTradingRegimeManager::IsHighImpactNewsTime(datetime current_time) const
{
    MqlDateTime dt;
    TimeToStruct(current_time, dt);

    int current_minutes = dt.hour * 60 + dt.min;

    // Check each configured news event
    for(int i = 0; i < m_news_events_count; i++)
    {
        SNewsEvent event = m_news_events[i];

        if(!event.is_high_impact)
            continue;

        // Check day of week (0 = any day)
        if(event.day_of_week > 0 && dt.day_of_week != event.day_of_week)
            continue;

        // Check day of month range (0 = any day)
        if(event.day_of_month_min > 0 && event.day_of_month_max > 0)
        {
            if(dt.day < event.day_of_month_min || dt.day > event.day_of_month_max)
                continue;
        }

        // Check time window
        int event_minutes = event.hour * 60 + event.minute;
        int start_minutes = event_minutes - event.minutes_before;
        int end_minutes = event_minutes + event.minutes_after;

        if(current_minutes >= start_minutes && current_minutes <= end_minutes)
        {
            Print("NEWS BLOCK: ", event.name, " detected at ", dt.hour, ":", dt.min);
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check if current time is news time (public interface)           |
//+------------------------------------------------------------------+
bool CTradingRegimeManager::IsNewsTime()
{
    // If news filter is disabled, never block trading
    if(!m_use_news_filter)
        return false;

    return IsHighImpactNewsTime(TimeCurrent());
}

//+------------------------------------------------------------------+
//| Get regime description                                           |
//+------------------------------------------------------------------+
string CTradingRegimeManager::GetRegimeDescription() const
{
    if(m_current_regime >= REGIME_TRENDING && m_current_regime <= REGIME_QUIET)
        return m_regimes[m_current_regime].description;

    return "No Trading";
}

//+------------------------------------------------------------------+
//| Get trading statistics                                           |
//+------------------------------------------------------------------+
string CTradingRegimeManager::GetTradingStatistics()
{
    string stats = "=== TRADING REGIME STATISTICS ===\n";
    stats += "Current Regime: " + GetRegimeDescription() + "\n";
    stats += StringFormat("Current ATR: %.1f points\n", m_current_atr);
    stats += StringFormat("Trades Today: Trend=%d, MR=%d, US=%d (Total=%d/5)\n",
                         m_trend_trades_today, m_mr_trades_today, m_us_trades_today, GetTotalTradesToday());

    if(m_current_regime != REGIME_NONE)
    {
        SRegimeConfig config = GetCurrentRegimeConfig();
        stats += StringFormat("Regime Config: Max=%d, MinStrength=%.1f, MaxSL=%.1f, TargetR=%.1f\n",
                             config.max_trades, config.min_signal_strength, config.max_sl_points, config.target_r_multiple);
    }

    stats += "Can Open Trade: " + (CanOpenNewTrade() ? "YES" : "NO") + "\n";
    stats += "News Time: " + (IsNewsTime() ? "YES" : "NO") + "\n";
    stats += GetNewsStatus() + "\n";

    return stats;
}

//+------------------------------------------------------------------+
//| Validate entry conditions for specific regime                   |
//+------------------------------------------------------------------+
bool CTradingRegimeManager::ValidateEntryConditions(ENUM_TRADING_REGIME regime, double entry_price)
{
    // This will be implemented with specific logic for each regime
    // For now, basic validation

    if(entry_price <= 0)
        return false;

    // Check spread
    double spread = SymbolInfoDouble(m_symbol, SYMBOL_ASK) - SymbolInfoDouble(m_symbol, SYMBOL_BID);
    if(spread > 2.5) // Max 2.5 points spread
    {
        Print("TradingRegimeManager: Spread too wide (", spread, " > 2.5)");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Get seasonal risk multiplier                                    |
//+------------------------------------------------------------------+
double CTradingRegimeManager::GetSeasonalRiskMultiplier() const
{
    MqlDateTime dt;
    datetime current_time = ::TimeCurrent();
    ::TimeToStruct(current_time, dt);
    int month = dt.mon;

    switch(month)
    {
        case 7:  return 1.4;  // Juli - høj risiko periode
        case 8:  return 1.3;  // August - høj risiko periode
        case 9:  return 1.4;  // September - høj risiko periode
        case 3:  return 0.6;  // Marts - lav risiko periode
        case 4:  return 0.6;  // April - lav risiko periode
        case 10: return 0.7;  // Oktober - moderat lav (drawdown periode)
        case 11: return 0.7;  // November - moderat lav (drawdown periode)
        case 12: return 0.8;  // December - jul volatilitet
        case 1:  return 0.8;  // Januar - nytårs effekt
        case 2:  return 0.9;  // Februar - stabilisering
        case 5:  return 1.0;  // Maj - neutral
        case 6:  return 1.1;  // Juni - let øget
        default: return 1.0;
    }
}

//+------------------------------------------------------------------+
//| Get seasonal target multiplier                                  |
//+------------------------------------------------------------------+
double CTradingRegimeManager::GetSeasonalTargetMultiplier() const
{
    MqlDateTime dt;
    datetime current_time = ::TimeCurrent();
    ::TimeToStruct(current_time, dt);
    int month = dt.mon;

    switch(month)
    {
        case 7:  return 1.3;  // Juli - øg targets i gode måneder
        case 8:  return 1.2;  // August - øg targets
        case 9:  return 1.3;  // September - øg targets i gode måneder
        case 3:  return 0.8;  // Marts - reducer targets i dårlige måneder
        case 4:  return 0.8;  // April - reducer targets i dårlige måneder
        case 10: return 0.9;  // Oktober - konservative targets
        case 11: return 0.9;  // November - konservative targets
        default: return 1.0;  // Alle andre måneder - standard
    }
}

//+------------------------------------------------------------------+
//| Get seasonal description                                         |
//+------------------------------------------------------------------+
string CTradingRegimeManager::GetSeasonalDescription() const
{
    MqlDateTime dt;
    datetime current_time = ::TimeCurrent();
    ::TimeToStruct(current_time, dt);
    int month = dt.mon;

    double risk_mult = GetSeasonalRiskMultiplier();
    double target_mult = GetSeasonalTargetMultiplier();

    string season_name;
    switch(month)
    {
        case 7:  season_name = "JULI (Høj Performance)"; break;
        case 8:  season_name = "AUGUST (Høj Performance)"; break;
        case 9:  season_name = "SEPTEMBER (Høj Performance)"; break;
        case 3:  season_name = "MARTS (Lav Performance)"; break;
        case 4:  season_name = "APRIL (Lav Performance)"; break;
        case 10: season_name = "OKTOBER (Drawdown Risiko)"; break;
        case 11: season_name = "NOVEMBER (Drawdown Risiko)"; break;
        case 12: season_name = "DECEMBER (Jul Volatilitet)"; break;
        case 1:  season_name = "JANUAR (Nytårs Effekt)"; break;
        case 2:  season_name = "FEBRUAR (Stabilisering)"; break;
        case 5:  season_name = "MAJ (Neutral)"; break;
        case 6:  season_name = "JUNI (Let Positiv)"; break;
        default: season_name = "UKENDT"; break;
    }

    return StringFormat("%s | Risk: %.1fx | Target: %.1fx",
                       season_name, risk_mult, target_mult);
}

//+------------------------------------------------------------------+
//| Get volatility multiplier based on current ATR                  |
//+------------------------------------------------------------------+
double CTradingRegimeManager::GetVolatilityMultiplier() const
{
    if(m_current_atr <= 0)
        return 1.0;

    // Define baseline ATR for DAX (30M timeframe optimized)
    double baseline_atr = 25.0; // 25 points baseline for 30M

    // Calculate volatility ratio
    double volatility_ratio = baseline_atr / m_current_atr;

    // Apply limits and smoothing
    // High volatility (low ATR) = increase position size
    // Low volatility (high ATR) = decrease position size
    double vol_multiplier = MathMax(0.5, MathMin(2.0, volatility_ratio));

    // Smooth the adjustment to avoid extreme changes
    vol_multiplier = 1.0 + (vol_multiplier - 1.0) * 0.7; // 70% of full adjustment

    return vol_multiplier;
}

//+------------------------------------------------------------------+
//| Get combined risk multiplier (seasonal + volatility)            |
//+------------------------------------------------------------------+
double CTradingRegimeManager::GetCombinedRiskMultiplier() const
{
    double seasonal_mult = GetSeasonalRiskMultiplier();
    double volatility_mult = GetVolatilityMultiplier();

    // Combine multipliers with safety limits
    double combined = seasonal_mult * volatility_mult;

    // Apply absolute safety limits
    combined = MathMax(0.3, MathMin(3.0, combined)); // Never below 30% or above 300%

    return combined;
}

//+------------------------------------------------------------------+
//| Get volatility description                                       |
//+------------------------------------------------------------------+
string CTradingRegimeManager::GetVolatilityDescription() const
{
    double vol_mult = GetVolatilityMultiplier();
    double combined_mult = GetCombinedRiskMultiplier();

    string vol_status;
    if(vol_mult > 1.2)
        vol_status = "LOW VOLATILITY (Øg position)";
    else if(vol_mult < 0.8)
        vol_status = "HIGH VOLATILITY (Reducer position)";
    else
        vol_status = "NORMAL VOLATILITY";

    return StringFormat("%s | ATR: %.1f | Vol Mult: %.2fx | Combined: %.2fx",
                       vol_status, m_current_atr, vol_mult, combined_mult);
}

//+------------------------------------------------------------------+
//| Get trailing stop distance based on regime and profit           |
//+------------------------------------------------------------------+
double CTradingRegimeManager::GetTrailingStopDistance(ENUM_TRADING_REGIME regime, double profit_r) const
{
    double base_distance = 0.5; // Base 0.5R trailing distance
    double atr_factor = m_current_atr / 25.0; // Normalize to 25-point baseline

    // Regime-based adjustments
    double regime_multiplier = 1.0;
    switch(regime)
    {
        case REGIME_TRENDING:
            regime_multiplier = 0.8; // Tighter trailing in trends
            break;
        case REGIME_RANGING:
            regime_multiplier = 1.2; // Wider trailing in ranges
            break;
        case REGIME_VOLATILE:
            regime_multiplier = 1.5; // Much wider in volatile conditions
            break;
        case REGIME_QUIET:
            regime_multiplier = 0.7; // Tight trailing in quiet markets
            break;
        default:
            regime_multiplier = 1.0;
            break;
    }

    // Profit-based dynamic adjustment
    double profit_multiplier = 1.0;
    if(profit_r >= 3.0)
        profit_multiplier = 0.6; // Very tight when 3R+ profit
    else if(profit_r >= 2.0)
        profit_multiplier = 0.7; // Tight when 2R+ profit
    else if(profit_r >= 1.5)
        profit_multiplier = 0.8; // Moderate when 1.5R+ profit
    else if(profit_r >= 1.0)
        profit_multiplier = 0.9; // Slightly tight when 1R+ profit

    // Volatility adjustment
    double vol_multiplier = MathMax(0.7, MathMin(1.5, atr_factor));

    // Seasonal adjustment for trailing
    double seasonal_trail_mult = 1.0;
    MqlDateTime dt;
    datetime current_time = ::TimeCurrent();
    ::TimeToStruct(current_time, dt);
    int month = dt.mon;

    if(month == 7 || month == 8 || month == 9)
        seasonal_trail_mult = 0.8; // Tighter trailing in good months
    else if(month == 3 || month == 4)
        seasonal_trail_mult = 1.3; // Wider trailing in bad months
    else if(month == 10 || month == 11)
        seasonal_trail_mult = 1.2; // Wider in drawdown months

    double final_distance = base_distance * regime_multiplier * profit_multiplier *
                           vol_multiplier * seasonal_trail_mult;

    // Apply safety limits
    return MathMax(0.3, MathMin(2.0, final_distance));
}

//+------------------------------------------------------------------+
//| Get breakeven threshold based on regime                         |
//+------------------------------------------------------------------+
double CTradingRegimeManager::GetBreakevenThreshold(ENUM_TRADING_REGIME regime) const
{
    double base_threshold = 1.0; // Base 1R breakeven

    switch(regime)
    {
        case REGIME_TRENDING:
            return base_threshold * 0.8; // Earlier breakeven in trends (0.8R)
        case REGIME_RANGING:
            return base_threshold * 1.2; // Later breakeven in ranges (1.2R)
        case REGIME_VOLATILE:
            return base_threshold * 1.5; // Much later in volatile markets (1.5R)
        case REGIME_QUIET:
            return base_threshold * 0.7; // Very early in quiet markets (0.7R)
        default:
            return base_threshold;
    }
}

//+------------------------------------------------------------------+
//| Check if trailing should be activated                           |
//+------------------------------------------------------------------+
bool CTradingRegimeManager::ShouldActivateTrailing(ENUM_TRADING_REGIME regime, double current_profit_r) const
{
    double threshold = GetBreakevenThreshold(regime);

    // Additional seasonal considerations
    MqlDateTime dt;
    datetime current_time = ::TimeCurrent();
    ::TimeToStruct(current_time, dt);
    int month = dt.mon;

    // In good months, activate trailing earlier
    if(month == 7 || month == 8 || month == 9)
        threshold *= 0.9;

    // In bad months, wait longer before trailing
    if(month == 3 || month == 4 || month == 10 || month == 11)
        threshold *= 1.1;

    return current_profit_r >= threshold;
}

//+------------------------------------------------------------------+
//| Get trailing stop description                                   |
//+------------------------------------------------------------------+
string CTradingRegimeManager::GetTrailingStopDescription() const
{
    ENUM_TRADING_REGIME current_regime = GetCurrentRegime();
    double trail_distance = GetTrailingStopDistance(current_regime, 1.0); // Example with 1R profit
    double breakeven_threshold = GetBreakevenThreshold(current_regime);

    string regime_name = EnumToString(current_regime);

    return StringFormat("Regime: %s | Breakeven: %.1fR | Trail Distance: %.1fR",
                       regime_name, breakeven_threshold, trail_distance);
}

//+------------------------------------------------------------------+
//| Get current news status                                         |
//+------------------------------------------------------------------+
string CTradingRegimeManager::GetNewsStatus() const
{
    datetime current_time = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(current_time, dt);

    string status = "News Filter: " + (m_use_news_filter ? "ENABLED" : "DISABLED") + " | ";

    if(!m_use_news_filter)
    {
        status += "News filtering disabled - Trading always allowed";
    }
    else if(IsHighImpactNewsTime(current_time))
    {
        status += "HIGH IMPACT NEWS ACTIVE - Trading Blocked";
    }
    else
    {
        status += "Clear - Trading Allowed";

        // Check for upcoming news in next 30 minutes
        datetime next_30min = current_time + 30 * 60;
        if(IsHighImpactNewsTime(next_30min))
        {
            status += " (News in <30min)";
        }
    }

    return status;
}

//+------------------------------------------------------------------+
//| Get upcoming news events for today                              |
//+------------------------------------------------------------------+
string CTradingRegimeManager::GetUpcomingNewsEvents() const
{
    datetime current_time = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(current_time, dt);

    string events = "Today's High Impact News:\n";
    bool found_events = false;

    for(int i = 0; i < m_news_events_count; i++)
    {
        SNewsEvent event = m_news_events[i];

        if(!event.is_high_impact)
            continue;

        // Check if event could occur today
        bool day_match = true;

        // Check day of week
        if(event.day_of_week > 0 && dt.day_of_week != event.day_of_week)
            day_match = false;

        // Check day of month
        if(event.day_of_month_min > 0 && event.day_of_month_max > 0)
        {
            if(dt.day < event.day_of_month_min || dt.day > event.day_of_month_max)
                day_match = false;
        }

        if(day_match)
        {
            events += StringFormat("- %s: %02d:%02d (±%d min)\n",
                                 event.name, event.hour, event.minute,
                                 event.minutes_before + event.minutes_after);
            found_events = true;
        }
    }

    if(!found_events)
    {
        events += "- No high impact news scheduled for today\n";
    }

    return events;
}
