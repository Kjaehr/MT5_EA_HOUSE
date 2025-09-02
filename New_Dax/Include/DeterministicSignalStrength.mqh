//+------------------------------------------------------------------+
//|                                  DeterministicSignalStrength.mqh |
//|                           Deterministic Signal Strength Calculator |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

#include "H4BiasFilter.mqh"
#include "TradingRegimeManager.mqh"

//+------------------------------------------------------------------+
//| Signal Strength Components Structure                            |
//+------------------------------------------------------------------+
struct SSignalComponents
{
    double h4_bias_score;      // 0.5 points max
    double atr_position_score; // 0.3 points max
    double ma_crossover_score; // 0.2 points max
    double macd_histogram_score; // 0.2 points max
    double total_score;        // Sum of all components
    
    // Constructor
    SSignalComponents()
    {
        h4_bias_score = 0.0;
        atr_position_score = 0.0;
        ma_crossover_score = 0.0;
        macd_histogram_score = 0.0;
        total_score = 0.0;
    }

    // Copy constructor to fix deprecation warning
    SSignalComponents(const SSignalComponents &other)
    {
        h4_bias_score = other.h4_bias_score;
        atr_position_score = other.atr_position_score;
        ma_crossover_score = other.ma_crossover_score;
        macd_histogram_score = other.macd_histogram_score;
        total_score = other.total_score;
    }
};

//+------------------------------------------------------------------+
//| Deterministic Signal Strength Calculator                        |
//+------------------------------------------------------------------+
class CDeterministicSignalStrength
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    
    // Component references
    CH4BiasFilter*    m_h4_bias;
    CTradingRegimeManager* m_regime_manager;
    
    // MA handles for crossover detection
    int               m_ema4_handle;
    int               m_smma6_handle;
    
    // MACD handle for histogram
    int               m_macd_handle;
    
    // Current values
    double            m_ema4_current;
    double            m_ema4_previous;
    double            m_smma6_current;
    double            m_smma6_previous;
    double            m_macd_histogram;
    
    bool              m_initialized;

public:
    //--- Constructor/Destructor
                      CDeterministicSignalStrength(string symbol, ENUM_TIMEFRAMES timeframe,
                                                   CH4BiasFilter* h4_bias, CTradingRegimeManager* regime_manager);
                     ~CDeterministicSignalStrength();
    
    //--- Initialization
    bool              Initialize();
    void              Deinitialize();
    
    //--- Main calculation methods
    bool              UpdateComponents();
    SSignalComponents CalculateSignalStrength(bool is_long, ENUM_TRADING_REGIME regime);
    double            GetTotalSignalStrength(bool is_long, ENUM_TRADING_REGIME regime);
    
    //--- Individual component calculations
    double            CalculateH4BiasScore(bool is_long);
    double            CalculateATRPositionScore();
    double            CalculateMAScore(bool is_long);
    double            CalculateMACDScore(bool is_long);
    
    //--- Validation methods
    bool              MeetsMinimumThreshold(double signal_strength, ENUM_TRADING_REGIME regime);
    
    //--- Information methods
    string            GetComponentBreakdown(const SSignalComponents &components);
    bool              IsInitialized() const { return m_initialized; }

