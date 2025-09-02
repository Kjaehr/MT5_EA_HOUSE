//+------------------------------------------------------------------+
//|                                              StochasticSignal.mqh |
//|                                 Stochastic Signal Detection Class |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Stochastic Signal Detection Class                              |
//+------------------------------------------------------------------+
class CStochasticSignal
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    int               m_stoch_handle;
    
    // Stochastic parameters
    int               m_k_period;
    int               m_d_period;
    int               m_slowing;
    ENUM_MA_METHOD    m_ma_method;
    ENUM_STO_PRICE    m_price_field;
    
    // Signal levels
    double            m_trigger_level;
    double            m_overbought_level;
    double            m_oversold_level;
    
    // Signal data
    double            m_current_main;
    double            m_current_signal;
    double            m_previous_main;
    double            m_previous_signal;
    
    bool              m_initialized;

public:
    //--- Constructor/Destructor
                      CStochasticSignal(string symbol, ENUM_TIMEFRAMES timeframe,
                                       int k_period = 14, int d_period = 3, int slowing = 3);
                     ~CStochasticSignal();
    
    //--- Initialization
    bool              Initialize();
    void              Deinitialize();
    
    //--- Main update method
    bool              UpdateSignals();
    
    //--- Signal detection methods
    bool              IsBullishSignal();
    bool              IsBearishSignal();
    bool              IsOverbought();
    bool              IsOversold();
    
    //--- Advanced signal methods
    bool              IsBullishCrossover();
    bool              IsBearishCrossover();
    bool              IsStrongBullish();
    bool              IsStrongBearish();
    bool              IsDivergence(bool bullish);
    
    //--- Getter methods
    double            GetCurrentMain() const { return m_current_main; }
    double            GetCurrentSignal() const { return m_current_signal; }
    double            GetTriggerLevel() const { return m_trigger_level; }
    
    //--- Configuration methods
    void              SetParameters(int k_period, int d_period, int slowing);
    void              SetLevels(double trigger, double overbought = 80.0, double oversold = 20.0);
    
    //--- Information methods
    bool              IsInitialized() const { return m_initialized; }
    string            GetSignalDescription();

