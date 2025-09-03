//+------------------------------------------------------------------+
//|                                         TrendMomentumStrategy.mqh |
//|                     Enhanced Trend Following & Momentum Strategy  |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

//--- Trend momentum signal structure
struct STrendMomentumSignal
{
    bool              is_valid;
    bool              is_long;
    double            entry_price;
    double            stop_loss;
    double            take_profit;
    double            confidence;
    string            signal_type;
    double            momentum_strength;
    double            trend_strength;
};

//--- Trend momentum enums
enum ENUM_MOMENTUM_TYPE
{
    MOMENTUM_BREAKOUT,      // Breakout momentum
    MOMENTUM_PULLBACK,      // Pullback in trend
    MOMENTUM_ACCELERATION,  // Trend acceleration
    MOMENTUM_CONTINUATION   // Trend continuation
};

//+------------------------------------------------------------------+
//| Trend Momentum Strategy Class                                   |
//+------------------------------------------------------------------+
class CTrendMomentumStrategy
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    
    // Indicator handles
    int               m_atr_handle;
    int               m_adx_handle;
    int               m_ema_fast_handle;
    int               m_ema_slow_handle;
    int               m_rsi_handle;
    int               m_macd_handle;
    
    // Parameters
    int               m_atr_period;
    int               m_adx_period;
    int               m_ema_fast_period;
    int               m_ema_slow_period;
    int               m_rsi_period;
    double            m_trend_threshold;
    double            m_momentum_threshold;
    double            m_volatility_multiplier;
    
    // Current values
    double            m_current_atr;
    double            m_current_adx;
    double            m_current_rsi;
    double            m_ema_fast;
    double            m_ema_slow;
    double            m_macd_main;
    double            m_macd_signal;
    
    bool              m_initialized;

public:
    //--- Constructor/Destructor
                      CTrendMomentumStrategy(string symbol, ENUM_TIMEFRAMES timeframe);
                     ~CTrendMomentumStrategy();
    
    //--- Initialization
    bool              Initialize();
    void              Deinitialize();
    
    //--- Main methods
    bool              UpdateIndicators();
    STrendMomentumSignal CheckTrendMomentumSignal();
    
    //--- Trend analysis
    bool              IsStrongTrend();
    bool              IsTrendAccelerating();
    double            GetTrendStrength();
    double            GetMomentumStrength();
    
    //--- Volatility analysis
    bool              IsHighVolatility();
    double            GetVolatilityRatio();
    double            GetATRMultipliedStopLoss(bool is_long, double entry_price, double multiplier = 2.0);
    
    //--- Signal generation
    STrendMomentumSignal CheckBreakoutMomentum();
    STrendMomentumSignal CheckPullbackEntry();
    STrendMomentumSignal CheckTrendAcceleration();
    STrendMomentumSignal CheckTrendContinuation();
    
    //--- Risk management
    double            CalculateDynamicStopLoss(bool is_long, double entry_price, ENUM_MOMENTUM_TYPE momentum_type);
    double            CalculateDynamicTakeProfit(bool is_long, double entry_price, double stop_loss, ENUM_MOMENTUM_TYPE momentum_type);
    
    //--- Getters
    bool              IsInitialized() const { return m_initialized; }
    double            GetCurrentATR() const { return m_current_atr; }
    double            GetCurrentADX() const { return m_current_adx; }
    
