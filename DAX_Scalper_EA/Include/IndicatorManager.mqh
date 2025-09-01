//+------------------------------------------------------------------+
//|                                            IndicatorManager.mqh |
//|                                  Copyright 2024, Tobias Kjaehr   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Tobias Kjaehr"
#property link      ""
#property version   "1.00"

#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Indicator data structures                                        |
//+------------------------------------------------------------------+
struct SMultiTimeframeMomentum
{
    double weighted_momentum;
    double m1_rsi;
    double m5_rsi;
    double m15_rsi;
    double h1_rsi;
    bool bullish_confluence;
    bool bearish_confluence;

    // Copy constructor
    SMultiTimeframeMomentum(const SMultiTimeframeMomentum& other)
    {
        weighted_momentum = other.weighted_momentum;
        m1_rsi = other.m1_rsi;
        m5_rsi = other.m5_rsi;
        m15_rsi = other.m15_rsi;
        h1_rsi = other.h1_rsi;
        bullish_confluence = other.bullish_confluence;
        bearish_confluence = other.bearish_confluence;
    }

    // Default constructor
    SMultiTimeframeMomentum()
    {
        weighted_momentum = 0.0;
        m1_rsi = 50.0;
        m5_rsi = 50.0;
        m15_rsi = 50.0;
        h1_rsi = 50.0;
        bullish_confluence = false;
        bearish_confluence = false;
    }
};

struct SMarketRegime
{
    double trend_strength;
    double volatility_index;
    double regime_score;
    int regime_type;  // 0=ranging, 1=trending, 2=volatile
    bool is_trending;
    bool is_volatile;

    // Copy constructor
    SMarketRegime(const SMarketRegime& other)
    {
        trend_strength = other.trend_strength;
        volatility_index = other.volatility_index;
        regime_score = other.regime_score;
        regime_type = other.regime_type;
        is_trending = other.is_trending;
        is_volatile = other.is_volatile;
    }

    // Default constructor
    SMarketRegime()
    {
        trend_strength = 50.0;
        volatility_index = 50.0;
        regime_score = 0.0;
        regime_type = 0;
        is_trending = false;
        is_volatile = false;
    }
};

struct SSmartMoneyConcepts
{
    bool bos_bullish;
    bool bos_bearish;
    bool choch_bullish;
    bool choch_bearish;
    bool order_block_bullish;
    bool order_block_bearish;
    bool fvg_bullish;
    bool fvg_bearish;

    // Copy constructor
    SSmartMoneyConcepts(const SSmartMoneyConcepts& other)
    {
        bos_bullish = other.bos_bullish;
        bos_bearish = other.bos_bearish;
        choch_bullish = other.choch_bullish;
        choch_bearish = other.choch_bearish;
        order_block_bullish = other.order_block_bullish;
        order_block_bearish = other.order_block_bearish;
        fvg_bullish = other.fvg_bullish;
        fvg_bearish = other.fvg_bearish;
    }

    // Default constructor
    SSmartMoneyConcepts()
    {
        bos_bullish = false;
        bos_bearish = false;
        choch_bullish = false;
        choch_bearish = false;
        order_block_bullish = false;
        order_block_bearish = false;
        fvg_bullish = false;
        fvg_bearish = false;
    }
};

struct SVolumeProfile
{
    double poc_price;
    double value_area_high;
    double value_area_low;
    bool volume_node_high;
    bool volume_node_low;

    // Copy constructor
    SVolumeProfile(const SVolumeProfile& other)
    {
        poc_price = other.poc_price;
        value_area_high = other.value_area_high;
        value_area_low = other.value_area_low;
        volume_node_high = other.volume_node_high;
        volume_node_low = other.volume_node_low;
    }

    // Default constructor
    SVolumeProfile()
    {
        poc_price = 0.0;
        value_area_high = 0.0;
        value_area_low = 0.0;
        volume_node_high = false;
        volume_node_low = false;
    }
};

struct SMarketMicrostructure
{
    double tick_direction;
    double price_impact;
    double spread_dynamics;
    double tick_velocity;
    bool buy_pressure;
    bool sell_pressure;

    // Copy constructor
    SMarketMicrostructure(const SMarketMicrostructure& other)
    {
        tick_direction = other.tick_direction;
        price_impact = other.price_impact;
        spread_dynamics = other.spread_dynamics;
        tick_velocity = other.tick_velocity;
        buy_pressure = other.buy_pressure;
        sell_pressure = other.sell_pressure;
    }

