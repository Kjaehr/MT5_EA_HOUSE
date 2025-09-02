//+------------------------------------------------------------------+
//|                                                   MACDSignal.mqh |
//|                                      MACD Signal Detection Class |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| MACD Signal Detection Class                                     |
//+------------------------------------------------------------------+
class CMACDSignal
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    int               m_macd_handle;
    
    // MACD parameters
    int               m_fast_ema_period;
    int               m_slow_ema_period;
    int               m_signal_period;
    ENUM_APPLIED_PRICE m_applied_price;
    
    // Signal data
    double            m_current_macd;
    double            m_current_signal;
    double            m_previous_macd;
    double            m_previous_signal;
    
    bool              m_initialized;

public:
    //--- Constructor/Destructor
                      CMACDSignal(string symbol, ENUM_TIMEFRAMES timeframe, 
                                 int fast_period = 12, int slow_period = 26, int signal_period = 1);
                     ~CMACDSignal();
    
    //--- Initialization
    bool              Initialize();
    void              Deinitialize();
    
    //--- Main update method
    bool              UpdateSignals();
    
    //--- Signal detection methods
    bool              IsBullishSignal();
    bool              IsBearishSignal();
    bool              IsNeutralSignal();
    
    //--- Advanced signal methods
    bool              IsBullishCrossover();
    bool              IsBearishCrossover();
    bool              IsStrongBullish();
    bool              IsStrongBearish();
    bool              IsBullishTrend();
    bool              IsBearishTrend();
    
    //--- Getter methods
    double            GetCurrentMACD() const { return m_current_macd; }
    double            GetCurrentSignal() const { return m_current_signal; }
    double            GetMACDValue() const { return m_current_macd - m_current_signal; }
    double            GetMACDHistogram() const { return m_current_macd - m_current_signal; }
    
    //--- Configuration methods
    void              SetParameters(int fast_period, int slow_period, int signal_period);
    
    //--- Information methods
    bool              IsInitialized() const { return m_initialized; }
    string            GetSignalDescription();