private:
    //--- Internal methods
    bool              CreateIndicatorHandles();
    bool              GetIndicatorValues();
    bool              ValidateIndicatorData();
    double            CalculateEMASlope(int handle, int period = 3);
    bool              IsEMAConvergence();
    bool              IsRSIMomentum(bool bullish);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrendMomentumStrategy::CTrendMomentumStrategy(string symbol, ENUM_TIMEFRAMES timeframe)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    
    // Set default parameters
    m_atr_period = 14;
    m_adx_period = 14;
    m_ema_fast_period = 8;
    m_ema_slow_period = 21;
    m_rsi_period = 14;
    m_trend_threshold = 25.0;
    m_momentum_threshold = 60.0;
    m_volatility_multiplier = 1.5;
    
    // Initialize handles
    m_atr_handle = INVALID_HANDLE;
    m_adx_handle = INVALID_HANDLE;
    m_ema_fast_handle = INVALID_HANDLE;
    m_ema_slow_handle = INVALID_HANDLE;
    m_rsi_handle = INVALID_HANDLE;
    m_macd_handle = INVALID_HANDLE;
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrendMomentumStrategy::~CTrendMomentumStrategy()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize strategy                                              |
//+------------------------------------------------------------------+
bool CTrendMomentumStrategy::Initialize()
{
    if(!CreateIndicatorHandles())
    {
        Print("TrendMomentumStrategy: Failed to create indicator handles");
        return false;
    }
    
    // Wait for indicators to calculate
    Sleep(100);
    
    if(!UpdateIndicators())
    {
        Print("TrendMomentumStrategy: Failed to get initial indicator data");
        return false;
    }
    
    m_initialized = true;
    Print("TrendMomentumStrategy: Initialized successfully for ", m_symbol, " on ", EnumToString(m_timeframe));
    
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize strategy                                           |
//+------------------------------------------------------------------+
void CTrendMomentumStrategy::Deinitialize()
{
    if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
    if(m_adx_handle != INVALID_HANDLE) IndicatorRelease(m_adx_handle);
    if(m_ema_fast_handle != INVALID_HANDLE) IndicatorRelease(m_ema_fast_handle);
    if(m_ema_slow_handle != INVALID_HANDLE) IndicatorRelease(m_ema_slow_handle);
    if(m_rsi_handle != INVALID_HANDLE) IndicatorRelease(m_rsi_handle);
    if(m_macd_handle != INVALID_HANDLE) IndicatorRelease(m_macd_handle);
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Create indicator handles                                         |
//+------------------------------------------------------------------+
bool CTrendMomentumStrategy::CreateIndicatorHandles()
{
    m_atr_handle = iATR(m_symbol, m_timeframe, m_atr_period);
    m_adx_handle = iADX(m_symbol, m_timeframe, m_adx_period);
    m_ema_fast_handle = iMA(m_symbol, m_timeframe, m_ema_fast_period, 0, MODE_EMA, PRICE_CLOSE);
    m_ema_slow_handle = iMA(m_symbol, m_timeframe, m_ema_slow_period, 0, MODE_EMA, PRICE_CLOSE);
    m_rsi_handle = iRSI(m_symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);
    m_macd_handle = iMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE);
    
    return (m_atr_handle != INVALID_HANDLE && 
            m_adx_handle != INVALID_HANDLE && 
            m_ema_fast_handle != INVALID_HANDLE && 
            m_ema_slow_handle != INVALID_HANDLE && 
            m_rsi_handle != INVALID_HANDLE && 
            m_macd_handle != INVALID_HANDLE);
}

//+------------------------------------------------------------------+
//| Update all indicators                                            |
//+------------------------------------------------------------------+
bool CTrendMomentumStrategy::UpdateIndicators()
{
    if(!GetIndicatorValues())
        return false;
        
    return ValidateIndicatorData();
}

//+------------------------------------------------------------------+
//| Get indicator values                                             |
//+------------------------------------------------------------------+
bool CTrendMomentumStrategy::GetIndicatorValues()
{
    double atr_buffer[1];
    double adx_buffer[1];
    double ema_fast_buffer[1];
    double ema_slow_buffer[1];
    double rsi_buffer[1];
    double macd_main_buffer[1];
    double macd_signal_buffer[1];
    
    if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_buffer) <= 0) return false;
    if(CopyBuffer(m_adx_handle, 0, 0, 1, adx_buffer) <= 0) return false;
    if(CopyBuffer(m_ema_fast_handle, 0, 0, 1, ema_fast_buffer) <= 0) return false;
    if(CopyBuffer(m_ema_slow_handle, 0, 0, 1, ema_slow_buffer) <= 0) return false;
    if(CopyBuffer(m_rsi_handle, 0, 0, 1, rsi_buffer) <= 0) return false;
    if(CopyBuffer(m_macd_handle, 0, 0, 1, macd_main_buffer) <= 0) return false;
    if(CopyBuffer(m_macd_handle, 1, 0, 1, macd_signal_buffer) <= 0) return false;
    
    m_current_atr = atr_buffer[0];
    m_current_adx = adx_buffer[0];
    m_ema_fast = ema_fast_buffer[0];
    m_ema_slow = ema_slow_buffer[0];
    m_current_rsi = rsi_buffer[0];
    m_macd_main = macd_main_buffer[0];
    m_macd_signal = macd_signal_buffer[0];
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate indicator data                                          |
//+------------------------------------------------------------------+
bool CTrendMomentumStrategy::ValidateIndicatorData()
{
    return (m_current_atr > 0 && 
            m_current_adx >= 0 && 
            m_ema_fast > 0 && 
            m_ema_slow > 0 && 
            m_current_rsi >= 0 && m_current_rsi <= 100);
}