    // Default constructor
    SMarketMicrostructure()
    {
        tick_direction = 0.0;
        price_impact = 0.0;
        spread_dynamics = 0.0;
        tick_velocity = 0.0;
        buy_pressure = false;
        sell_pressure = false;
    }
};

//+------------------------------------------------------------------+
//| Combined indicator signal structure                              |
//+------------------------------------------------------------------+
struct SIndicatorSignals
{
    SMultiTimeframeMomentum momentum;
    SMarketRegime regime;
    SSmartMoneyConcepts smc;
    SVolumeProfile volume;
    SMarketMicrostructure microstructure;

    // Combined signals
    bool strong_bullish_signal;
    bool strong_bearish_signal;
    bool entry_confirmation;
    bool exit_signal;
    double signal_strength;  // 0.0 to 1.0

    // Copy constructor
    SIndicatorSignals(const SIndicatorSignals& other)
    {
        momentum = other.momentum;
        regime = other.regime;
        smc = other.smc;
        volume = other.volume;
        microstructure = other.microstructure;
        strong_bullish_signal = other.strong_bullish_signal;
        strong_bearish_signal = other.strong_bearish_signal;
        entry_confirmation = other.entry_confirmation;
        exit_signal = other.exit_signal;
        signal_strength = other.signal_strength;
    }

    // Default constructor
    SIndicatorSignals()
    {
        strong_bullish_signal = false;
        strong_bearish_signal = false;
        entry_confirmation = false;
        exit_signal = false;
        signal_strength = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Indicator Manager Class                                          |
//+------------------------------------------------------------------+
class CIndicatorManager
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    CLogger*          m_logger;
    
    // Indicator handles
    int               m_momentum_handle;
    int               m_regime_handle;
    int               m_smc_handle;
    int               m_volume_handle;
    int               m_microstructure_handle;
    
    // Data buffers
    double            m_momentum_data[];
    double            m_regime_data[];
    double            m_smc_data[];
    double            m_volume_data[];
    double            m_microstructure_data[];
    
    // Current signals
    SIndicatorSignals m_current_signals;
    
    // Configuration
    bool              m_use_momentum;
    bool              m_use_regime;
    bool              m_use_smc;
    bool              m_use_volume;
    bool              m_use_microstructure;
    
    double            m_signal_threshold;
    int               m_lookback_bars;
    
public:
    //--- Constructor/Destructor
    CIndicatorManager(string symbol, ENUM_TIMEFRAMES timeframe);
    ~CIndicatorManager();
    
    //--- Initialization
    bool Initialize();
    void Deinitialize();
    
    //--- Configuration
    void SetLogger(CLogger* logger) { m_logger = logger; }
    void SetSignalThreshold(double threshold) { m_signal_threshold = threshold; }
    void SetLookbackBars(int bars) { m_lookback_bars = bars; }
    
    void EnableMomentum(bool enable) { m_use_momentum = enable; }
    void EnableRegime(bool enable) { m_use_regime = enable; }
    void EnableSMC(bool enable) { m_use_smc = enable; }
    void EnableVolume(bool enable) { m_use_volume = enable; }
    void EnableMicrostructure(bool enable) { m_use_microstructure = enable; }
    
    //--- Data retrieval
    bool UpdateSignals();
    SIndicatorSignals GetCurrentSignals() { return m_current_signals; }
    
    //--- Signal analysis
    bool IsBullishSignal();
    bool IsBearishSignal();
    bool IsEntryConfirmed();
    bool IsExitSignal();
    double GetSignalStrength();
    
    //--- Utility functions
    bool AreIndicatorsReady();
    string GetSignalSummary();
    
private:
    //--- Internal methods
    bool CreateIndicatorHandles();
    bool UpdateMomentumData();
    bool UpdateRegimeData();
    bool UpdateSMCData();
    bool UpdateVolumeData();
    bool UpdateMicrostructureData();
    
    void AnalyzeCombinedSignals();
    double CalculateSignalStrength();
    bool ValidateSignalQuality();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CIndicatorManager::CIndicatorManager(string symbol, ENUM_TIMEFRAMES timeframe)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_logger = NULL;
    
    // Initialize handles
    m_momentum_handle = INVALID_HANDLE;
    m_regime_handle = INVALID_HANDLE;
    m_smc_handle = INVALID_HANDLE;
    m_volume_handle = INVALID_HANDLE;
    m_microstructure_handle = INVALID_HANDLE;
    
    // Default configuration - DISABLE ALL PROBLEMATIC INDICATORS
    m_use_momentum = false;      // DISABLE Multi-Timeframe Momentum (PROBLEMATIC)
    m_use_regime = false;        // DISABLE Market Regime Filter (PROBLEMATIC)
    m_use_smc = false;           // DISABLE Smart Money Concepts (PROBLEMATIC)
    m_use_volume = false;        // DISABLE Volume Profile (UNRELIABLE DAX VOLUME)
    m_use_microstructure = false; // DISABLE Microstructure (PROBLEMATIC)
    
    m_signal_threshold = 0.6;  // Reduced back since we have fewer indicators now
    m_lookback_bars = 3;
    
    // Initialize signal structure
    ZeroMemory(m_current_signals);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CIndicatorManager::~CIndicatorManager()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize all indicators                                        |
//+------------------------------------------------------------------+
bool CIndicatorManager::Initialize()
{
    if(m_logger != NULL)
        m_logger.Info("Initializing Indicator Manager for " + m_symbol);
    
    // Create indicator handles
    if(!CreateIndicatorHandles())
    {
        if(m_logger != NULL)
            m_logger.Error("Failed to create indicator handles");
        return false;
    }
    
    // Set array properties
    ArraySetAsSeries(m_momentum_data, true);
    ArraySetAsSeries(m_regime_data, true);
    ArraySetAsSeries(m_smc_data, true);
    ArraySetAsSeries(m_volume_data, true);
    ArraySetAsSeries(m_microstructure_data, true);
    
    if(m_logger != NULL)
        m_logger.Info("Indicator Manager initialized successfully");
    
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize and cleanup                                         |
//+------------------------------------------------------------------+
void CIndicatorManager::Deinitialize()
{
    // Release indicator handles
    if(m_momentum_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_momentum_handle);
        m_momentum_handle = INVALID_HANDLE;
    }
    
    if(m_regime_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_regime_handle);
        m_regime_handle = INVALID_HANDLE;
    }
    
    if(m_smc_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_smc_handle);
        m_smc_handle = INVALID_HANDLE;
    }
    