private:
    //--- Internal methods
    bool              UpdateMAValues();
    bool              UpdateMACDValues();
    double            GetRegimeThreshold(ENUM_TRADING_REGIME regime);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDeterministicSignalStrength::CDeterministicSignalStrength(string symbol, ENUM_TIMEFRAMES timeframe,
                                                           CH4BiasFilter* h4_bias, CTradingRegimeManager* regime_manager)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_h4_bias = h4_bias;
    m_regime_manager = regime_manager;
    
    m_ema4_handle = INVALID_HANDLE;
    m_smma6_handle = INVALID_HANDLE;
    m_macd_handle = INVALID_HANDLE;
    
    m_ema4_current = 0.0;
    m_ema4_previous = 0.0;
    m_smma6_current = 0.0;
    m_smma6_previous = 0.0;
    m_macd_histogram = 0.0;
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDeterministicSignalStrength::~CDeterministicSignalStrength()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize signal strength calculator                           |
//+------------------------------------------------------------------+
bool CDeterministicSignalStrength::Initialize()
{
    if(StringLen(m_symbol) == 0 || m_regime_manager == NULL)
    {
        Print("DeterministicSignalStrength: Invalid parameters");
        return false;
    }

    if(m_h4_bias == NULL)
    {
        Print("DeterministicSignalStrength: H4 bias filter not available - will use reduced scoring");
    }
    
    // Create EMA4 indicator
    m_ema4_handle = iMA(m_symbol, m_timeframe, 4, 0, MODE_EMA, PRICE_CLOSE);
    if(m_ema4_handle == INVALID_HANDLE)
    {
        Print("DeterministicSignalStrength: Failed to create EMA4 indicator");
        return false;
    }
    
    // Create SMMA6 indicator (on HLCC/4)
    m_smma6_handle = iMA(m_symbol, m_timeframe, 6, 0, MODE_SMMA, PRICE_TYPICAL);
    if(m_smma6_handle == INVALID_HANDLE)
    {
        Print("DeterministicSignalStrength: Failed to create SMMA6 indicator");
        IndicatorRelease(m_ema4_handle);
        return false;
    }
    
    // Create MACD indicator
    m_macd_handle = iMACD(m_symbol, m_timeframe, 12, 26, 1, PRICE_CLOSE);
    if(m_macd_handle == INVALID_HANDLE)
    {
        Print("DeterministicSignalStrength: Failed to create MACD indicator");
        IndicatorRelease(m_ema4_handle);
        IndicatorRelease(m_smma6_handle);
        return false;
    }
    
    // Wait for indicators to be ready
    Sleep(100);

    // Initial update - try a few times if it fails
    int attempts = 0;
    while(attempts < 3 && !UpdateComponents())
    {
        attempts++;
        Print("DeterministicSignalStrength: Initial update attempt ", attempts, " failed, retrying...");
        Sleep(100);
    }

    if(attempts >= 3)
    {
        Print("DeterministicSignalStrength: Failed to update initial components after 3 attempts - using defaults");
        // Don't fail completely - just use default values
        m_ema4_current = 0.0;
        m_ema4_previous = 0.0;
        m_smma6_current = 0.0;
        m_smma6_previous = 0.0;
        m_macd_histogram = 0.0;
    }
    
    m_initialized = true;
    Print("DeterministicSignalStrength: Initialized successfully");
    
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize signal strength calculator                         |
//+------------------------------------------------------------------+
void CDeterministicSignalStrength::Deinitialize()
{
    if(m_ema4_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ema4_handle);
        m_ema4_handle = INVALID_HANDLE;
    }
    
    if(m_smma6_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_smma6_handle);
        m_smma6_handle = INVALID_HANDLE;
    }
    
    if(m_macd_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_macd_handle);
        m_macd_handle = INVALID_HANDLE;
    }
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Update all components                                            |
//+------------------------------------------------------------------+
bool CDeterministicSignalStrength::UpdateComponents()
{
    // Allow update during initialization (m_initialized may be false)
    return UpdateMAValues() && UpdateMACDValues();
}

//+------------------------------------------------------------------+
//| Calculate complete signal strength                               |
//+------------------------------------------------------------------+
SSignalComponents CDeterministicSignalStrength::CalculateSignalStrength(bool is_long, ENUM_TRADING_REGIME regime)
{
    SSignalComponents components;
    
    if(!m_initialized)
        return components;
    
    // Calculate each component
    components.h4_bias_score = CalculateH4BiasScore(is_long);
    components.atr_position_score = CalculateATRPositionScore();
    components.ma_crossover_score = CalculateMAScore(is_long);
    components.macd_histogram_score = CalculateMACDScore(is_long);
    
    // Calculate total
    components.total_score = components.h4_bias_score + components.atr_position_score + 
                            components.ma_crossover_score + components.macd_histogram_score;
    
    return components;
}

//+------------------------------------------------------------------+
//| Get total signal strength                                        |
//+------------------------------------------------------------------+
double CDeterministicSignalStrength::GetTotalSignalStrength(bool is_long, ENUM_TRADING_REGIME regime)
{
    SSignalComponents components = CalculateSignalStrength(is_long, regime);
    return components.total_score;
}

//+------------------------------------------------------------------+
//| Calculate H4 bias score                                         |
//+------------------------------------------------------------------+
double CDeterministicSignalStrength::CalculateH4BiasScore(bool is_long)
{
    if(m_h4_bias == NULL || !m_h4_bias.IsInitialized())
        return 0.0;
    
    // +0.5 if H4 bias supports direction
    return m_h4_bias.GetBiasScore(is_long);
}

//+------------------------------------------------------------------+
//| Calculate ATR position score                                    |
//+------------------------------------------------------------------+
double CDeterministicSignalStrength::CalculateATRPositionScore()
{
    if(m_regime_manager == NULL)
        return 0.0;
    
    double current_atr = m_regime_manager.GetCurrentATR();
    if(current_atr <= 0)
        return 0.0;
    
    // ATR should be in middle-half of range [12-25] for optimal score
    double optimal_min = 12.0;
    double optimal_max = 25.0;
    double optimal_mid = (optimal_min + optimal_max) / 2.0;
    
    // Calculate distance from optimal middle
    double distance_from_optimal = MathAbs(current_atr - optimal_mid);
    double max_distance = (optimal_max - optimal_min) / 2.0;
    
    // Score decreases with distance from optimal
    double score = 0.3 * (1.0 - (distance_from_optimal / max_distance));
    
    return MathMax(0.0, MathMin(0.3, score));
}

//+------------------------------------------------------------------+
//| Calculate MA crossover score                                    |
//+------------------------------------------------------------------+
double CDeterministicSignalStrength::CalculateMAScore(bool is_long)
{
    // +0.2 if EMA4 > SMMA6 (long) or EMA4 < SMMA6 (short)
    bool ma_supports_direction = is_long ? (m_ema4_current > m_smma6_current) : (m_ema4_current < m_smma6_current);
    
    if(!ma_supports_direction)
        return 0.0;
    
    return 0.2;
}

