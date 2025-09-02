//+------------------------------------------------------------------+
//|                                                  H4BiasFilter.mqh |
//|                           H4 EMA Bias Filter for Trend Direction |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| H4 Bias Enumeration                                              |
//+------------------------------------------------------------------+
enum ENUM_H4_BIAS
{
    H4_BIAS_NONE = 0,      // No clear bias
    H4_BIAS_BULLISH = 1,   // Bullish bias (allow longs)
    H4_BIAS_BEARISH = -1   // Bearish bias (allow shorts)
};

//+------------------------------------------------------------------+
//| H4 Bias Filter Class                                             |
//+------------------------------------------------------------------+
class CH4BiasFilter
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    
    // EMA handles
    int               m_ema20_handle;
    int               m_ema50_handle;
    
    // Current bias state
    ENUM_H4_BIAS      m_current_bias;
    datetime          m_last_update;
    
    // EMA values
    double            m_ema20_current;
    double            m_ema50_current;
    double            m_close_current;
    
    // Bias strength (0.0 - 1.0)
    double            m_bias_strength;
    
    bool              m_initialized;

public:
    //--- Constructor/Destructor
                      CH4BiasFilter(string symbol, ENUM_TIMEFRAMES timeframe = PERIOD_H4);
                     ~CH4BiasFilter();
    
    //--- Initialization
    bool              Initialize();
    void              Deinitialize();
    
    //--- Main methods
    bool              UpdateBias();
    ENUM_H4_BIAS      GetCurrentBias() const { return m_current_bias; }
    double            GetBiasStrength() const { return m_bias_strength; }
    
    //--- Validation methods
    bool              IsLongAllowed() const { return m_current_bias == H4_BIAS_BULLISH || m_current_bias == H4_BIAS_NONE; }
    bool              IsShortAllowed() const { return m_current_bias == H4_BIAS_BEARISH || m_current_bias == H4_BIAS_NONE; }
    bool              IsDirectionAllowed(bool is_long) const;
    
    //--- Scoring for signal strength
    double            GetBiasScore(bool is_long) const;
    
    //--- Information methods
    string            GetBiasDescription() const;
    string            GetDetailedInfo() const;
    bool              IsInitialized() const { return m_initialized; }