private:
    //--- Internal methods
    bool              CreateStochasticHandle();
    bool              GetStochasticData();
    bool              ValidateData();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStochasticSignal::CStochasticSignal(string symbol, ENUM_TIMEFRAMES timeframe,
                                    int k_period, int d_period, int slowing)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_k_period = k_period;
    m_d_period = d_period;
    m_slowing = slowing;
    m_ma_method = MODE_SMA;
    m_price_field = STO_LOWHIGH;
    
    m_stoch_handle = INVALID_HANDLE;
    
    // Set default levels
    m_trigger_level = 50.0;
    m_overbought_level = 80.0;
    m_oversold_level = 20.0;
    
    // Initialize signal data
    m_current_main = 0.0;
    m_current_signal = 0.0;
    m_previous_main = 0.0;
    m_previous_signal = 0.0;
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStochasticSignal::~CStochasticSignal()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize Stochastic indicator                                |
//+------------------------------------------------------------------+
bool CStochasticSignal::Initialize()
{
    if(!CreateStochasticHandle())
    {
        Print("StochasticSignal: Failed to create Stochastic handle");
        return false;
    }
    
    // Wait for indicator to calculate
    Sleep(100);
    
    if(!UpdateSignals())
    {
        Print("StochasticSignal: Failed to get initial Stochastic data");
        return false;
    }
    
    m_initialized = true;
    Print("StochasticSignal: Initialized successfully for ", m_symbol, " on ", EnumToString(m_timeframe));
    Print("StochasticSignal: Parameters - K:", m_k_period, " D:", m_d_period, " Slowing:", m_slowing);
    Print("StochasticSignal: Levels - Trigger:", m_trigger_level, " OB:", m_overbought_level, " OS:", m_oversold_level);
    
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize Stochastic indicator                              |
//+------------------------------------------------------------------+
void CStochasticSignal::Deinitialize()
{
    if(m_stoch_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_stoch_handle);
        m_stoch_handle = INVALID_HANDLE;
    }
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Create Stochastic indicator handle                             |
//+------------------------------------------------------------------+
bool CStochasticSignal::CreateStochasticHandle()
{
    m_stoch_handle = iStochastic(m_symbol, m_timeframe, m_k_period, m_d_period, 
                                m_slowing, m_ma_method, m_price_field);
    
    if(m_stoch_handle == INVALID_HANDLE)
    {
        Print("StochasticSignal: Failed to create Stochastic indicator handle. Error: ", GetLastError());
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Update Stochastic signals                                      |
//+------------------------------------------------------------------+
bool CStochasticSignal::UpdateSignals()
{
    if(!m_initialized && m_stoch_handle == INVALID_HANDLE)
        return false;
    
    if(!GetStochasticData())
        return false;
    
    return ValidateData();
}

//+------------------------------------------------------------------+
//| Get Stochastic data from indicator                             |
//+------------------------------------------------------------------+
bool CStochasticSignal::GetStochasticData()
{
    double stoch_main[];
    double stoch_signal[];
    
    ArraySetAsSeries(stoch_main, true);
    ArraySetAsSeries(stoch_signal, true);
    
    // Get Stochastic main line (%K)
    if(CopyBuffer(m_stoch_handle, 0, 0, 3, stoch_main) < 3)
    {
        Print("StochasticSignal: Failed to copy Stochastic main buffer");
        return false;
    }
    
    // Get Stochastic signal line (%D)
    if(CopyBuffer(m_stoch_handle, 1, 0, 3, stoch_signal) < 3)
    {
        Print("StochasticSignal: Failed to copy Stochastic signal buffer");
        return false;
    }
    
    // Store current and previous values
    m_previous_main = m_current_main;
    m_previous_signal = m_current_signal;
    
    m_current_main = stoch_main[0];
    m_current_signal = stoch_signal[0];
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Stochastic data                                       |
//+------------------------------------------------------------------+
bool CStochasticSignal::ValidateData()
{
    // Check for valid values
    if(m_current_main == EMPTY_VALUE || m_current_signal == EMPTY_VALUE)
    {
        Print("StochasticSignal: Invalid Stochastic data received");
        return false;
    }
    
    // Check if values are within expected range (0-100)
    if(m_current_main < 0 || m_current_main > 100 || 
       m_current_signal < 0 || m_current_signal > 100)
    {
        Print("StochasticSignal: Stochastic values out of range");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if Stochastic shows bullish signal (> trigger level)    |
//+------------------------------------------------------------------+
bool CStochasticSignal::IsBullishSignal()
{
    if(!m_initialized)
        return false;
    
    // Stochastic above trigger level (50)
    return m_current_main > m_trigger_level;
}

//+------------------------------------------------------------------+
//| Check if Stochastic shows bearish signal (< trigger level)    |
//+------------------------------------------------------------------+
bool CStochasticSignal::IsBearishSignal()
{
    if(!m_initialized)
        return false;
    
    // Stochastic below trigger level (50)
    return m_current_main < m_trigger_level;
}

//+------------------------------------------------------------------+
//| Check if Stochastic is overbought                             |
//+------------------------------------------------------------------+
bool CStochasticSignal::IsOverbought()
{
    if(!m_initialized)
        return false;
    
    return m_current_main > m_overbought_level;
}

//+------------------------------------------------------------------+
//| Check if Stochastic is oversold                               |
//+------------------------------------------------------------------+
bool CStochasticSignal::IsOversold()
{
    if(!m_initialized)
        return false;
    
    return m_current_main < m_oversold_level;
}

//+------------------------------------------------------------------+
//| Check for bullish crossover (%K crosses above %D)            |
//+------------------------------------------------------------------+
bool CStochasticSignal::IsBullishCrossover()
{
    if(!m_initialized)
        return false;
    
    return (m_previous_main <= m_previous_signal && m_current_main > m_current_signal);
}

//+------------------------------------------------------------------+
//| Check for bearish crossover (%K crosses below %D)            |
//+------------------------------------------------------------------+
bool CStochasticSignal::IsBearishCrossover()
{
    if(!m_initialized)
        return false;
    
    return (m_previous_main >= m_previous_signal && m_current_main < m_current_signal);
}

//+------------------------------------------------------------------+
//| Check for strong bullish signal                               |
//+------------------------------------------------------------------+
bool CStochasticSignal::IsStrongBullish()
{
    if(!m_initialized)
        return false;
    
    // Strong bullish: above trigger level and rising
    return (m_current_main > m_trigger_level && 
            m_current_main > m_previous_main &&
            m_current_main > m_current_signal);
}

//+------------------------------------------------------------------+
//| Check for strong bearish signal                               |
//+------------------------------------------------------------------+
bool CStochasticSignal::IsStrongBearish()
{
    if(!m_initialized)
        return false;
    
    // Strong bearish: below trigger level and falling
    return (m_current_main < m_trigger_level && 
            m_current_main < m_previous_main &&
            m_current_main < m_current_signal);
}

//+------------------------------------------------------------------+
//| Check for divergence (simplified)                             |
//+------------------------------------------------------------------+
bool CStochasticSignal::IsDivergence(bool bullish)
{
    if(!m_initialized)
        return false;
    
    // Simplified divergence detection
    // This would need more sophisticated implementation for real use
    if(bullish)
        return (IsOversold() && m_current_main > m_previous_main);
    else
        return (IsOverbought() && m_current_main < m_previous_main);
}

//+------------------------------------------------------------------+
//| Set Stochastic parameters                                      |
//+------------------------------------------------------------------+
void CStochasticSignal::SetParameters(int k_period, int d_period, int slowing)
{
    if(k_period > 0) m_k_period = k_period;
    if(d_period > 0) m_d_period = d_period;
    if(slowing > 0) m_slowing = slowing;
    
    // Reinitialize if already initialized
    if(m_initialized)
    {
        Deinitialize();
        Initialize();
    }
}

//+------------------------------------------------------------------+
//| Set signal levels                                             |
//+------------------------------------------------------------------+
void CStochasticSignal::SetLevels(double trigger, double overbought, double oversold)
{
    if(trigger >= 0 && trigger <= 100) m_trigger_level = trigger;
    if(overbought >= 0 && overbought <= 100) m_overbought_level = overbought;
    if(oversold >= 0 && oversold <= 100) m_oversold_level = oversold;
}

//+------------------------------------------------------------------+
//| Get signal description                                         |
//+------------------------------------------------------------------+
string CStochasticSignal::GetSignalDescription()
{
    if(!m_initialized)
        return "Stochastic: Not initialized";
    
    string signal_text = "Stochastic: ";
    
    if(IsBullishSignal())
        signal_text += "BULLISH";
    else if(IsBearishSignal())
        signal_text += "BEARISH";
    else
        signal_text += "NEUTRAL";
    
    signal_text += StringFormat(" (%.1f/%.1f)", m_current_main, m_current_signal);
    
    if(IsOverbought())
        signal_text += " [OB]";
    else if(IsOversold())
        signal_text += " [OS]";
    
    if(IsBullishCrossover())
        signal_text += " [BULL CROSS]";
    else if(IsBearishCrossover())
        signal_text += " [BEAR CROSS]";
    
    return signal_text;
}
