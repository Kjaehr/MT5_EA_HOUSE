//+------------------------------------------------------------------+
//|                                         MovingAverageSignal.mqh |
//|                            Moving Average Signal Detection Class |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Moving Average Signal Detection Class                          |
//+------------------------------------------------------------------+
class CMovingAverageSignal
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    
    // MA handles
    int               m_ema_handle;
    int               m_smma_handle;
    
    // MA parameters
    int               m_ema_period;
    int               m_smma_period;
    ENUM_APPLIED_PRICE m_ema_applied_price;
    ENUM_APPLIED_PRICE m_smma_applied_price;
    
    // Signal data
    double            m_current_ema;
    double            m_current_smma;
    double            m_previous_ema;
    double            m_previous_smma;
    
    bool              m_initialized;

public:
    //--- Constructor/Destructor
                      CMovingAverageSignal(string symbol, ENUM_TIMEFRAMES timeframe,
                                          int ema_period = 4, int smma_period = 6);
                     ~CMovingAverageSignal();
    
    //--- Initialization
    bool              Initialize();
    void              Deinitialize();
    
    //--- Main update method
    bool              UpdateSignals();
    
    //--- Signal detection methods
    bool              IsBullishSignal();
    bool              IsBearishSignal();
    bool              IsEMAAboveSMMA();
    bool              IsEMABelowSMMA();
    
    //--- Advanced signal methods
    bool              IsBullishCrossover();
    bool              IsBearishCrossover();
    bool              IsStrongTrend(bool bullish);
    bool              IsTrendAccelerating(bool bullish);
    
    //--- Getter methods
    double            GetCurrentEMA() const { return m_current_ema; }
    double            GetCurrentSMMA() const { return m_current_smma; }
    double            GetMASpread() const { return m_current_ema - m_current_smma; }
    
    //--- Configuration methods
    void              SetParameters(int ema_period, int smma_period);
    
    //--- Information methods
    bool              IsInitialized() const { return m_initialized; }
    string            GetSignalDescription();