    if(m_volume_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_volume_handle);
        m_volume_handle = INVALID_HANDLE;
    }
    
    if(m_microstructure_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_microstructure_handle);
        m_microstructure_handle = INVALID_HANDLE;
    }
    
    if(m_logger != NULL)
        m_logger.Info("Indicator Manager deinitialized");
}

//+------------------------------------------------------------------+
//| Create indicator handles                                         |
//+------------------------------------------------------------------+
bool CIndicatorManager::CreateIndicatorHandles()
{
    // Create simple RSI handle instead of complex Multi-Timeframe Momentum
    if(m_use_momentum)
    {
        // Use simple RSI instead of complex multi-timeframe indicator
        m_momentum_handle = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
        if(m_momentum_handle == INVALID_HANDLE)
        {
            if(m_logger != NULL)
                m_logger.Warning("Failed to create RSI indicator handle - continuing without it");
            m_use_momentum = false; // Disable if can't load
        }
        else
        {
            if(m_logger != NULL)
                m_logger.Info("RSI momentum indicator loaded successfully");
        }
    }

    // Create Market Regime Filter handle
    if(m_use_regime)
    {
        m_regime_handle = iCustom(m_symbol, m_timeframe, "DAX_MarketRegimeFilter");
        if(m_regime_handle == INVALID_HANDLE)
        {
            if(m_logger != NULL)
                m_logger.Warning("Failed to create Market Regime Filter indicator handle, using fallback ADX");
            // Fallback to ADX for trend strength
            m_regime_handle = iADX(m_symbol, m_timeframe, 14);
            if(m_regime_handle == INVALID_HANDLE)
            {
                if(m_logger != NULL)
                    m_logger.Error("Failed to create fallback ADX indicator handle");
                return false;
            }
        }
    }

    // Smart Money Concepts handle - DISABLED DUE TO CONFLICTING SIGNALS
    if(m_use_smc)
    {
        if(m_logger != NULL)
            m_logger.Warning("Smart Money Concepts indicator disabled - generates too many conflicting signals");
        m_use_smc = false; // Disable due to signal conflicts
    }

    // Volume Profile handle - DISABLED FOR DAX CASH INDEX
    if(m_use_volume)
    {
        if(m_logger != NULL)
            m_logger.Warning("Volume Profile indicator disabled - not suitable for DAX Cash index");
        m_use_volume = false; // Disable for DAX Cash - volume data is not reliable
    }

    // Create Market Microstructure handle - TEMPORARILY DISABLED FOR PERFORMANCE
    if(m_use_microstructure)
    {
        if(m_logger != NULL)
            m_logger.Warning("Market Microstructure indicator temporarily disabled for performance");
        m_use_microstructure = false; // Disable to avoid performance issues
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check if all indicators are ready                               |
//+------------------------------------------------------------------+
bool CIndicatorManager::AreIndicatorsReady()
{
    // Skip momentum check if disabled
    if(m_use_momentum && m_momentum_handle != INVALID_HANDLE && BarsCalculated(m_momentum_handle) < 10)
        return false;

    if(m_use_regime && BarsCalculated(m_regime_handle) < 10)
        return false;

    // Skip SMC check if disabled
    if(m_use_smc && m_smc_handle != INVALID_HANDLE && BarsCalculated(m_smc_handle) < 10)
        return false;

    // Check volume indicator if enabled
    if(m_use_volume && m_volume_handle != INVALID_HANDLE && BarsCalculated(m_volume_handle) < 10)
        return false;

    // Skip microstructure check if disabled
    if(m_use_microstructure && m_microstructure_handle != INVALID_HANDLE && BarsCalculated(m_microstructure_handle) < 10)
        return false;

    return true;
}

//+------------------------------------------------------------------+
//| Update all indicator signals                                     |
//+------------------------------------------------------------------+
bool CIndicatorManager::UpdateSignals()
{
    if(!AreIndicatorsReady())
    {
        if(m_logger != NULL)
            m_logger.Debug("Indicators not ready yet");
        return false;
    }

    // Clear previous signals
    ZeroMemory(m_current_signals);

    // Update each indicator's data
    bool success = true;

    if(m_use_momentum)
        success &= UpdateMomentumData();

    if(m_use_regime)
        success &= UpdateRegimeData();

    if(m_use_smc)
        success &= UpdateSMCData();

    if(m_use_volume)
        success &= UpdateVolumeData();

    if(m_use_microstructure)
        success &= UpdateMicrostructureData();

    if(success)
    {
        // Analyze combined signals
        AnalyzeCombinedSignals();
    }

    return success;
}

//+------------------------------------------------------------------+
//| Update Multi-Timeframe Momentum data                            |
//+------------------------------------------------------------------+
bool CIndicatorManager::UpdateMomentumData()
{
    // Multi-timeframe momentum temporarily disabled - use fallback values
    if(!m_use_momentum || m_momentum_handle == INVALID_HANDLE)
    {
        // Set neutral/default values
        m_current_signals.momentum.weighted_momentum = 50.0;
        m_current_signals.momentum.m1_rsi = 50.0;
        m_current_signals.momentum.m5_rsi = 50.0;
        m_current_signals.momentum.m15_rsi = 50.0;
        m_current_signals.momentum.h1_rsi = 50.0;
        m_current_signals.momentum.bullish_confluence = false;
        m_current_signals.momentum.bearish_confluence = false;
        return true;
    }

    double weighted_momentum[1], m1_rsi[1], m5_rsi[1], m15_rsi[1], h1_rsi[1];
    double bullish_confluence[1], bearish_confluence[1];

    // Get data from indicator buffers
    if(CopyBuffer(m_momentum_handle, 0, 0, 1, weighted_momentum) != 1) return false;
    if(CopyBuffer(m_momentum_handle, 1, 0, 1, m1_rsi) != 1) return false;
    if(CopyBuffer(m_momentum_handle, 2, 0, 1, m5_rsi) != 1) return false;
    if(CopyBuffer(m_momentum_handle, 3, 0, 1, m15_rsi) != 1) return false;
    if(CopyBuffer(m_momentum_handle, 4, 0, 1, h1_rsi) != 1) return false;
    if(CopyBuffer(m_momentum_handle, 5, 0, 1, bullish_confluence) != 1) return false;
    if(CopyBuffer(m_momentum_handle, 6, 0, 1, bearish_confluence) != 1) return false;

    // Store in signal structure
    m_current_signals.momentum.weighted_momentum = weighted_momentum[0];
    m_current_signals.momentum.m1_rsi = m1_rsi[0];
    m_current_signals.momentum.m5_rsi = m5_rsi[0];
    m_current_signals.momentum.m15_rsi = m15_rsi[0];
    m_current_signals.momentum.h1_rsi = h1_rsi[0];
    m_current_signals.momentum.bullish_confluence = (bullish_confluence[0] != EMPTY_VALUE);
    m_current_signals.momentum.bearish_confluence = (bearish_confluence[0] != EMPTY_VALUE);

    return true;
}

//+------------------------------------------------------------------+
//| Update Market Regime data                                       |
//+------------------------------------------------------------------+
bool CIndicatorManager::UpdateRegimeData()
{
    double trend_strength[1], volatility_index[1], regime_score[1];

    if(CopyBuffer(m_regime_handle, 0, 0, 1, trend_strength) != 1) return false;
    if(CopyBuffer(m_regime_handle, 1, 0, 1, volatility_index) != 1) return false;
    if(CopyBuffer(m_regime_handle, 2, 0, 1, regime_score) != 1) return false;

    m_current_signals.regime.trend_strength = trend_strength[0];
    m_current_signals.regime.volatility_index = volatility_index[0];
    m_current_signals.regime.regime_score = regime_score[0];

    // Determine regime type
    if(trend_strength[0] > 60.0)
        m_current_signals.regime.regime_type = 1; // Trending
    else if(volatility_index[0] > 70.0)
        m_current_signals.regime.regime_type = 2; // Volatile
    else
        m_current_signals.regime.regime_type = 0; // Ranging

    m_current_signals.regime.is_trending = (trend_strength[0] > 60.0);
    m_current_signals.regime.is_volatile = (volatility_index[0] > 70.0);

    return true;
}

//+------------------------------------------------------------------+
//| Update Smart Money Concepts data                                |
//+------------------------------------------------------------------+
bool CIndicatorManager::UpdateSMCData()
{
    // Smart Money Concepts temporarily disabled - use fallback values
    if(!m_use_smc || m_smc_handle == INVALID_HANDLE)
    {
        // Set neutral/default values
        m_current_signals.smc.bos_bullish = false;
        m_current_signals.smc.bos_bearish = false;
        m_current_signals.smc.choch_bullish = false;
        m_current_signals.smc.choch_bearish = false;
        m_current_signals.smc.order_block_bullish = false;
        m_current_signals.smc.order_block_bearish = false;
        m_current_signals.smc.fvg_bullish = false;
        m_current_signals.smc.fvg_bearish = false;
        return true;
    }

    double bos_bullish[1], bos_bearish[1], choch_bullish[1], choch_bearish[1];
    double ob_bullish[1], ob_bearish[1], fvg_bullish[1], fvg_bearish[1];

    if(CopyBuffer(m_smc_handle, 0, 0, 1, bos_bullish) != 1) return false;
    if(CopyBuffer(m_smc_handle, 1, 0, 1, bos_bearish) != 1) return false;
    if(CopyBuffer(m_smc_handle, 2, 0, 1, choch_bullish) != 1) return false;
    if(CopyBuffer(m_smc_handle, 3, 0, 1, choch_bearish) != 1) return false;
    if(CopyBuffer(m_smc_handle, 4, 0, 1, ob_bullish) != 1) return false;
    if(CopyBuffer(m_smc_handle, 5, 0, 1, ob_bearish) != 1) return false;
    if(CopyBuffer(m_smc_handle, 6, 0, 1, fvg_bullish) != 1) return false;
    if(CopyBuffer(m_smc_handle, 7, 0, 1, fvg_bearish) != 1) return false;

    m_current_signals.smc.bos_bullish = (bos_bullish[0] != EMPTY_VALUE);
    m_current_signals.smc.bos_bearish = (bos_bearish[0] != EMPTY_VALUE);
    m_current_signals.smc.choch_bullish = (choch_bullish[0] != EMPTY_VALUE);
    m_current_signals.smc.choch_bearish = (choch_bearish[0] != EMPTY_VALUE);
    m_current_signals.smc.order_block_bullish = (ob_bullish[0] != EMPTY_VALUE);
    m_current_signals.smc.order_block_bearish = (ob_bearish[0] != EMPTY_VALUE);
    m_current_signals.smc.fvg_bullish = (fvg_bullish[0] != EMPTY_VALUE);
    m_current_signals.smc.fvg_bearish = (fvg_bearish[0] != EMPTY_VALUE);

    return true;
}

//+------------------------------------------------------------------+
//| Update Volume Profile data                                      |
//+------------------------------------------------------------------+
bool CIndicatorManager::UpdateVolumeData()
{
    // Volume Profile re-enabled - use real data if available, fallback if not
    if(!m_use_volume || m_volume_handle == INVALID_HANDLE)
    {
        // Set neutral/default values as fallback
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        m_current_signals.volume.poc_price = current_price;
        m_current_signals.volume.value_area_high = current_price + 10.0;
        m_current_signals.volume.value_area_low = current_price - 10.0;
        m_current_signals.volume.volume_node_high = false;
        m_current_signals.volume.volume_node_low = false;
        return true;
    }

    double poc[1], va_high[1], va_low[1], vol_high[1], vol_low[1];

    if(CopyBuffer(m_volume_handle, 0, 0, 1, poc) != 1) return false;
    if(CopyBuffer(m_volume_handle, 1, 0, 1, va_high) != 1) return false;
    if(CopyBuffer(m_volume_handle, 2, 0, 1, va_low) != 1) return false;
    if(CopyBuffer(m_volume_handle, 3, 0, 1, vol_high) != 1) return false;
    if(CopyBuffer(m_volume_handle, 4, 0, 1, vol_low) != 1) return false;

    m_current_signals.volume.poc_price = poc[0];
    m_current_signals.volume.value_area_high = va_high[0];
    m_current_signals.volume.value_area_low = va_low[0];
    m_current_signals.volume.volume_node_high = (vol_high[0] != EMPTY_VALUE);
    m_current_signals.volume.volume_node_low = (vol_low[0] != EMPTY_VALUE);

    return true;
}

//+------------------------------------------------------------------+
//| Update Market Microstructure data                               |
//+------------------------------------------------------------------+
bool CIndicatorManager::UpdateMicrostructureData()
{
    // Market Microstructure temporarily disabled - use fallback values
    if(!m_use_microstructure || m_microstructure_handle == INVALID_HANDLE)
    {
        // Set neutral/default values
        m_current_signals.microstructure.tick_direction = 0.0;
        m_current_signals.microstructure.price_impact = 0.0;
        m_current_signals.microstructure.spread_dynamics = 0.0;
        m_current_signals.microstructure.tick_velocity = 0.0;
        m_current_signals.microstructure.buy_pressure = false;
        m_current_signals.microstructure.sell_pressure = false;
        return true;
    }

    double tick_dir[1], price_impact[1], spread_dyn[1], tick_vel[1];
    double buy_pressure[1], sell_pressure[1];

    if(CopyBuffer(m_microstructure_handle, 0, 0, 1, tick_dir) != 1) return false;
    if(CopyBuffer(m_microstructure_handle, 1, 0, 1, price_impact) != 1) return false;
    if(CopyBuffer(m_microstructure_handle, 2, 0, 1, spread_dyn) != 1) return false;
    if(CopyBuffer(m_microstructure_handle, 3, 0, 1, tick_vel) != 1) return false;
    if(CopyBuffer(m_microstructure_handle, 4, 0, 1, buy_pressure) != 1) return false;
    if(CopyBuffer(m_microstructure_handle, 5, 0, 1, sell_pressure) != 1) return false;

    m_current_signals.microstructure.tick_direction = tick_dir[0];
    m_current_signals.microstructure.price_impact = price_impact[0];
    m_current_signals.microstructure.spread_dynamics = spread_dyn[0];
    m_current_signals.microstructure.tick_velocity = tick_vel[0];
    m_current_signals.microstructure.buy_pressure = (buy_pressure[0] != EMPTY_VALUE);
    m_current_signals.microstructure.sell_pressure = (sell_pressure[0] != EMPTY_VALUE);

    return true;
}

//+------------------------------------------------------------------+
//| Analyze combined signals                                         |
//+------------------------------------------------------------------+
void CIndicatorManager::AnalyzeCombinedSignals()
{
    // Calculate signal strength
    m_current_signals.signal_strength = CalculateSignalStrength();

    // Determine bullish signals
    int bullish_count = 0;
    int total_signals = 0;

    // Momentum signals
    if(m_use_momentum)
    {
        total_signals++;
        if(m_current_signals.momentum.weighted_momentum > 55.0 ||
           m_current_signals.momentum.bullish_confluence)
            bullish_count++;
    }

    // Regime signals
    if(m_use_regime)
    {
        total_signals++;
        if(m_current_signals.regime.is_trending &&
           m_current_signals.regime.regime_score > 0)
            bullish_count++;
    }

    // SMC signals - DISABLED due to conflicting signals
    // Smart Money Concepts generates too many conflicting signals for DAX Cash
    // Relying on Momentum and Regime instead

    // Volume signals
    if(m_use_volume)
    {
        total_signals++;
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(current_price > m_current_signals.volume.poc_price)
            bullish_count++;
    }

    // Microstructure signals
    if(m_use_microstructure)
    {
        total_signals++;
        if(m_current_signals.microstructure.tick_direction > 0 ||
           m_current_signals.microstructure.buy_pressure)
            bullish_count++;
    }

    // Calculate signal ratios
    double bullish_ratio = (total_signals > 0) ? (double)bullish_count / (double)total_signals : 0.0;
    double bearish_ratio = 1.0 - bullish_ratio;

    // Set combined signals
    m_current_signals.strong_bullish_signal = (bullish_ratio >= m_signal_threshold);
    m_current_signals.strong_bearish_signal = (bearish_ratio >= m_signal_threshold);
    m_current_signals.entry_confirmation = ValidateSignalQuality();

    // Exit signals
    m_current_signals.exit_signal = (
        (m_use_momentum && m_current_signals.momentum.bearish_confluence && m_current_signals.strong_bullish_signal) ||
        (m_use_momentum && m_current_signals.momentum.bullish_confluence && m_current_signals.strong_bearish_signal) ||
        (m_use_microstructure && m_current_signals.microstructure.sell_pressure && m_current_signals.strong_bullish_signal) ||
        (m_use_microstructure && m_current_signals.microstructure.buy_pressure && m_current_signals.strong_bearish_signal)
    );
}

//+------------------------------------------------------------------+
//| Calculate overall signal strength                               |
//+------------------------------------------------------------------+
double CIndicatorManager::CalculateSignalStrength()
{
    double strength = 0.0;
    int components = 0;

    // Momentum strength
    if(m_use_momentum)
    {
        components++;
        double momentum_strength = MathAbs(m_current_signals.momentum.weighted_momentum - 50.0) / 50.0;
        if(m_current_signals.momentum.bullish_confluence || m_current_signals.momentum.bearish_confluence)
            momentum_strength += 0.3;
        strength += MathMin(momentum_strength, 1.0);
    }

    // Regime strength
    if(m_use_regime)
    {
        components++;
        double regime_strength = m_current_signals.regime.trend_strength / 100.0;
        strength += regime_strength;
    }

    // SMC strength
    if(m_use_smc)
    {
        components++;
        double smc_strength = 0.0;
        if(m_current_signals.smc.bos_bullish || m_current_signals.smc.bos_bearish) smc_strength += 0.4;
        if(m_current_signals.smc.choch_bullish || m_current_signals.smc.choch_bearish) smc_strength += 0.3;
        if(m_current_signals.smc.order_block_bullish || m_current_signals.smc.order_block_bearish) smc_strength += 0.2;
        if(m_current_signals.smc.fvg_bullish || m_current_signals.smc.fvg_bearish) smc_strength += 0.1;
        strength += MathMin(smc_strength, 1.0);
    }

    // Volume strength
    if(m_use_volume)
    {
        components++;
        double volume_strength = 0.5; // Base strength
        if(m_current_signals.volume.volume_node_high || m_current_signals.volume.volume_node_low)
            volume_strength += 0.3;
        strength += MathMin(volume_strength, 1.0);
    }

    // Microstructure strength
    if(m_use_microstructure)
    {
        components++;
        double micro_strength = MathAbs(m_current_signals.microstructure.tick_direction) / 100.0;
        if(m_current_signals.microstructure.buy_pressure || m_current_signals.microstructure.sell_pressure)
            micro_strength += 0.2;
        strength += MathMin(micro_strength, 1.0);
    }

    return (components > 0) ? strength / (double)components : 0.0;
}

//+------------------------------------------------------------------+
//| Validate signal quality                                          |
//+------------------------------------------------------------------+
bool CIndicatorManager::ValidateSignalQuality()
{
    // Check if we have minimum signal strength - increased threshold
    if(m_current_signals.signal_strength < 0.5)
        return false;

    // Check for conflicting signals
    if(m_current_signals.strong_bullish_signal && m_current_signals.strong_bearish_signal)
        return false;

    // Regime filter - avoid trading in ranging markets if possible
    if(m_use_regime && m_current_signals.regime.regime_type == 0 &&
       m_current_signals.regime.volatility_index < 30.0)
        return false;

    // Additional SMC validation - avoid trading when too many conflicting SMC signals
    if(m_use_smc)
    {
        int total_smc_signals = 0;
        if(m_current_signals.smc.bos_bullish) total_smc_signals++;
        if(m_current_signals.smc.bos_bearish) total_smc_signals++;
        if(m_current_signals.smc.choch_bullish) total_smc_signals++;
        if(m_current_signals.smc.choch_bearish) total_smc_signals++;

        // If too many conflicting SMC signals, avoid trading
        if(total_smc_signals > 2)
            return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Public signal analysis methods                                  |
//+------------------------------------------------------------------+
bool CIndicatorManager::IsBullishSignal()
{
    return m_current_signals.strong_bullish_signal && m_current_signals.entry_confirmation;
}

bool CIndicatorManager::IsBearishSignal()
{
    return m_current_signals.strong_bearish_signal && m_current_signals.entry_confirmation;
}

bool CIndicatorManager::IsEntryConfirmed()
{
    return m_current_signals.entry_confirmation;
}

bool CIndicatorManager::IsExitSignal()
{
    return m_current_signals.exit_signal;
}

double CIndicatorManager::GetSignalStrength()
{
    return m_current_signals.signal_strength;
}

//+------------------------------------------------------------------+
//| Get signal summary string                                        |
//+------------------------------------------------------------------+
string CIndicatorManager::GetSignalSummary()
{
    string summary = "Signals: ";

    if(m_use_momentum)
    {
        summary += StringFormat("MTF=%.1f ", m_current_signals.momentum.weighted_momentum);
        if(m_current_signals.momentum.bullish_confluence) summary += "BULL_CONF ";
        if(m_current_signals.momentum.bearish_confluence) summary += "BEAR_CONF ";
    }

    if(m_use_regime)
    {
        summary += StringFormat("Regime=%d(%.1f) ",
                               m_current_signals.regime.regime_type,
                               m_current_signals.regime.trend_strength);
    }

    if(m_use_smc)
    {
        if(m_current_signals.smc.bos_bullish) summary += "BOS_BULL ";
        if(m_current_signals.smc.bos_bearish) summary += "BOS_BEAR ";
        if(m_current_signals.smc.order_block_bullish) summary += "OB_BULL ";
        if(m_current_signals.smc.order_block_bearish) summary += "OB_BEAR ";
    }

    if(m_use_volume)
    {
        summary += StringFormat("POC=%.1f ", m_current_signals.volume.poc_price);
        if(m_current_signals.volume.volume_node_high) summary += "VOL_HIGH ";
        if(m_current_signals.volume.volume_node_low) summary += "VOL_LOW ";
    }

    if(m_use_microstructure)
    {
        summary += StringFormat("Tick=%.1f ", m_current_signals.microstructure.tick_direction);
        if(m_current_signals.microstructure.buy_pressure) summary += "BUY_PRESS ";
        if(m_current_signals.microstructure.sell_pressure) summary += "SELL_PRESS ";
    }

    summary += StringFormat("Strength=%.2f ", m_current_signals.signal_strength);

    if(m_current_signals.strong_bullish_signal) summary += "STRONG_BULL ";
    if(m_current_signals.strong_bearish_signal) summary += "STRONG_BEAR ";
    if(m_current_signals.entry_confirmation) summary += "ENTRY_OK ";
    if(m_current_signals.exit_signal) summary += "EXIT ";

    return summary;
}