//+------------------------------------------------------------------+
//| Calculate MACD histogram score                                  |
//+------------------------------------------------------------------+
double CDeterministicSignalStrength::CalculateMACDScore(bool is_long)
{
    // +0.2 if MACD histogram > 0 (long) or < 0 (short)
    bool macd_supports_direction = is_long ? (m_macd_histogram > 0) : (m_macd_histogram < 0);
    
    if(!macd_supports_direction)
        return 0.0;
    
    return 0.2;
}

//+------------------------------------------------------------------+
//| Check if signal meets minimum threshold                         |
//+------------------------------------------------------------------+
bool CDeterministicSignalStrength::MeetsMinimumThreshold(double signal_strength, ENUM_TRADING_REGIME regime)
{
    double threshold = GetRegimeThreshold(regime);
    return signal_strength >= threshold;
}

//+------------------------------------------------------------------+
//| Get regime-specific threshold                                   |
//+------------------------------------------------------------------+
double CDeterministicSignalStrength::GetRegimeThreshold(ENUM_TRADING_REGIME regime)
{
    switch(regime)
    {
        case REGIME_TRENDING:
            return 0.7; // Require ≥0.7 for trend regime
        case REGIME_RANGING:
            return 0.5; // Require ≥0.5 for MR (exits are tight)
        case REGIME_VOLATILE:
            return 0.6; // Require ≥0.6 for US vol
        case REGIME_QUIET:
            return 0.8; // Require ≥0.8 for quiet markets
        default:
            return 0.7; // Default high threshold
    }
}

//+------------------------------------------------------------------+
//| Update MA values                                                |
//+------------------------------------------------------------------+
bool CDeterministicSignalStrength::UpdateMAValues()
{
    double ema4_buffer[2];
    double smma6_buffer[2];

    // Check if handles are valid
    if(m_ema4_handle == INVALID_HANDLE || m_smma6_handle == INVALID_HANDLE)
    {
        Print("DeterministicSignalStrength: Invalid MA handles");
        return false;
    }

    // Get EMA4 values (current and previous)
    int copied = CopyBuffer(m_ema4_handle, 0, 0, 2, ema4_buffer);
    if(copied <= 0)
    {
        Print("DeterministicSignalStrength: Failed to get EMA4 values, error: ", GetLastError());
        return false;
    }

    // Get SMMA6 values (current and previous)
    copied = CopyBuffer(m_smma6_handle, 0, 0, 2, smma6_buffer);
    if(copied <= 0)
    {
        Print("DeterministicSignalStrength: Failed to get SMMA6 values, error: ", GetLastError());
        return false;
    }

    m_ema4_current = ema4_buffer[0];
    m_ema4_previous = ema4_buffer[1];
    m_smma6_current = smma6_buffer[0];
    m_smma6_previous = smma6_buffer[1];

    return true;
}

//+------------------------------------------------------------------+
//| Update MACD values                                              |
//+------------------------------------------------------------------+
bool CDeterministicSignalStrength::UpdateMACDValues()
{
    double macd_main[1];
    double macd_signal[1];

    // Check if handle is valid
    if(m_macd_handle == INVALID_HANDLE)
    {
        Print("DeterministicSignalStrength: Invalid MACD handle");
        return false;
    }

    // Get MACD main line
    int copied = CopyBuffer(m_macd_handle, 0, 0, 1, macd_main);
    if(copied <= 0)
    {
        Print("DeterministicSignalStrength: Failed to get MACD main line, error: ", GetLastError());
        return false;
    }

    // Get MACD signal line
    copied = CopyBuffer(m_macd_handle, 1, 0, 1, macd_signal);
    if(copied <= 0)
    {
        Print("DeterministicSignalStrength: Failed to get MACD signal line, error: ", GetLastError());
        return false;
    }

    // Calculate histogram (main - signal)
    m_macd_histogram = macd_main[0] - macd_signal[0];

    return true;
}

//+------------------------------------------------------------------+
//| Get component breakdown                                          |
//+------------------------------------------------------------------+
string CDeterministicSignalStrength::GetComponentBreakdown(const SSignalComponents &components)
{
    string breakdown = "=== SIGNAL STRENGTH BREAKDOWN ===\n";
    breakdown += StringFormat("H4 Bias Score: %.2f/0.50\n", components.h4_bias_score);
    breakdown += StringFormat("ATR Position Score: %.2f/0.30\n", components.atr_position_score);
    breakdown += StringFormat("MA Crossover Score: %.2f/0.20\n", components.ma_crossover_score);
    breakdown += StringFormat("MACD Histogram Score: %.2f/0.20\n", components.macd_histogram_score);
    breakdown += StringFormat("TOTAL SCORE: %.2f/1.20\n", components.total_score);

    return breakdown;
}
