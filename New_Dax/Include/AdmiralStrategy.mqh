//+------------------------------------------------------------------+
//|                                              AdmiralStrategy.mqh |
//|                           Admiral Pivot Points Strategy Class   |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

#include "AdmiralPivotPoints.mqh"
#include "MACDSignal.mqh"
#include "StochasticSignal.mqh"
#include "MovingAverageSignal.mqh"
#include "SwingPointDetector.mqh"
#include "TradingRegimeManager.mqh"
#include "H4BiasFilter.mqh"
#include "DeterministicSignalStrength.mqh"
#include "PivotZoneManager.mqh"

//+------------------------------------------------------------------+
//| Signal structure                                               |
//+------------------------------------------------------------------+
struct SAdmiralSignal
{
    bool              is_valid;
    bool              is_long;
    double            entry_price;
    double            stop_loss;
    double            take_profit;
    double            signal_strength;
    string            signal_description;

    // Default constructor
    SAdmiralSignal()
    {
        is_valid = false;
        is_long = false;
        entry_price = 0.0;
        stop_loss = 0.0;
        take_profit = 0.0;
        signal_strength = 0.0;
        signal_description = "";
    }

    // Copy constructor
    SAdmiralSignal(const SAdmiralSignal &other)
    {
        is_valid = other.is_valid;
        is_long = other.is_long;
        entry_price = other.entry_price;
        stop_loss = other.stop_loss;
        take_profit = other.take_profit;
        signal_strength = other.signal_strength;
        signal_description = other.signal_description;
    }

    // Assignment operator
    void operator=(const SAdmiralSignal &other)
    {
        is_valid = other.is_valid;
        is_long = other.is_long;
        entry_price = other.entry_price;
        stop_loss = other.stop_loss;
        take_profit = other.take_profit;
        signal_strength = other.signal_strength;
        signal_description = other.signal_description;
    }
};

//+------------------------------------------------------------------+
//| Admiral Strategy Class                                         |
//+------------------------------------------------------------------+
class CAdmiralStrategy
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    ENUM_TIMEFRAMES   m_pivot_timeframe;
    
    // Strategy components
    CAdmiralPivotPoints* m_pivot_points;
    CMACDSignal*      m_macd_signal;
    CStochasticSignal* m_stoch_signal;
    CMovingAverageSignal* m_ma_signal;
    CSwingPointDetector* m_swing_detector;

    // New advanced components
    CTradingRegimeManager* m_regime_manager;
    CH4BiasFilter*    m_h4_bias_filter;
    CDeterministicSignalStrength* m_signal_strength;
    CPivotZoneManager* m_pivot_zone_manager;
    
    // Strategy parameters (legacy - now handled by regime manager)
    double            m_min_signal_strength;
    int               m_stop_loss_buffer_pips;
    bool              m_use_dynamic_stops;
    bool              m_use_pivot_targets;
    bool              m_use_macd_trend;

    // New parameters
    bool              m_use_regime_based_trading;
    bool              m_use_h4_bias_filter;
    bool              m_use_deterministic_signals;
    bool              m_use_pivot_zones;
    
    // Signal data
    SAdmiralSignal    m_current_signal;
    datetime          m_last_signal_time;
    
    bool              m_initialized;

public:
    //--- Constructor/Destructor
                      CAdmiralStrategy(string symbol, ENUM_TIMEFRAMES timeframe, 
                                      ENUM_TIMEFRAMES pivot_timeframe = PERIOD_H1);
                     ~CAdmiralStrategy();
    
    //--- Initialization
    bool              Initialize();
    void              Deinitialize();
    
    //--- Main strategy methods
    bool              UpdateSignals();
    SAdmiralSignal    CheckEntrySignal();
    bool              ShouldExit(bool is_long_position);
    bool              CheckExitConditions(bool is_long_position);
    bool              CheckEarlyExit(bool is_long_position);
    
    //--- Signal analysis methods
    bool              CheckLongEntry();
    bool              CheckShortEntry();
    double            CalculateSignalStrength(bool is_long);

    //--- New regime-based entry methods
    SAdmiralSignal    CheckRegimeBasedEntry(ENUM_TRADING_REGIME regime);
    SAdmiralSignal    CheckTrendRegimeEntry();
    SAdmiralSignal    CheckMeanReversionEntry();
    SAdmiralSignal    CheckUSVolatilityEntry();
    SAdmiralSignal    CheckLegacyEntry();
    
    //--- Position management
    double            CalculateStopLoss(bool is_long, double entry_price);
    double            CalculateTakeProfit(bool is_long, double entry_price);

    //--- Advanced trailing stops
    bool              UpdateTrailingStop(ulong ticket, double entry_price, double current_price);
    double            CalculateTrailingStopLevel(bool is_long, double entry_price, double current_price);
    bool              ShouldMoveToBreakeven(ulong ticket, double entry_price, double current_price);
    
    //--- Configuration methods
    void              SetMinSignalStrength(double strength) { m_min_signal_strength = strength; }
    void              SetStopLossBuffer(int pips) { m_stop_loss_buffer_pips = pips; }
    void              SetUseDynamicStops(bool use_dynamic) { m_use_dynamic_stops = use_dynamic; }
    void              SetUsePivotTargets(bool use_pivot) { m_use_pivot_targets = use_pivot; }
    void              SetUseMACDTrend(bool use_trend) { m_use_macd_trend = use_trend; }

    //--- New configuration methods
    void              SetUseRegimeBasedTrading(bool use_regime) { m_use_regime_based_trading = use_regime; }
    void              SetUseH4BiasFilter(bool use_h4_bias) { m_use_h4_bias_filter = use_h4_bias; }
    void              SetUseDeterministicSignals(bool use_deterministic) { m_use_deterministic_signals = use_deterministic; }
    void              SetUsePivotZones(bool use_zones) { m_use_pivot_zones = use_zones; }
    void              SetUseNewsFilter(bool use_news_filter) { if(m_regime_manager != NULL) m_regime_manager.SetNewsFilter(use_news_filter); }
    
    //--- Information methods
    bool              IsInitialized() const { return m_initialized; }
    SAdmiralSignal    GetCurrentSignal() const { return m_current_signal; }
    string            GetStrategyStatus();
    string            GetDetailedSignalInfo();
    string            GetAdvancedComponentsStatus();

    //--- Component access
    CTradingRegimeManager* GetRegimeManager() const { return m_regime_manager; }