private:
    //--- Internal methods
    bool              CreateMACDHandle();
    bool              GetMACDData();
    bool              ValidateData();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMACDSignal::CMACDSignal(string symbol, ENUM_TIMEFRAMES timeframe, 
                        int fast_period, int slow_period, int signal_period)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_fast_ema_period = fast_period;
    m_slow_ema_period = slow_period;
    m_signal_period = signal_period;
    m_applied_price = PRICE_CLOSE;
    
    m_macd_handle = INVALID_HANDLE;
    
    // Initialize signal data
    m_current_macd = 0.0;
    m_current_signal = 0.0;
    m_previous_macd = 0.0;
    m_previous_signal = 0.0;
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMACDSignal::~CMACDSignal()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize MACD indicator                                       |
//+------------------------------------------------------------------+
bool CMACDSignal::Initialize()
{
    if(!CreateMACDHandle())
    {
        Print("MACDSignal: Failed to create MACD handle");
        return false;
    }
    
    // Wait for indicator to calculate
    Sleep(100);
    
    if(!UpdateSignals())
    {
        Print("MACDSignal: Failed to get initial MACD data");
        return false;
    }
    
    m_initialized = true;
    Print("MACDSignal: Initialized successfully for ", m_symbol, " on ", EnumToString(m_timeframe));
    Print("MACDSignal: Parameters - Fast:", m_fast_ema_period, " Slow:", m_slow_ema_period, " Signal:", m_signal_period);
    
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize MACD indicator                                     |
//+------------------------------------------------------------------+
void CMACDSignal::Deinitialize()
{
    if(m_macd_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_macd_handle);
        m_macd_handle = INVALID_HANDLE;
    }
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Create MACD indicator handle                                    |
//+------------------------------------------------------------------+
bool CMACDSignal::CreateMACDHandle()
{
    m_macd_handle = iMACD(m_symbol, m_timeframe, m_fast_ema_period, 
                         m_slow_ema_period, m_signal_period, m_applied_price);
    
    if(m_macd_handle == INVALID_HANDLE)
    {
        Print("MACDSignal: Failed to create MACD indicator handle. Error: ", GetLastError());
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Update MACD signals                                             |
//+------------------------------------------------------------------+
bool CMACDSignal::UpdateSignals()
{
    if(!m_initialized && m_macd_handle == INVALID_HANDLE)
        return false;
    
    if(!GetMACDData())
        return false;
    
    return ValidateData();
}

//+------------------------------------------------------------------+
//| Get MACD data from indicator                                    |
//+------------------------------------------------------------------+
bool CMACDSignal::GetMACDData()
{
    double macd_main[];
    double macd_signal[];

    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);

    // Get MACD main line
    if(CopyBuffer(m_macd_handle, 0, 0, 3, macd_main) < 3)
    {
        Print("MACDSignal: Failed to copy MACD main buffer");
        return false;
    }

    // Get MACD signal line
    if(CopyBuffer(m_macd_handle, 1, 0, 3, macd_signal) < 3)
    {
        Print("MACDSignal: Failed to copy MACD signal buffer");
        return false;
    }

    // Store current and previous values
    m_previous_macd = m_current_macd;
    m_previous_signal = m_current_signal;

    m_current_macd = macd_main[0];
    m_current_signal = macd_signal[0];

    return true;
}

//+------------------------------------------------------------------+
//| Validate MACD data                                             |
//+------------------------------------------------------------------+
bool CMACDSignal::ValidateData()
{
    // Check for valid values
    if(m_current_macd == EMPTY_VALUE || m_current_signal == EMPTY_VALUE)
    {
        Print("MACDSignal: Invalid MACD data received");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if MACD shows bullish signal (MACD main > 0)            |
//+------------------------------------------------------------------+
bool CMACDSignal::IsBullishSignal()
{
    if(!m_initialized)
        return false;

    // Use MACD main line instead of histogram for (12,26,1) setup
    return m_current_macd > 0.0;
}

//+------------------------------------------------------------------+
//| Check if MACD shows bearish signal (MACD main < 0)            |
//+------------------------------------------------------------------+
bool CMACDSignal::IsBearishSignal()
{
    if(!m_initialized)
        return false;

    // Use MACD main line instead of histogram for (12,26,1) setup
    return m_current_macd < 0.0;
}

//+------------------------------------------------------------------+
//| Check if MACD is neutral (around zero)                         |
//+------------------------------------------------------------------+
bool CMACDSignal::IsNeutralSignal()
{
    if(!m_initialized)
        return false;

    double histogram = m_current_macd - m_current_signal;
    double threshold = 0.000005; // Very small threshold for neutrality

    return MathAbs(histogram) <= threshold;
}

//+------------------------------------------------------------------+
//| Check for bullish crossover (MACD crosses above signal)        |
//+------------------------------------------------------------------+
bool CMACDSignal::IsBullishCrossover()
{
    if(!m_initialized)
        return false;
    
    double current_histogram = m_current_macd - m_current_signal;
    double previous_histogram = m_previous_macd - m_previous_signal;
    
    return (previous_histogram <= 0 && current_histogram > 0);
}

//+------------------------------------------------------------------+
//| Check for bearish crossover (MACD crosses below signal)        |
//+------------------------------------------------------------------+
bool CMACDSignal::IsBearishCrossover()
{
    if(!m_initialized)
        return false;
    
    double current_histogram = m_current_macd - m_current_signal;
    double previous_histogram = m_previous_macd - m_previous_signal;
    
    return (previous_histogram >= 0 && current_histogram < 0);
}

//+------------------------------------------------------------------+
//| Check for strong bullish signal                                |
//+------------------------------------------------------------------+
bool CMACDSignal::IsStrongBullish()
{
    if(!m_initialized)
        return false;
    
    double histogram = m_current_macd - m_current_signal;
    double threshold = 0.001; // Adjust based on symbol characteristics
    
    return (histogram > threshold && m_current_macd > m_current_signal);
}

//+------------------------------------------------------------------+
//| Check for strong bearish signal                                |
//+------------------------------------------------------------------+
bool CMACDSignal::IsStrongBearish()
{
    if(!m_initialized)
        return false;
    
    double histogram = m_current_macd - m_current_signal;
    double threshold = -0.001; // Adjust based on symbol characteristics
    
    return (histogram < threshold && m_current_macd < m_current_signal);
}

//+------------------------------------------------------------------+
//| Set MACD parameters                                            |
//+------------------------------------------------------------------+
void CMACDSignal::SetParameters(int fast_period, int slow_period, int signal_period)
{
    if(fast_period > 0) m_fast_ema_period = fast_period;
    if(slow_period > 0) m_slow_ema_period = slow_period;
    if(signal_period > 0) m_signal_period = signal_period;
    
    // Reinitialize if already initialized
    if(m_initialized)
    {
        Deinitialize();
        Initialize();
    }
}

//+------------------------------------------------------------------+
//| Get signal description                                          |
//+------------------------------------------------------------------+
string CMACDSignal::GetSignalDescription()
{
    if(!m_initialized)
        return "MACD: Not initialized";
    
    string signal_text = "MACD: ";
    double histogram = m_current_macd - m_current_signal;
    
    if(IsBullishSignal())
        signal_text += "BULLISH";
    else if(IsBearishSignal())
        signal_text += "BEARISH";
    else
        signal_text += "NEUTRAL";
    
    signal_text += StringFormat(" (%.5f)", histogram);
    
    if(IsBullishCrossover())
        signal_text += " [BULL CROSS]";
    else if(IsBearishCrossover())
        signal_text += " [BEAR CROSS]";
    
    return signal_text;
}

//+------------------------------------------------------------------+
//| Check for bullish trend (MACD main line rising)               |
//+------------------------------------------------------------------+
bool CMACDSignal::IsBullishTrend()
{
    if(!m_initialized)
        return false;

    // MACD main line is rising
    return m_current_macd > m_previous_macd;
}

//+------------------------------------------------------------------+
//| Check for bearish trend (MACD main line falling)              |
//+------------------------------------------------------------------+
bool CMACDSignal::IsBearishTrend()
{
    if(!m_initialized)
        return false;

    // MACD main line is falling
    return m_current_macd < m_previous_macd;
}