private:
    //--- Internal methods
    bool              CreateMAHandles();
    bool              GetMAData();
    bool              ValidateData();
    double            CalculateHLCC4(int shift);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMovingAverageSignal::CMovingAverageSignal(string symbol, ENUM_TIMEFRAMES timeframe,
                                          int ema_period, int smma_period)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_ema_period = ema_period;
    m_smma_period = smma_period;
    
    // Set applied prices according to strategy
    m_ema_applied_price = PRICE_CLOSE;        // 4 EMA on close
    m_smma_applied_price = PRICE_TYPICAL;     // 6 SMMA on HLCC/4 (will use custom calculation)
    
    m_ema_handle = INVALID_HANDLE;
    m_smma_handle = INVALID_HANDLE;
    
    // Initialize signal data
    m_current_ema = 0.0;
    m_current_smma = 0.0;
    m_previous_ema = 0.0;
    m_previous_smma = 0.0;
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMovingAverageSignal::~CMovingAverageSignal()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize Moving Average indicators                            |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::Initialize()
{
    if(!CreateMAHandles())
    {
        Print("MovingAverageSignal: Failed to create MA handles");
        return false;
    }
    
    // Wait for indicators to calculate
    Sleep(100);
    
    if(!UpdateSignals())
    {
        Print("MovingAverageSignal: Failed to get initial MA data");
        return false;
    }
    
    m_initialized = true;
    Print("MovingAverageSignal: Initialized successfully for ", m_symbol, " on ", EnumToString(m_timeframe));
    Print("MovingAverageSignal: Parameters - EMA:", m_ema_period, " SMMA:", m_smma_period);
    
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize Moving Average indicators                         |
//+------------------------------------------------------------------+
void CMovingAverageSignal::Deinitialize()
{
    if(m_ema_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ema_handle);
        m_ema_handle = INVALID_HANDLE;
    }
    
    if(m_smma_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_smma_handle);
        m_smma_handle = INVALID_HANDLE;
    }
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Create Moving Average indicator handles                        |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::CreateMAHandles()
{
    // Create EMA handle (4 period on close)
    m_ema_handle = iMA(m_symbol, m_timeframe, m_ema_period, 0, MODE_EMA, m_ema_applied_price);
    if(m_ema_handle == INVALID_HANDLE)
    {
        Print("MovingAverageSignal: Failed to create EMA indicator handle. Error: ", GetLastError());
        return false;
    }
    
    // Create SMMA handle (6 period on typical price - we'll calculate HLCC/4 manually)
    m_smma_handle = iMA(m_symbol, m_timeframe, m_smma_period, 0, MODE_SMMA, PRICE_TYPICAL);
    if(m_smma_handle == INVALID_HANDLE)
    {
        Print("MovingAverageSignal: Failed to create SMMA indicator handle. Error: ", GetLastError());
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Update Moving Average signals                                  |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::UpdateSignals()
{
    if(!m_initialized && (m_ema_handle == INVALID_HANDLE || m_smma_handle == INVALID_HANDLE))
        return false;
    
    if(!GetMAData())
        return false;
    
    return ValidateData();
}

//+------------------------------------------------------------------+
//| Get Moving Average data from indicators                        |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::GetMAData()
{
    double ema_buffer[];
    double smma_buffer[];
    
    ArraySetAsSeries(ema_buffer, true);
    ArraySetAsSeries(smma_buffer, true);
    
    // Get EMA data
    if(CopyBuffer(m_ema_handle, 0, 0, 3, ema_buffer) < 3)
    {
        Print("MovingAverageSignal: Failed to copy EMA buffer");
        return false;
    }
    
    // Get SMMA data
    if(CopyBuffer(m_smma_handle, 0, 0, 3, smma_buffer) < 3)
    {
        Print("MovingAverageSignal: Failed to copy SMMA buffer");
        return false;
    }
    
    // Store current and previous values
    m_previous_ema = m_current_ema;
    m_previous_smma = m_current_smma;
    
    m_current_ema = ema_buffer[0];
    m_current_smma = smma_buffer[0];
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate HLCC/4 price (High + Low + Close + Close) / 4       |
//+------------------------------------------------------------------+
double CMovingAverageSignal::CalculateHLCC4(int shift)
{
    double high = iHigh(m_symbol, m_timeframe, shift);
    double low = iLow(m_symbol, m_timeframe, shift);
    double close = iClose(m_symbol, m_timeframe, shift);
    
    if(high <= 0 || low <= 0 || close <= 0)
        return 0.0;
    
    return (high + low + close + close) / 4.0;
}

//+------------------------------------------------------------------+
//| Validate Moving Average data                                   |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::ValidateData()
{
    // Check for valid values
    if(m_current_ema == EMPTY_VALUE || m_current_smma == EMPTY_VALUE)
    {
        Print("MovingAverageSignal: Invalid MA data received");
        return false;
    }
    
    if(m_current_ema <= 0 || m_current_smma <= 0)
    {
        Print("MovingAverageSignal: Invalid MA values");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if MA shows bullish signal (EMA > SMMA)                 |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::IsBullishSignal()
{
    if(!m_initialized)
        return false;
    
    return m_current_ema > m_current_smma;
}

//+------------------------------------------------------------------+
//| Check if MA shows bearish signal (EMA < SMMA)                 |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::IsBearishSignal()
{
    if(!m_initialized)
        return false;
    
    return m_current_ema < m_current_smma;
}

//+------------------------------------------------------------------+
//| Check if EMA is above SMMA                                    |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::IsEMAAboveSMMA()
{
    return IsBullishSignal();
}

//+------------------------------------------------------------------+
//| Check if EMA is below SMMA                                    |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::IsEMABelowSMMA()
{
    return IsBearishSignal();
}

//+------------------------------------------------------------------+
//| Check for bullish crossover (EMA crosses above SMMA)         |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::IsBullishCrossover()
{
    if(!m_initialized)
        return false;
    
    return (m_previous_ema <= m_previous_smma && m_current_ema > m_current_smma);
}

//+------------------------------------------------------------------+
//| Check for bearish crossover (EMA crosses below SMMA)         |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::IsBearishCrossover()
{
    if(!m_initialized)
        return false;
    
    return (m_previous_ema >= m_previous_smma && m_current_ema < m_current_smma);
}

//+------------------------------------------------------------------+
//| Check for strong trend                                        |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::IsStrongTrend(bool bullish)
{
    if(!m_initialized)
        return false;
    
    double spread = MathAbs(m_current_ema - m_current_smma);
    double price = (m_current_ema + m_current_smma) / 2.0;
    double spread_percentage = (spread / price) * 100.0;
    
    // Consider strong trend if spread is significant (adjust threshold as needed)
    double threshold = 0.05; // 0.05% spread threshold
    
    if(bullish)
        return (m_current_ema > m_current_smma && spread_percentage > threshold);
    else
        return (m_current_ema < m_current_smma && spread_percentage > threshold);
}

//+------------------------------------------------------------------+
//| Check if trend is accelerating                               |
//+------------------------------------------------------------------+
bool CMovingAverageSignal::IsTrendAccelerating(bool bullish)
{
    if(!m_initialized)
        return false;
    
    double current_spread = m_current_ema - m_current_smma;
    double previous_spread = m_previous_ema - m_previous_smma;
    
    if(bullish)
    {
        // Bullish acceleration: positive spread increasing
        return (current_spread > 0 && current_spread > previous_spread);
    }
    else
    {
        // Bearish acceleration: negative spread decreasing (becoming more negative)
        return (current_spread < 0 && current_spread < previous_spread);
    }
}

//+------------------------------------------------------------------+
//| Set Moving Average parameters                                 |
//+------------------------------------------------------------------+
void CMovingAverageSignal::SetParameters(int ema_period, int smma_period)
{
    if(ema_period > 0) m_ema_period = ema_period;
    if(smma_period > 0) m_smma_period = smma_period;
    
    // Reinitialize if already initialized
    if(m_initialized)
    {
        Deinitialize();
        Initialize();
    }
}

//+------------------------------------------------------------------+
//| Get signal description                                         |
//+------------------------------------------------------------------+
string CMovingAverageSignal::GetSignalDescription()
{
    if(!m_initialized)
        return "MA: Not initialized";
    
    string signal_text = "MA: ";
    
    if(IsBullishSignal())
        signal_text += "BULLISH (EMA>SMMA)";
    else if(IsBearishSignal())
        signal_text += "BEARISH (EMA<SMMA)";
    else
        signal_text += "NEUTRAL";
    
    signal_text += StringFormat(" EMA:%.5f SMMA:%.5f", m_current_ema, m_current_smma);
    
    if(IsBullishCrossover())
        signal_text += " [BULL CROSS]";
    else if(IsBearishCrossover())
        signal_text += " [BEAR CROSS]";
    
    if(IsStrongTrend(true))
        signal_text += " [STRONG BULL]";
    else if(IsStrongTrend(false))
        signal_text += " [STRONG BEAR]";
    
    return signal_text;
}