private:
    //--- Internal methods
    bool              InitializeComponents();
    void              DeinitializeComponents();
    bool              ValidateSignal(const SAdmiralSignal &signal);
    void              ResetSignal(SAdmiralSignal &signal);
    double            GetDefaultStopLoss(bool is_long, double entry_price);
    double            GetDefaultTakeProfit(bool is_long, double entry_price);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAdmiralStrategy::CAdmiralStrategy(string symbol, ENUM_TIMEFRAMES timeframe, 
                                  ENUM_TIMEFRAMES pivot_timeframe)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_pivot_timeframe = pivot_timeframe;
    
    // Initialize component pointers
    m_pivot_points = NULL;
    m_macd_signal = NULL;
    m_stoch_signal = NULL;
    m_ma_signal = NULL;
    m_swing_detector = NULL;

    // Initialize new components
    m_regime_manager = NULL;
    m_h4_bias_filter = NULL;
    m_signal_strength = NULL;
    m_pivot_zone_manager = NULL;
    
    // Set default parameters
    m_min_signal_strength = 0.7;
    m_stop_loss_buffer_pips = 7;
    m_use_dynamic_stops = true;
    m_use_pivot_targets = true;
    m_use_macd_trend = false;

    // Set new default parameters
    m_use_regime_based_trading = true;
    m_use_h4_bias_filter = true;
    m_use_deterministic_signals = true;
    m_use_pivot_zones = true;
    
    // Initialize signal data
    ResetSignal(m_current_signal);
    m_last_signal_time = 0;
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAdmiralStrategy::~CAdmiralStrategy()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize strategy                                             |
//+------------------------------------------------------------------+
bool CAdmiralStrategy::Initialize()
{
    if(!InitializeComponents())
    {
        Print("AdmiralStrategy: Failed to initialize components");
        return false;
    }
    
    m_initialized = true;
    Print("AdmiralStrategy: Initialized successfully for ", m_symbol, " on ", EnumToString(m_timeframe));
    Print("AdmiralStrategy: Pivot timeframe: ", EnumToString(m_pivot_timeframe));
    Print("AdmiralStrategy: Min signal strength: ", m_min_signal_strength);
    
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize strategy                                          |
//+------------------------------------------------------------------+
void CAdmiralStrategy::Deinitialize()
{
    DeinitializeComponents();
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Initialize all strategy components                             |
//+------------------------------------------------------------------+
bool CAdmiralStrategy::InitializeComponents()
{
    // Initialize Admiral Pivot Points
    m_pivot_points = new CAdmiralPivotPoints(m_symbol, m_pivot_timeframe);
    if(!m_pivot_points.Initialize())
    {
        Print("AdmiralStrategy: Failed to initialize Pivot Points");
        return false;
    }
    
    // Initialize MACD Signal (12, 26, 1) - As per strategy specification
    m_macd_signal = new CMACDSignal(m_symbol, m_timeframe, 12, 26, 1);
    if(!m_macd_signal.Initialize())
    {
        Print("AdmiralStrategy: Failed to initialize MACD Signal");
        return false;
    }
    
    // Initialize Stochastic Signal (14, 3, 3)
    m_stoch_signal = new CStochasticSignal(m_symbol, m_timeframe, 14, 3, 3);
    if(!m_stoch_signal.Initialize())
    {
        Print("AdmiralStrategy: Failed to initialize Stochastic Signal");
        return false;
    }
    
    // Initialize Moving Average Signal (4 EMA, 6 SMMA)
    m_ma_signal = new CMovingAverageSignal(m_symbol, m_timeframe, 4, 6);
    if(!m_ma_signal.Initialize())
    {
        Print("AdmiralStrategy: Failed to initialize Moving Average Signal");
        return false;
    }
    
    // Initialize Swing Point Detector
    m_swing_detector = new CSwingPointDetector(m_symbol, m_timeframe, 5, 50);
    if(!m_swing_detector.Initialize())
    {
        Print("AdmiralStrategy: Failed to initialize Swing Point Detector");
        return false;
    }

    // Initialize new advanced components
    if(m_use_regime_based_trading)
    {
        m_regime_manager = new CTradingRegimeManager(m_symbol);
        if(!m_regime_manager.Initialize())
        {
            Print("AdmiralStrategy: Failed to initialize Trading Regime Manager");
            return false;
        }
    }

    if(m_use_h4_bias_filter)
    {
        m_h4_bias_filter = new CH4BiasFilter(m_symbol, PERIOD_H4);
        if(!m_h4_bias_filter.Initialize())
        {
            Print("AdmiralStrategy: Failed to initialize H4 Bias Filter - disabling H4 bias");
            delete m_h4_bias_filter;
            m_h4_bias_filter = NULL;
            m_use_h4_bias_filter = false; // Disable H4 bias filter
        }
    }

    if(m_use_deterministic_signals && m_regime_manager != NULL)
    {
        m_signal_strength = new CDeterministicSignalStrength(m_symbol, m_timeframe, m_h4_bias_filter, m_regime_manager);
        if(!m_signal_strength.Initialize())
        {
            Print("AdmiralStrategy: Failed to initialize Deterministic Signal Strength - disabling");
            delete m_signal_strength;
            m_signal_strength = NULL;
            m_use_deterministic_signals = false;
        }
    }

    if(m_use_pivot_zones && m_pivot_points != NULL && m_regime_manager != NULL)
    {
        m_pivot_zone_manager = new CPivotZoneManager(m_symbol, m_timeframe, m_pivot_points, m_regime_manager);
        if(!m_pivot_zone_manager.Initialize())
        {
            Print("AdmiralStrategy: Failed to initialize Pivot Zone Manager - disabling pivot zones");
            delete m_pivot_zone_manager;
            m_pivot_zone_manager = NULL;
            m_use_pivot_zones = false; // Disable pivot zones
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize all strategy components                          |
//+------------------------------------------------------------------+
void CAdmiralStrategy::DeinitializeComponents()
{
    if(m_pivot_points != NULL)
    {
        delete m_pivot_points;
        m_pivot_points = NULL;
    }
    
    if(m_macd_signal != NULL)
    {
        delete m_macd_signal;
        m_macd_signal = NULL;
    }
    
    if(m_stoch_signal != NULL)
    {
        delete m_stoch_signal;
        m_stoch_signal = NULL;
    }
    
    if(m_ma_signal != NULL)
    {
        delete m_ma_signal;
        m_ma_signal = NULL;
    }
    
    if(m_swing_detector != NULL)
    {
        delete m_swing_detector;
        m_swing_detector = NULL;
    }

    // Deinitialize new components
    if(m_regime_manager != NULL)
    {
        delete m_regime_manager;
        m_regime_manager = NULL;
    }

    if(m_h4_bias_filter != NULL)
    {
        delete m_h4_bias_filter;
        m_h4_bias_filter = NULL;
    }

    if(m_signal_strength != NULL)
    {
        delete m_signal_strength;
        m_signal_strength = NULL;
    }

    if(m_pivot_zone_manager != NULL)
    {
        delete m_pivot_zone_manager;
        m_pivot_zone_manager = NULL;
    }
}

//+------------------------------------------------------------------+
//| Update all signals                                             |
//+------------------------------------------------------------------+
bool CAdmiralStrategy::UpdateSignals()
{
    if(!m_initialized)
        return false;
    
    // Update all components
    if(!m_pivot_points.UpdatePivotLevels())
        return false;
    
    if(!m_macd_signal.UpdateSignals())
        return false;
    
    if(!m_stoch_signal.UpdateSignals())
        return false;
    
    if(!m_ma_signal.UpdateSignals())
        return false;
    
    if(!m_swing_detector.UpdateSwingPoints())
        return false;

    // Update new components
    if(m_regime_manager != NULL && !m_regime_manager.UpdateCurrentRegime())
        return false;

    if(m_h4_bias_filter != NULL && !m_h4_bias_filter.UpdateBias())
        return false;

    if(m_signal_strength != NULL && !m_signal_strength.UpdateComponents())
        return false;

    if(m_pivot_zone_manager != NULL && !m_pivot_zone_manager.UpdateZones())
        return false;

    return true;
}

//+------------------------------------------------------------------+
//| Check for entry signal                                        |
//+------------------------------------------------------------------+
SAdmiralSignal CAdmiralStrategy::CheckEntrySignal()
{
    SAdmiralSignal signal;
    ResetSignal(signal);

    if(!m_initialized)
    {
        Print("DEBUG: Strategy not initialized");
        return signal;
    }

    // Update all signals first
    if(!UpdateSignals())
    {
        Print("DEBUG: Failed to update signals");
        return signal;
    }

    // Debug: Print current indicator values with actual values
    double macd_main = m_macd_signal.GetCurrentMACD();
    double stoch_main = m_stoch_signal.GetCurrentMain();
    double ema_value = m_ma_signal.GetCurrentEMA();
    double smma_value = m_ma_signal.GetCurrentSMMA();

    Print("DEBUG: MACD=", m_macd_signal.IsBullishSignal() ? "BULL" : (m_macd_signal.IsBearishSignal() ? "BEAR" : "NEUTRAL"),
          " (", macd_main, ") Stoch=", m_stoch_signal.IsBullishSignal() ? "BULL" : (m_stoch_signal.IsBearishSignal() ? "BEAR" : "NEUTRAL"),
          " (", stoch_main, ") MA=", m_ma_signal.IsBullishSignal() ? "BULL" : (m_ma_signal.IsBearishSignal() ? "BEAR" : "NEUTRAL"),
          " EMA:", ema_value, " SMMA:", smma_value);

    // NEW: Check if regime-based trading is enabled
    if(m_use_regime_based_trading && m_regime_manager != NULL)
    {
        // Check if we can open new trades in current regime
        if(!m_regime_manager.CanOpenNewTrade())
        {
            Print("DEBUG: Cannot open new trade - regime restrictions");
            return signal;
        }

        ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
        if(current_regime == REGIME_NONE)
        {
            Print("DEBUG: No trading regime active");
            return signal;
        }

        // Check regime-specific entry conditions
        signal = CheckRegimeBasedEntry(current_regime);
    }
    else
    {
        // LEGACY: Use old entry logic if regime trading is disabled
        signal = CheckLegacyEntry();
    }

    // Validate signal
    if(signal.is_valid && !ValidateSignal(signal))
    {
        Print("DEBUG: Signal validation failed");
        ResetSignal(signal);
    }

    m_current_signal = signal;
    return signal;
}

//+------------------------------------------------------------------+
//| Check long entry conditions                                   |
//+------------------------------------------------------------------+
bool CAdmiralStrategy::CheckLongEntry()
{
    // Long conditions (ENHANCED WITH H4 BIAS):
    // 1. H4 Bias allows longs (NEW - PRIMARY FILTER)
    // 2. Stochastic > 50
    // 3. EMA > SMMA (Blue MA > Red MA)
    // 4. MACD > 0 OR MACD trending up (if trend mode enabled)

    // NEW: Check H4 bias first (primary filter)
    if(m_use_h4_bias_filter && m_h4_bias_filter != NULL)
    {
        if(!m_h4_bias_filter.IsLongAllowed())
        {
            Print("DEBUG: Long entry blocked by H4 bias filter");
            return false;
        }
    }

    bool stoch_bullish = m_stoch_signal.IsBullishSignal();
    bool ma_bullish = m_ma_signal.IsBullishSignal();
    bool macd_bullish;

    if(m_use_macd_trend)
        macd_bullish = m_macd_signal.IsBullishTrend();
    else
        macd_bullish = m_macd_signal.IsBullishSignal();

    // NEW: Check if price is in middle of nowhere
    if(m_use_pivot_zones && m_pivot_zone_manager != NULL)
    {
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        if(m_pivot_zone_manager.IsInMiddleOfNowhere(current_price))
        {
            Print("DEBUG: Long entry blocked - price in middle of nowhere");
            return false;
        }
    }

    return (stoch_bullish && ma_bullish && macd_bullish);
}

//+------------------------------------------------------------------+
//| Check short entry conditions                                  |
//+------------------------------------------------------------------+
bool CAdmiralStrategy::CheckShortEntry()
{
    // Short conditions (ENHANCED WITH H4 BIAS):
    // 1. H4 Bias allows shorts (NEW - PRIMARY FILTER)
    // 2. Stochastic < 50
    // 3. EMA < SMMA (Blue MA < Red MA)
    // 4. MACD < 0 OR MACD trending down (if trend mode enabled)

    // NEW: Check H4 bias first (primary filter)
    if(m_use_h4_bias_filter && m_h4_bias_filter != NULL)
    {
        if(!m_h4_bias_filter.IsShortAllowed())
        {
            Print("DEBUG: Short entry blocked by H4 bias filter");
            return false;
        }
    }

    bool stoch_bearish = m_stoch_signal.IsBearishSignal();
    bool ma_bearish = m_ma_signal.IsBearishSignal();
    bool macd_bearish;

    if(m_use_macd_trend)
        macd_bearish = m_macd_signal.IsBearishTrend();
    else
        macd_bearish = m_macd_signal.IsBearishSignal();

    // NEW: Check if price is in middle of nowhere
    if(m_use_pivot_zones && m_pivot_zone_manager != NULL)
    {
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(m_pivot_zone_manager.IsInMiddleOfNowhere(current_price))
        {
            Print("DEBUG: Short entry blocked - price in middle of nowhere");
            return false;
        }
    }

    return (stoch_bearish && ma_bearish && macd_bearish);
}

//+------------------------------------------------------------------+
//| Calculate signal strength                                      |
//+------------------------------------------------------------------+
double CAdmiralStrategy::CalculateSignalStrength(bool is_long)
{
    // NEW: Use deterministic signal strength if available
    if(m_use_deterministic_signals && m_signal_strength != NULL && m_regime_manager != NULL)
    {
        ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
        if(current_regime != REGIME_NONE)
        {
            double deterministic_strength = m_signal_strength.GetTotalSignalStrength(is_long, current_regime);
            Print("DEBUG: Using deterministic signal strength = ", deterministic_strength);
            return deterministic_strength;
        }
    }

    // LEGACY: Use old signal strength calculation
    double strength = 0.0;
    int total_indicators = 3;

    if(is_long)
    {
        if(m_stoch_signal.IsBullishSignal()) strength += 1.0;
        if(m_ma_signal.IsBullishSignal()) strength += 1.0;
        if(m_macd_signal.IsBullishSignal()) strength += 1.0;
    }
    else
    {
        if(m_stoch_signal.IsBearishSignal()) strength += 1.0;
        if(m_ma_signal.IsBearishSignal()) strength += 1.0;
        if(m_macd_signal.IsBearishSignal()) strength += 1.0;
    }

    return strength / total_indicators;
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                           |
//+------------------------------------------------------------------+
double CAdmiralStrategy::CalculateStopLoss(bool is_long, double entry_price)
{
    double calculated_sl = 0.0;

    // NEW: Use regime manager for optimal SL if available
    if(m_use_regime_based_trading && m_regime_manager != NULL)
    {
        ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
        if(current_regime != REGIME_NONE)
        {
            calculated_sl = m_regime_manager.GetOptimalStopLoss(current_regime, is_long, entry_price);
            Print("DEBUG SL: Using regime-based SL = ", calculated_sl);
            return calculated_sl; // Return directly - regime manager handles all validation
        }
    }

    // LEGACY: Use old SL calculation if regime trading is disabled
    if(m_use_dynamic_stops && m_swing_detector != NULL)
    {
        double dynamic_sl = m_swing_detector.GetDynamicStopLoss(is_long, entry_price, m_stop_loss_buffer_pips);
        if(dynamic_sl > 0)
        {
            calculated_sl = dynamic_sl;
            Print("DEBUG SL: Using dynamic SL = ", calculated_sl);
        }
    }

    if(calculated_sl <= 0)
    {
        calculated_sl = GetDefaultStopLoss(is_long, entry_price);
        Print("DEBUG SL: Using default SL = ", calculated_sl);
    }

    // SAFETY CHECK: Maximum SL distance in PIPS
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double pip_size = 0.1; // 1 pip for DAX = 0.1 price units
    double sl_distance = MathAbs(entry_price - calculated_sl);
    double max_sl_distance = 50 * pip_size; // Maximum 50 pips SL

    if(sl_distance > max_sl_distance)
    {
        Print("WARNING: SL distance too large (", sl_distance/pip_size, " pips). Limiting to 50 pips.");
        if(is_long)
            calculated_sl = entry_price - max_sl_distance;
        else
            calculated_sl = entry_price + max_sl_distance;
        sl_distance = max_sl_distance;
    }

    Print("FINAL SL: Entry=", entry_price, " SL=", calculated_sl, " Distance=", sl_distance/pip_size, " pips");
    return calculated_sl;
}

//+------------------------------------------------------------------+
//| Calculate take profit                                         |
//+------------------------------------------------------------------+
double CAdmiralStrategy::CalculateTakeProfit(bool is_long, double entry_price)
{
    // NEW: Use regime manager for optimal TP if available
    if(m_use_regime_based_trading && m_regime_manager != NULL)
    {
        ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
        if(current_regime != REGIME_NONE)
        {
            // Need SL to calculate TP
            double sl_price = CalculateStopLoss(is_long, entry_price);
            double calculated_tp = m_regime_manager.GetOptimalTakeProfit(current_regime, is_long, entry_price, sl_price);
            Print("DEBUG TP: Using regime-based TP = ", calculated_tp);
            return calculated_tp;
        }
    }

    // LEGACY: Use old TP calculation if regime trading is disabled
    if(m_use_pivot_targets && m_pivot_points != NULL)
    {
        if(is_long)
            return m_pivot_points.GetNextResistanceLevel(entry_price);
        else
            return m_pivot_points.GetNextSupportLevel(entry_price);
    }

    return GetDefaultTakeProfit(is_long, entry_price);
}

//+------------------------------------------------------------------+
//| Get default stop loss                                         |
//+------------------------------------------------------------------+
double CAdmiralStrategy::GetDefaultStopLoss(bool is_long, double entry_price)
{
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double min_stop_level = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

    // FUCK IT - DIRECT CALCULATION FOR DAX
    // 10 pips = 10.0 price units for DAX (1 pip = 1.0 price unit)
    double sl_distance = 10.0; // HARDCODED 10 pips = 10.0 price units
    double sl_distance_pips = 10.0; // For logging

    Print("DEBUG DEFAULT SL: min_stop_level=", min_stop_level/point, " points, calculated_pips=", sl_distance_pips, " pips");

    Print("DEBUG SL: Default SL distance = ", sl_distance_pips, " pips (", sl_distance, " price units)");

    if(is_long)
        return entry_price - sl_distance;
    else
        return entry_price + sl_distance;
}

//+------------------------------------------------------------------+
//| Get default take profit                                       |
//+------------------------------------------------------------------+
double CAdmiralStrategy::GetDefaultTakeProfit(bool is_long, double entry_price)
{
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double tp_distance = 100 * point; // Default 100 points (2:1 R/R)
    
    if(is_long)
        return entry_price + tp_distance;
    else
        return entry_price - tp_distance;
}

//+------------------------------------------------------------------+
//| Validate signal                                               |
//+------------------------------------------------------------------+
bool CAdmiralStrategy::ValidateSignal(const SAdmiralSignal &signal)
{
    // OPTIMIZED: Use different signal strength thresholds for long vs short
    double required_strength = m_min_signal_strength;

    // Lower threshold for shorts to improve their performance
    if(!signal.is_long)
    {
        // Use fixed 20% lower threshold for shorts (configurable via main EA)
        required_strength = m_min_signal_strength * 0.8; // 20% lower for shorts
    }

    // Check signal strength with direction-specific threshold
    if(signal.signal_strength < required_strength)
    {
        Print("DEBUG: Signal strength too low: ", signal.signal_strength, " < ", required_strength,
              " (", signal.is_long ? "LONG" : "SHORT", " threshold)");
        return false;
    }

    // Check stop loss and take profit levels
    if(signal.stop_loss <= 0 || signal.take_profit <= 0)
    {
        Print("DEBUG: Invalid SL/TP levels: SL=", signal.stop_loss, " TP=", signal.take_profit);
        return false;
    }

    // Check minimum distance between entry and SL/TP
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double min_distance = 10 * point;

    if(signal.is_long)
    {
        double sl_distance = signal.entry_price - signal.stop_loss;
        double tp_distance = signal.take_profit - signal.entry_price;

        if(sl_distance < min_distance)
        {
            Print("DEBUG: LONG SL distance too small: ", sl_distance, " < ", min_distance);
            return false;
        }
        if(tp_distance < min_distance)
        {
            Print("DEBUG: LONG TP distance too small: ", tp_distance, " < ", min_distance);
            return false;
        }
    }
    else
    {
        double sl_distance = signal.stop_loss - signal.entry_price;
        double tp_distance = signal.entry_price - signal.take_profit;

        if(sl_distance < min_distance)
        {
            Print("DEBUG: SHORT SL distance too small: ", sl_distance, " < ", min_distance);
            return false;
        }
        if(tp_distance < min_distance)
        {
            Print("DEBUG: SHORT TP distance too small: ", tp_distance, " < ", min_distance);
            return false;
        }
    }

    Print("DEBUG: Signal validation passed");
    return true;
}

//+------------------------------------------------------------------+
//| Reset signal structure                                        |
//+------------------------------------------------------------------+
void CAdmiralStrategy::ResetSignal(SAdmiralSignal &signal)
{
    signal = SAdmiralSignal(); // Use default constructor
}

//+------------------------------------------------------------------+
//| Get strategy status                                           |
//+------------------------------------------------------------------+
string CAdmiralStrategy::GetStrategyStatus()
{
    if(!m_initialized)
        return "Admiral Strategy: Not initialized";
    
    string status = "Admiral Strategy: ";
    
    if(m_current_signal.is_valid)
    {
        status += StringFormat("%s Signal (Strength: %.2f)", 
                              m_current_signal.is_long ? "LONG" : "SHORT",
                              m_current_signal.signal_strength);
    }
    else
    {
        status += "No signal";
    }
    
    return status;
}

//+------------------------------------------------------------------+
//| Check if should exit position                                  |
//+------------------------------------------------------------------+
bool CAdmiralStrategy::ShouldExit(bool is_long_position)
{
    if(!m_initialized)
        return false;

    // Update signals first
    if(!UpdateSignals())
        return false;

    // Check exit conditions
    return CheckExitConditions(is_long_position) || CheckEarlyExit(is_long_position);
}

//+------------------------------------------------------------------+
//| Check main exit conditions                                     |
//+------------------------------------------------------------------+
bool CAdmiralStrategy::CheckExitConditions(bool is_long_position)
{
    if(is_long_position)
    {
        // Exit long if any indicator turns bearish
        if(m_stoch_signal.IsBearishSignal() ||
           m_ma_signal.IsBearishSignal() ||
           m_macd_signal.IsBearishSignal())
        {
            return true;
        }

        // Exit on strong bearish crossover
        if(m_stoch_signal.IsBearishCrossover() ||
           m_ma_signal.IsBearishCrossover() ||
           m_macd_signal.IsBearishCrossover())
        {
            return true;
        }
    }
    else
    {
        // Exit short if any indicator turns bullish
        if(m_stoch_signal.IsBullishSignal() ||
           m_ma_signal.IsBullishSignal() ||
           m_macd_signal.IsBullishSignal())
        {
            return true;
        }

        // Exit on strong bullish crossover
        if(m_stoch_signal.IsBullishCrossover() ||
           m_ma_signal.IsBullishCrossover() ||
           m_macd_signal.IsBullishCrossover())
        {
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check early exit conditions                                   |
//+------------------------------------------------------------------+
bool CAdmiralStrategy::CheckEarlyExit(bool is_long_position)
{
    // Check if price is near pivot level (potential reversal)
    double current_price = is_long_position ?
                          SymbolInfoDouble(m_symbol, SYMBOL_BID) :
                          SymbolInfoDouble(m_symbol, SYMBOL_ASK);

    if(m_pivot_points.IsPriceNearPivot(current_price, 3.0))
    {
        // If price development is slow near pivot, consider early exit
        // This implements the strategy note: "Hvis prisudviklingen er sløv, kan du tage profit før næste pivot"

        // Check if momentum is weakening
        if(is_long_position)
        {
            if(m_stoch_signal.GetCurrentMain() < 70.0 && // Stoch not strongly bullish
               !m_ma_signal.IsTrendAccelerating(true))    // MA trend not accelerating
            {
                return true;
            }
        }
        else
        {
            if(m_stoch_signal.GetCurrentMain() > 30.0 && // Stoch not strongly bearish
               !m_ma_signal.IsTrendAccelerating(false))   // MA trend not accelerating
            {
                return true;
            }
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Get detailed signal information                               |
//+------------------------------------------------------------------+
string CAdmiralStrategy::GetDetailedSignalInfo()
{
    if(!m_initialized)
        return "Strategy not initialized";

    string info = "=== Admiral Strategy Signal Analysis ===\n";

    // Pivot Points info
    info += m_pivot_points.GetPivotLevelsString() + "\n";

    // Individual indicator signals
    info += m_macd_signal.GetSignalDescription() + "\n";
    info += m_stoch_signal.GetSignalDescription() + "\n";
    info += m_ma_signal.GetSignalDescription() + "\n";

    // Swing points info
    info += m_swing_detector.GetSwingPointsInfo() + "\n";

    // Current signal
    if(m_current_signal.is_valid)
    {
        info += StringFormat("CURRENT SIGNAL: %s | Strength: %.2f | Entry: %.5f | SL: %.5f | TP: %.5f\n",
                            m_current_signal.is_long ? "LONG" : "SHORT",
                            m_current_signal.signal_strength,
                            m_current_signal.entry_price,
                            m_current_signal.stop_loss,
                            m_current_signal.take_profit);
    }
    else
    {
        info += "CURRENT SIGNAL: No valid signal\n";
    }

    return info;
}

//+------------------------------------------------------------------+
//| Check regime-based entry (NEW)                                  |
//+------------------------------------------------------------------+
SAdmiralSignal CAdmiralStrategy::CheckRegimeBasedEntry(ENUM_TRADING_REGIME regime)
{
    SAdmiralSignal signal;

    switch(regime)
    {
        case REGIME_TRENDING:
            signal = CheckTrendRegimeEntry();
            break;
        case REGIME_RANGING:
            signal = CheckMeanReversionEntry();
            break;
        case REGIME_VOLATILE:
            signal = CheckUSVolatilityEntry();
            break;
        case REGIME_QUIET:
            // For quiet regime, use trend logic with stricter requirements
            signal = CheckTrendRegimeEntry();
            break;
        default:
            break;
    }

    // Validate signal with new deterministic strength
    if(signal.is_valid)
    {
        if(m_use_deterministic_signals && m_signal_strength != NULL)
        {
            signal.signal_strength = m_signal_strength.GetTotalSignalStrength(signal.is_long, regime);

            if(!m_signal_strength.MeetsMinimumThreshold(signal.signal_strength, regime))
            {
                Print("DEBUG: Signal strength too low: ", signal.signal_strength);
                ResetSignal(signal);
                return signal;
            }
        }

        // Register trade with regime manager
        if(m_regime_manager != NULL)
        {
            m_regime_manager.RegisterNewTrade();
        }

        // Register zone test if using pivot zones
        if(m_use_pivot_zones && m_pivot_zone_manager != NULL)
        {
            SPivotZone nearest_zone = m_pivot_zone_manager.GetNearestZone();
            if(StringLen(nearest_zone.level_name) > 0)
            {
                // Find zone index and register test
                for(int i = 0; i < 7; i++)
                {
                    SPivotZone zone = m_pivot_zone_manager.GetZoneByIndex(i);
                    if(zone.level_name == nearest_zone.level_name)
                    {
                        m_pivot_zone_manager.RegisterZoneTest(i);
                        break;
                    }
                }
            }
        }
    }

    return signal;
}

//+------------------------------------------------------------------+
//| Check trend regime entry (09:05-11:00)                         |
//+------------------------------------------------------------------+
SAdmiralSignal CAdmiralStrategy::CheckTrendRegimeEntry()
{
    SAdmiralSignal signal;

    // Trend regime: Breakout + Retest strategy
    if(m_use_pivot_zones && m_pivot_zone_manager != NULL)
    {
        // Check for breakout-retest setup
        bool long_retest = m_pivot_zone_manager.IsBreakoutRetestSetup(true);
        bool short_retest = m_pivot_zone_manager.IsBreakoutRetestSetup(false);

        if(long_retest && m_h4_bias_filter != NULL && m_h4_bias_filter.IsLongAllowed())
        {
            signal.is_valid = true;
            signal.is_long = true;
            signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            signal.signal_description = "TREND: Long breakout retest";
        }
        else if(short_retest && m_h4_bias_filter != NULL && m_h4_bias_filter.IsShortAllowed())
        {
            signal.is_valid = true;
            signal.is_long = false;
            signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            signal.signal_description = "TREND: Short breakout retest";
        }
    }

    // Calculate SL and TP using regime manager
    if(signal.is_valid && m_regime_manager != NULL)
    {
        signal.stop_loss = m_regime_manager.GetOptimalStopLoss(REGIME_TRENDING, signal.is_long, signal.entry_price);
        signal.take_profit = m_regime_manager.GetOptimalTakeProfit(REGIME_TRENDING, signal.is_long, signal.entry_price, signal.stop_loss);
    }

    return signal;
}

//+------------------------------------------------------------------+
//| Check mean reversion entry (12:00-14:30)                       |
//+------------------------------------------------------------------+
SAdmiralSignal CAdmiralStrategy::CheckMeanReversionEntry()
{
    SAdmiralSignal signal;

    // Mean reversion: Zone rejection strategy
    if(m_use_pivot_zones && m_pivot_zone_manager != NULL)
    {
        // Check for zone rejection setup
        bool long_rejection = m_pivot_zone_manager.IsZoneRejectionSetup(true);
        bool short_rejection = m_pivot_zone_manager.IsZoneRejectionSetup(false);

        if(long_rejection)
        {
            signal.is_valid = true;
            signal.is_long = true;
            signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            signal.signal_description = "MR: Long zone rejection";
        }
        else if(short_rejection)
        {
            signal.is_valid = true;
            signal.is_long = false;
            signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            signal.signal_description = "MR: Short zone rejection";
        }
    }

    // Calculate SL and TP using regime manager
    if(signal.is_valid && m_regime_manager != NULL)
    {
        signal.stop_loss = m_regime_manager.GetOptimalStopLoss(REGIME_RANGING, signal.is_long, signal.entry_price);
        signal.take_profit = m_regime_manager.GetOptimalTakeProfit(REGIME_RANGING, signal.is_long, signal.entry_price, signal.stop_loss);
    }

    return signal;
}

//+------------------------------------------------------------------+
//| Check US volatility entry (15:30-17:00)                        |
//+------------------------------------------------------------------+
SAdmiralSignal CAdmiralStrategy::CheckUSVolatilityEntry()
{
    SAdmiralSignal signal;

    // US volatility: Momentum bursts with quick BE
    // Use combination of breakout and momentum

    if(m_use_pivot_zones && m_pivot_zone_manager != NULL)
    {
        // Check for momentum setup near zones
        bool long_momentum = m_pivot_zone_manager.IsBreakoutRetestSetup(true) || CheckLongEntry();
        bool short_momentum = m_pivot_zone_manager.IsBreakoutRetestSetup(false) || CheckShortEntry();

        if(long_momentum && m_h4_bias_filter != NULL && m_h4_bias_filter.IsLongAllowed())
        {
            signal.is_valid = true;
            signal.is_long = true;
            signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            signal.signal_description = "US_VOL: Long momentum burst";
        }
        else if(short_momentum && m_h4_bias_filter != NULL && m_h4_bias_filter.IsShortAllowed())
        {
            signal.is_valid = true;
            signal.is_long = false;
            signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            signal.signal_description = "US_VOL: Short momentum burst";
        }
    }

    // Calculate SL and TP using regime manager
    if(signal.is_valid && m_regime_manager != NULL)
    {
        signal.stop_loss = m_regime_manager.GetOptimalStopLoss(REGIME_VOLATILE, signal.is_long, signal.entry_price);
        signal.take_profit = m_regime_manager.GetOptimalTakeProfit(REGIME_VOLATILE, signal.is_long, signal.entry_price, signal.stop_loss);
    }

    return signal;
}

//+------------------------------------------------------------------+
//| Check legacy entry (OLD LOGIC)                                  |
//+------------------------------------------------------------------+
SAdmiralSignal CAdmiralStrategy::CheckLegacyEntry()
{
    SAdmiralSignal signal;

    // Check long entry
    if(CheckLongEntry())
    {
        signal.is_valid = true;
        signal.is_long = true;
        signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        signal.stop_loss = CalculateStopLoss(true, signal.entry_price);
        signal.take_profit = CalculateTakeProfit(true, signal.entry_price);
        signal.signal_strength = CalculateSignalStrength(true);
        signal.signal_description = "LEGACY: LONG conditions met";
        Print("DEBUG: LONG signal detected with strength: ", signal.signal_strength);
    }
    // Check short entry
    else if(CheckShortEntry())
    {
        signal.is_valid = true;
        signal.is_long = false;
        signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        signal.stop_loss = CalculateStopLoss(false, signal.entry_price);
        signal.take_profit = CalculateTakeProfit(false, signal.entry_price);
        signal.signal_strength = CalculateSignalStrength(false);
        signal.signal_description = "LEGACY: SHORT conditions met";
        Print("DEBUG: SHORT signal detected with strength: ", signal.signal_strength);
    }

    // Validate signal before returning
    if(signal.is_valid && !ValidateSignal(signal))
    {
        Print("DEBUG: Signal validation failed");
        ResetSignal(signal);
    }

    return signal;
}

//+------------------------------------------------------------------+
//| Get advanced components status                                   |
//+------------------------------------------------------------------+
string CAdmiralStrategy::GetAdvancedComponentsStatus()
{
    string status = "=== ADVANCED COMPONENTS STATUS ===\n";

    // Regime Manager Status
    if(m_use_regime_based_trading && m_regime_manager != NULL)
    {
        status += m_regime_manager.GetTradingStatistics();
        status += "\n=== SEASONAL ADJUSTMENTS ===\n";
        status += m_regime_manager.GetSeasonalDescription() + "\n";
        status += "\n=== VOLATILITY ADJUSTMENTS ===\n";
        status += m_regime_manager.GetVolatilityDescription() + "\n";
        status += "\n=== TRAILING STOPS ===\n";
        status += m_regime_manager.GetTrailingStopDescription() + "\n";
    }
    else
    {
        status += "Regime-Based Trading: DISABLED\n";
    }

    // H4 Bias Filter Status
    if(m_use_h4_bias_filter && m_h4_bias_filter != NULL)
    {
        status += m_h4_bias_filter.GetDetailedInfo();
    }
    else
    {
        status += "H4 Bias Filter: DISABLED\n";
    }

    // Signal Strength Status
    if(m_use_deterministic_signals && m_signal_strength != NULL)
    {
        status += "Deterministic Signal Strength: ENABLED\n";
        if(m_regime_manager != NULL)
        {
            ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
            if(current_regime != REGIME_NONE)
            {
                SSignalComponents components = m_signal_strength.CalculateSignalStrength(true, current_regime);
                status += m_signal_strength.GetComponentBreakdown(components);
            }
        }
    }
    else
    {
        status += "Deterministic Signal Strength: DISABLED\n";
    }

    // Pivot Zone Manager Status
    if(m_use_pivot_zones && m_pivot_zone_manager != NULL)
    {
        status += m_pivot_zone_manager.GetZoneAnalysis();
    }
    else
    {
        status += "Pivot Zones: DISABLED\n";
    }

    return status;
}

//+------------------------------------------------------------------+
//| Update trailing stop for position                               |
//+------------------------------------------------------------------+
bool CAdmiralStrategy::UpdateTrailingStop(ulong ticket, double entry_price, double current_price)
{
    if(!PositionSelectByTicket(ticket))
        return false;

    bool is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    double current_sl = PositionGetDouble(POSITION_SL);
    double current_profit_r = 0.0;

    // Calculate current profit in R
    double sl_distance = MathAbs(entry_price - current_sl);
    if(sl_distance > 0)
    {
        if(is_long)
            current_profit_r = (current_price - entry_price) / sl_distance;
        else
            current_profit_r = (entry_price - current_price) / sl_distance;
    }

    // Get regime-based trailing parameters
    if(m_regime_manager == NULL)
        return false;

    ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();

    // Check if we should activate trailing
    if(!m_regime_manager.ShouldActivateTrailing(current_regime, current_profit_r))
        return false;

    // Calculate new trailing stop level
    double new_sl = CalculateTrailingStopLevel(is_long, entry_price, current_price);

    // Check if new SL is better than current
    bool should_update = false;
    if(is_long && new_sl > current_sl)
        should_update = true;
    else if(!is_long && new_sl < current_sl)
        should_update = true;

    if(!should_update)
        return false;

    // Update stop loss
    CTrade trade;
    if(trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP)))
    {
        Print("TRAILING: Updated SL for ticket ", ticket, " from ", current_sl, " to ", new_sl,
              " (Profit: ", current_profit_r, "R)");
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Calculate trailing stop level                                   |
//+------------------------------------------------------------------+
double CAdmiralStrategy::CalculateTrailingStopLevel(bool is_long, double entry_price, double current_price)
{
    if(m_regime_manager == NULL)
        return 0.0;

    ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();

    // Calculate current profit in R
    double original_sl = is_long ? entry_price - 10.0 : entry_price + 10.0; // Assume 10-point original SL
    double sl_distance = MathAbs(entry_price - original_sl);
    double current_profit_r = 0.0;

    if(sl_distance > 0)
    {
        if(is_long)
            current_profit_r = (current_price - entry_price) / sl_distance;
        else
            current_profit_r = (entry_price - current_price) / sl_distance;
    }

    // Get trailing distance from regime manager
    double trail_distance_r = m_regime_manager.GetTrailingStopDistance(current_regime, current_profit_r);
    double trail_distance_points = trail_distance_r * sl_distance;

    // Calculate new SL level
    double new_sl;
    if(is_long)
        new_sl = current_price - trail_distance_points;
    else
        new_sl = current_price + trail_distance_points;

    // Ensure we don't move SL against us
    if(is_long)
        new_sl = MathMax(new_sl, entry_price); // Never below entry for longs
    else
        new_sl = MathMin(new_sl, entry_price); // Never above entry for shorts

    return new_sl;
}

//+------------------------------------------------------------------+
//| Check if position should move to breakeven                      |
//+------------------------------------------------------------------+
bool CAdmiralStrategy::ShouldMoveToBreakeven(ulong ticket, double entry_price, double current_price)
{
    if(!PositionSelectByTicket(ticket))
        return false;

    if(m_regime_manager == NULL)
        return false;

    bool is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    double current_sl = PositionGetDouble(POSITION_SL);

    // Check if already at breakeven
    if(is_long && current_sl >= entry_price)
        return false;
    if(!is_long && current_sl <= entry_price)
        return false;

    // Calculate current profit in R
    double sl_distance = MathAbs(entry_price - current_sl);
    double current_profit_r = 0.0;

    if(sl_distance > 0)
    {
        if(is_long)
            current_profit_r = (current_price - entry_price) / sl_distance;
        else
            current_profit_r = (entry_price - current_price) / sl_distance;
    }

    ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
    double breakeven_threshold = m_regime_manager.GetBreakevenThreshold(current_regime);

    return current_profit_r >= breakeven_threshold;
}