private:
    //--- Internal methods
    bool              UpdateEMAValues();
    ENUM_H4_BIAS      CalculateBias();
    double            CalculateBiasStrength();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CH4BiasFilter::CH4BiasFilter(string symbol, ENUM_TIMEFRAMES timeframe)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    
    m_ema20_handle = INVALID_HANDLE;
    m_ema50_handle = INVALID_HANDLE;
    
    m_current_bias = H4_BIAS_NONE;
    m_last_update = 0;
    
    m_ema20_current = 0.0;
    m_ema50_current = 0.0;
    m_close_current = 0.0;
    m_bias_strength = 0.0;
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CH4BiasFilter::~CH4BiasFilter()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize H4 bias filter                                       |
//+------------------------------------------------------------------+
bool CH4BiasFilter::Initialize()
{
    if(StringLen(m_symbol) == 0)
    {
        Print("H4BiasFilter: Invalid symbol");
        return false;
    }
    
    // Create EMA indicators
    m_ema20_handle = iMA(m_symbol, m_timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
    if(m_ema20_handle == INVALID_HANDLE)
    {
        Print("H4BiasFilter: Failed to create EMA20 indicator");
        return false;
    }
    
    m_ema50_handle = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
    if(m_ema50_handle == INVALID_HANDLE)
    {
        Print("H4BiasFilter: Failed to create EMA50 indicator");
        IndicatorRelease(m_ema20_handle);
        m_ema20_handle = INVALID_HANDLE;
        return false;
    }
    
    // Wait for indicators to be ready
    Sleep(100); // Small delay to ensure indicators are ready

    // Initial update - try a few times if it fails
    int attempts = 0;
    while(attempts < 3 && !UpdateBias())
    {
        attempts++;
        Print("H4BiasFilter: Initial bias attempt ", attempts, " failed, retrying...");
        Sleep(100);
    }

    if(attempts >= 3)
    {
        Print("H4BiasFilter: Failed to get initial bias after 3 attempts - using neutral bias");
        // Set neutral bias as fallback
        m_current_bias = H4_BIAS_NONE;
        m_bias_strength = 0.0;
        m_ema20_current = 0.0;
        m_ema50_current = 0.0;
        m_close_current = 0.0;
        // Don't return false - continue with neutral bias
    }
    
    m_initialized = true;
    Print("H4BiasFilter: Initialized successfully for ", m_symbol, " on ", EnumToString(m_timeframe));
    
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize H4 bias filter                                     |
//+------------------------------------------------------------------+
void CH4BiasFilter::Deinitialize()
{
    if(m_ema20_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ema20_handle);
        m_ema20_handle = INVALID_HANDLE;
    }
    
    if(m_ema50_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ema50_handle);
        m_ema50_handle = INVALID_HANDLE;
    }
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Update H4 bias                                                  |
//+------------------------------------------------------------------+
bool CH4BiasFilter::UpdateBias()
{
    // Allow update during initialization (m_initialized may be false)

    // Check if we need to update (every H4 bar or first time)
    datetime current_bar_time = iTime(m_symbol, m_timeframe, 0);
    if(current_bar_time == m_last_update && m_last_update != 0 && m_initialized)
        return true;

    // Update EMA values
    if(!UpdateEMAValues())
        return false;

    // Calculate new bias
    ENUM_H4_BIAS new_bias = CalculateBias();

    if(new_bias != m_current_bias && m_initialized) // Only print if already initialized
    {
        Print("H4BiasFilter: Bias changed from ", EnumToString(m_current_bias),
              " to ", EnumToString(new_bias));
    }
    m_current_bias = new_bias;

    // Calculate bias strength
    m_bias_strength = CalculateBiasStrength();

    m_last_update = current_bar_time;
    return true;
}

//+------------------------------------------------------------------+
//| Update EMA values                                               |
//+------------------------------------------------------------------+
bool CH4BiasFilter::UpdateEMAValues()
{
    double ema20_buffer[1];
    double ema50_buffer[1];

    // Check if handles are valid
    if(m_ema20_handle == INVALID_HANDLE || m_ema50_handle == INVALID_HANDLE)
    {
        Print("H4BiasFilter: Invalid indicator handles");
        return false;
    }

    // Get EMA20 value
    int copied = CopyBuffer(m_ema20_handle, 0, 0, 1, ema20_buffer);
    if(copied <= 0)
    {
        Print("H4BiasFilter: Failed to get EMA20 value, error: ", GetLastError());
        return false;
    }

    // Get EMA50 value
    copied = CopyBuffer(m_ema50_handle, 0, 0, 1, ema50_buffer);
    if(copied <= 0)
    {
        Print("H4BiasFilter: Failed to get EMA50 value, error: ", GetLastError());
        return false;
    }

    // Get current close price
    m_close_current = iClose(m_symbol, m_timeframe, 0);
    if(m_close_current <= 0)
    {
        Print("H4BiasFilter: Failed to get current close price, error: ", GetLastError());
        // Try to get close price from current timeframe if H4 fails
        m_close_current = iClose(m_symbol, PERIOD_CURRENT, 0);
        if(m_close_current <= 0)
        {
            Print("H4BiasFilter: Failed to get close price from any timeframe");
            return false;
        }
        Print("H4BiasFilter: Using current timeframe close price as fallback");
    }

    // Validate values
    if(ema20_buffer[0] <= 0 || ema50_buffer[0] <= 0)
    {
        Print("H4BiasFilter: Invalid EMA values - EMA20: ", ema20_buffer[0], " EMA50: ", ema50_buffer[0]);
        return false;
    }

    m_ema20_current = ema20_buffer[0];
    m_ema50_current = ema50_buffer[0];

    return true;
}

//+------------------------------------------------------------------+
//| Calculate H4 bias                                               |
//+------------------------------------------------------------------+
ENUM_H4_BIAS CH4BiasFilter::CalculateBias()
{
    // Bullish bias: Close > EMA50 AND EMA20 > EMA50
    if(m_close_current > m_ema50_current && m_ema20_current > m_ema50_current)
        return H4_BIAS_BULLISH;
    
    // Bearish bias: Close < EMA50 AND EMA20 < EMA50
    if(m_close_current < m_ema50_current && m_ema20_current < m_ema50_current)
        return H4_BIAS_BEARISH;
    
    // No clear bias
    return H4_BIAS_NONE;
}

//+------------------------------------------------------------------+
//| Calculate bias strength                                          |
//+------------------------------------------------------------------+
double CH4BiasFilter::CalculateBiasStrength()
{
    if(m_current_bias == H4_BIAS_NONE)
        return 0.0;

    // Check if we have valid EMA values
    if(m_ema20_current <= 0 || m_ema50_current <= 0 || m_close_current <= 0)
        return 0.0;

    // Calculate distance between EMAs as percentage
    double ema_distance = MathAbs(m_ema20_current - m_ema50_current);
    double price_distance = MathAbs(m_close_current - m_ema50_current);

    // Normalize to get strength (0.0 - 1.0)
    double avg_price = (m_ema20_current + m_ema50_current) / 2.0;
    if(avg_price <= 0)
        return 0.0;

    double ema_strength = MathMin(ema_distance / avg_price * 1000, 1.0); // Scale for DAX
    double price_strength = MathMin(price_distance / avg_price * 1000, 1.0);

    // Combined strength
    double strength = (ema_strength + price_strength) / 2.0;

    return MathMax(0.1, MathMin(1.0, strength)); // Ensure range [0.1, 1.0]
}

//+------------------------------------------------------------------+
//| Check if direction is allowed                                   |
//+------------------------------------------------------------------+
bool CH4BiasFilter::IsDirectionAllowed(bool is_long) const
{
    if(is_long)
        return IsLongAllowed();
    else
        return IsShortAllowed();
}

//+------------------------------------------------------------------+
//| Get bias score for signal strength                              |
//+------------------------------------------------------------------+
double CH4BiasFilter::GetBiasScore(bool is_long) const
{
    // Only give points if bias actually supports the direction (not neutral)
    if(is_long && m_current_bias == H4_BIAS_BULLISH)
        return 0.5 * m_bias_strength;
    else if(!is_long && m_current_bias == H4_BIAS_BEARISH)
        return 0.5 * m_bias_strength;
    else
        return 0.0; // No points for neutral bias or wrong direction
}

//+------------------------------------------------------------------+
//| Get bias description                                             |
//+------------------------------------------------------------------+
string CH4BiasFilter::GetBiasDescription() const
{
    switch(m_current_bias)
    {
        case H4_BIAS_BULLISH: return "BULLISH";
        case H4_BIAS_BEARISH: return "BEARISH";
        default: return "NEUTRAL";
    }
}

//+------------------------------------------------------------------+
//| Get detailed information                                         |
//+------------------------------------------------------------------+
string CH4BiasFilter::GetDetailedInfo() const
{
    string info = "=== H4 BIAS FILTER ===\n";
    info += "Bias: " + GetBiasDescription() + StringFormat(" (Strength: %.2f)\n", m_bias_strength);
    info += StringFormat("Close: %.1f | EMA20: %.1f | EMA50: %.1f\n",
                        m_close_current, m_ema20_current, m_ema50_current);
    info += "Longs Allowed: " + (IsLongAllowed() ? "YES" : "NO") + " | Shorts Allowed: " + (IsShortAllowed() ? "YES" : "NO") + "\n";

    return info;
}
