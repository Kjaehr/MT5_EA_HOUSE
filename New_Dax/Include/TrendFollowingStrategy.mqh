//+------------------------------------------------------------------+
//|                                      TrendFollowingStrategy.mqh |
//|                           Enhanced Trend Following Strategy      |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "2.00"

#include "StrategyBase.mqh"
#include "MACDSignal.mqh"
#include "TradingRegimeManager.mqh"
#include "H4BiasFilter.mqh"

//+------------------------------------------------------------------+
//| Enhanced Trend Following Strategy Parameters                    |
//+------------------------------------------------------------------+
struct STrendFollowingParams
{
    // EMA Parameters
    int               ema_fast_period;         // Fast EMA period (default 8)
    int               ema_slow_period;         // Slow EMA period (default 21)

    // ADX Parameters
    int               adx_period;              // ADX period (default 14)
    double            adx_threshold;           // ADX threshold for strong trend (default 25)

    // MACD Parameters
    int               macd_fast_ema;           // MACD fast EMA (default 12)
    int               macd_slow_ema;           // MACD slow EMA (default 26)
    int               macd_signal;             // MACD signal period (default 9)
    bool              use_macd_confirmation;   // Enable MACD confirmation (default true)
    bool              use_macd_trend_mode;     // Use MACD trend mode vs signal mode

    // ATR Parameters
    int               atr_period;              // ATR period (default 14)
    double            atr_sl_multiplier;       // ATR multiplier for stop loss (default 2.5)
    double            atr_tp_multiplier;       // ATR multiplier for take profit (default 4.0)

    // Trend Parameters
    double            min_trend_strength;      // Minimum trend strength (0.0-1.0)
    bool              use_pullback_entries;    // Allow entries on pullbacks
    double            pullback_threshold;      // Pullback threshold (0.0-1.0)
    bool              require_price_above_both_emas; // Require price above/below BOTH EMAs (strict mode)
    bool              allow_ema_crossover_entries;   // Allow entries when price between EMAs but EMAs crossed

    // Multi-Timeframe Parameters
    bool              use_mtf_bias_filter;     // Enable multi-timeframe bias filter
    ENUM_TIMEFRAMES   mtf_timeframe;           // Higher timeframe for bias (default H4)
    double            mtf_bias_strength_min;   // Minimum bias strength required (0.0-1.0)
    bool              allow_against_bias;      // Allow trades against MTF bias

    // Market Regime Parameters
    bool              use_regime_detection;    // Enable market regime detection
    bool              use_regime_based_sizing; // Enable regime-based position sizing
    bool              use_regime_based_stops;  // Enable regime-based stop/target levels

    // Advanced Risk Management
    bool              use_dynamic_sizing;      // Enable dynamic position sizing
    double            base_risk_percent;       // Base risk per trade (default 1.0%)
    double            max_risk_percent;        // Maximum risk per trade (default 2.0%)
    bool              use_correlation_filter;  // Enable correlation-based position limits
    double            max_correlation;         // Maximum allowed correlation (default 0.7)
    bool              use_drawdown_protection; // Enable drawdown-based position reduction
    double            max_drawdown_percent;    // Maximum drawdown before reduction (default 10%)

    // Breakout Parameters
    bool              enable_breakout_logic;   // Enable breakout continuation logic
    double            breakout_atr_multiplier; // ATR multiplier for breakout detection (default 1.5)
    double            breakout_sl_multiplier;  // Tighter SL for breakout trades (default 1.5)
    double            fib_382_level;           // 38.2% Fibonacci retracement level
    double            fib_50_level;            // 50% Fibonacci retracement level
    int               rsi_period;              // RSI period for momentum confirmation
    double            rsi_oversold;            // RSI oversold level
    double            rsi_overbought;          // RSI overbought level

    // Trading Hours Parameters
    int               start_hour;              // Trading start hour (0-23)
    int               end_hour;                // Trading end hour (0-23)
    bool              trade_on_friday;         // Allow trading on Friday
    
    // Constructor
    STrendFollowingParams()
    {
        ema_fast_period = 8;
        ema_slow_period = 21;
        adx_period = 14;
        adx_threshold = 18.0;              // Lowered for more trades
        macd_fast_ema = 12;
        macd_slow_ema = 26;
        macd_signal = 9;
        use_macd_confirmation = false;     // Disable MACD confirmation for more trades
        use_macd_trend_mode = false;       // Use signal mode by default
        atr_period = 14;
        atr_sl_multiplier = 2.5;
        atr_tp_multiplier = 4.0;
        min_trend_strength = 0.35;         // Lowered for more trades
        use_pullback_entries = false;      // Disable pullback entries for immediate entries
        pullback_threshold = 0.3;
        require_price_above_both_emas = false; // More flexible by default
        allow_ema_crossover_entries = true;    // Allow entries between EMAs

        // Multi-timeframe parameters
        use_mtf_bias_filter = true;        // Enable MTF bias filter
        mtf_timeframe = PERIOD_D1;         // Use D1 for bias (changed from H4)
        mtf_bias_strength_min = 0.1;       // Minimum bias strength (lowered)
        allow_against_bias = true;         // Allow trades against bias

        // Market regime parameters
        use_regime_detection = false;      // Disable regime detection for more trades
        use_regime_based_sizing = false;   // Disable regime-based sizing
        use_regime_based_stops = false;    // Disable regime-based stops

        // Advanced risk management
        use_dynamic_sizing = true;         // Enable dynamic sizing
        base_risk_percent = 1.0;           // Base risk 1%
        max_risk_percent = 2.0;            // Max risk 2%
        use_correlation_filter = true;     // Enable correlation filter
        max_correlation = 0.7;             // Max 70% correlation
        use_drawdown_protection = true;    // Enable drawdown protection
        max_drawdown_percent = 10.0;       // Max 10% drawdown

        // Breakout parameters
        enable_breakout_logic = true;      // Enable breakout logic
        breakout_atr_multiplier = 1.5;
        breakout_sl_multiplier = 1.5;
        fib_382_level = 0.382;
        fib_50_level = 0.5;
        rsi_period = 14;
        rsi_oversold = 30.0;
        rsi_overbought = 70.0;

        // Trading hours defaults
        start_hour = 8;
        end_hour = 20;
        trade_on_friday = false;
    }
};

//+------------------------------------------------------------------+
//| Trend Following Strategy Class                                  |
//+------------------------------------------------------------------+
class CTrendFollowingStrategy : public CStrategyBase
{
private:
    // Strategy parameters
    STrendFollowingParams m_params;

    // Enhanced components
    CMACDSignal*      m_macd_signal;           // Enhanced MACD signal component
    CH4BiasFilter*    m_mtf_bias_filter;       // Multi-timeframe bias filter

    // Indicator handles
    int               m_ema_fast_handle;       // Fast EMA handle
    int               m_ema_slow_handle;       // Slow EMA handle
    int               m_adx_handle;            // ADX handle
    int               m_atr_handle;            // ATR handle
    int               m_rsi_handle;            // RSI handle for breakout confirmation

    // Indicator buffers
    double            m_ema_fast_buffer[];     // Fast EMA values
    double            m_ema_slow_buffer[];     // Slow EMA values
    double            m_adx_buffer[];          // ADX values
    double            m_atr_buffer[];          // ATR values
    double            m_rsi_buffer[];          // RSI values
    
    // Trend state
    int               m_current_trend;         // 1=uptrend, -1=downtrend, 0=no trend
    double            m_trend_strength;        // Current trend strength (0.0-1.0)
    datetime          m_last_trend_change;     // Last trend change time

    // Breakout state
    bool              m_breakout_detected;     // Breakout currently detected
    bool              m_waiting_for_pullback;  // Waiting for pullback after breakout
    double            m_breakout_high;         // High of the breakout move
    double            m_breakout_low;          // Low of the breakout move
    double            m_breakout_start_price;  // Price where breakout started
    datetime          m_breakout_time;         // Time of breakout detection
    bool              m_breakout_is_long;      // Direction of breakout

    // Enhanced risk management state
    double            m_current_portfolio_risk; // Current portfolio risk exposure
    double            m_current_drawdown;      // Current drawdown percentage
    double            m_peak_equity;           // Peak equity for drawdown calculation
    int               m_consecutive_losses;    // Consecutive losing trades
    datetime          m_last_trade_time;       // Last trade time for correlation checks
    
public:
    //--- Constructor/Destructor
                      CTrendFollowingStrategy(string symbol, ENUM_TIMEFRAMES timeframe);
                     ~CTrendFollowingStrategy();
    
    //--- Strategy Interface Implementation
    virtual bool      Initialize() override;
    virtual void      Deinitialize() override;
    virtual bool      UpdateSignals() override;
    virtual SStrategySignal CheckEntrySignal() override;
    virtual bool      ShouldExit(bool is_long_position) override;
    
    //--- Configuration Methods
    void              SetTrendParams(const STrendFollowingParams& params) { m_params = params; }
    STrendFollowingParams GetTrendParams() const { return m_params; }

    //--- Information Methods
    int               GetCurrentTrend() const { return m_current_trend; }
    double            GetTrendStrength() const { return m_trend_strength; }
    virtual string    GetStrategyInfo() override;

    //--- Enhanced Component Access
    CTradingRegimeManager* GetRegimeManager() const { return m_regime_manager; }
    CH4BiasFilter*    GetMTFBiasFilter() const { return m_mtf_bias_filter; }
    CMACDSignal*      GetMACDSignal() const { return m_macd_signal; }

protected:
    //--- Enhanced calculations (override base class methods)
    virtual double    CalculateStopLoss(bool is_long, double entry_price) override;
    virtual double    CalculateTakeProfit(bool is_long, double entry_price, double stop_loss) override;

private:
    //--- Enhanced Component Management
    bool              InitializeEnhancedComponents();
    void              DeinitializeEnhancedComponents();
    bool              UpdateEnhancedComponents();
    bool              UpdateDynamicRegime();

    //--- Internal Methods
    bool              InitializeIndicators();
    void              DeinitializeIndicators();
    bool              UpdateIndicatorBuffers();
    
    //--- Trend Analysis
    void              AnalyzeTrend();
    double            CalculateTrendStrength();
    bool              IsStrongTrend();
    
    //--- Enhanced Entry Conditions
    bool              CheckLongTrendConditions();
    bool              CheckShortTrendConditions();
    bool              CheckEnhancedMACDConfirmation(bool is_long);
    bool              CheckMTFBiasAlignment(bool is_long);
    bool              CheckRegimeBasedEntry(bool is_long);
    bool              CheckPullbackEntry(bool is_long);
    bool              CheckBreakoutMomentum(bool is_long);

    //--- Breakout Logic
    void              DetectBreakouts();
    bool              IsSignificantBreakout(bool is_long);
    bool              CheckBreakoutPullback(bool is_long);
    bool              CheckRSIMomentumConfirmation(bool is_long);
    double            CalculateFibonacciLevel(double high, double low, double fib_level);
    void              ResetBreakoutState();

    //--- Trading Hours
    bool              IsWithinTradingHours();
    
    //--- Enhanced Signal Strength
    double            CalculateSignalStrength(bool is_long);
    double            GetEMACrossoverStrength(bool is_long);
    double            GetADXStrength();
    double            GetEnhancedMACDStrength(bool is_long);
    double            GetMTFBiasStrength(bool is_long);
    double            GetRegimeStrength(bool is_long);
    double            GetMomentumStrength(bool is_long);

    //--- Enhanced Risk Management
    double            CalculateDynamicPositionSize(double signal_strength, bool is_long);
    bool              CheckCorrelationLimits();
    bool              CheckDrawdownProtection();
    void              UpdateRiskMetrics();
    double            CalculateSwingBasedStopLoss(bool is_long, double entry_price);

    //--- Utility Methods
    double            GetATRValue();
    bool              ValidateTrendSignal(const SStrategySignal& signal);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrendFollowingStrategy::CTrendFollowingStrategy(string symbol, ENUM_TIMEFRAMES timeframe)
    : CStrategyBase("Enhanced Trend Following", symbol, timeframe)
{
    // Initialize parameters with defaults
    m_params = STrendFollowingParams();

    // Initialize enhanced components
    m_macd_signal = NULL;
    m_mtf_bias_filter = NULL;

    // Initialize indicator handles
    m_ema_fast_handle = INVALID_HANDLE;
    m_ema_slow_handle = INVALID_HANDLE;
    m_adx_handle = INVALID_HANDLE;
    m_atr_handle = INVALID_HANDLE;
    m_rsi_handle = INVALID_HANDLE;

    // Initialize trend state
    m_current_trend = 0;
    m_trend_strength = 0.0;
    m_last_trend_change = 0;

    // Initialize breakout state
    m_breakout_detected = false;
    m_waiting_for_pullback = false;
    m_breakout_high = 0.0;
    m_breakout_low = 0.0;
    m_breakout_start_price = 0.0;
    m_breakout_time = 0;
    m_breakout_is_long = false;

    // Initialize enhanced risk management state
    m_current_portfolio_risk = 0.0;
    m_current_drawdown = 0.0;
    m_peak_equity = 0.0;
    m_consecutive_losses = 0;
    m_last_trade_time = 0;
    
    // Set array properties
    ArraySetAsSeries(m_ema_fast_buffer, true);
    ArraySetAsSeries(m_ema_slow_buffer, true);
    ArraySetAsSeries(m_adx_buffer, true);
    ArraySetAsSeries(m_atr_buffer, true);
    ArraySetAsSeries(m_rsi_buffer, true);

    Print("Enhanced TrendFollowingStrategy: Created for ", symbol, " on ", EnumToString(timeframe));
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrendFollowingStrategy::~CTrendFollowingStrategy()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize Strategy                                             |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::Initialize()
{
    Print("Enhanced TrendFollowingStrategy: Initializing...");

    if(!InitializeIndicators())
    {
        Print("Enhanced TrendFollowingStrategy: Failed to initialize indicators");
        return false;
    }

    if(!InitializeEnhancedComponents())
    {
        Print("Enhanced TrendFollowingStrategy: Failed to initialize enhanced components");
        return false;
    }

    // Set enhanced strategy-specific risk parameters (optimized for more trades)
    m_risk_params.min_signal_strength = 0.45;  // Lowered for more trades
    m_risk_params.max_risk_per_trade = m_params.max_risk_percent;
    m_risk_params.stop_loss_buffer_pips = 5.0;
    m_risk_params.take_profit_ratio = 1.6; // Will be overridden by regime-based calculation
    m_risk_params.use_dynamic_stops = true;
    m_risk_params.use_trailing_stops = true;
    m_risk_params.trailing_start_ratio = 1.5;
    m_risk_params.trailing_step_pips = 10.0;
    m_risk_params.max_trades_per_day = 50; // Much higher limit for trend following

    // Initialize risk metrics
    UpdateRiskMetrics();

    // CRITICAL: Disable StrategyBase regime manager to prevent interference
    // TrendFollowingStrategy handles its own regime logic
    SetRegimeManager(NULL);
    Print("Enhanced TrendFollowingStrategy: StrategyBase regime manager DISABLED");

    m_initialized = true;
    Print("Enhanced TrendFollowingStrategy: Initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize Strategy                                          |
//+------------------------------------------------------------------+
void CTrendFollowingStrategy::Deinitialize()
{
    if(!m_initialized)
        return;

    Print("Enhanced TrendFollowingStrategy: Deinitializing...");
    DeinitializeIndicators();
    DeinitializeEnhancedComponents();
    m_initialized = false;
    Print("Enhanced TrendFollowingStrategy: Deinitialized");
}

//+------------------------------------------------------------------+
//| Update Signals                                                 |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::UpdateSignals()
{
    if(!m_initialized)
        return false;

    // Try to update indicator buffers, but don't fail completely if they're not ready yet
    static int update_attempts = 0;
    if(!UpdateIndicatorBuffers())
    {
        update_attempts++;
        if(update_attempts < 10) // Allow up to 10 attempts
        {
            Print("Enhanced TrendFollowingStrategy: UpdateSignals - Indicators not ready, attempt ", update_attempts);
            return false; // Try again next tick
        }
        else
        {
            Print("Enhanced TrendFollowingStrategy: UpdateSignals - Using fallback mode after ", update_attempts, " attempts");
            // Continue with fallback values - don't fail completely
            update_attempts = 0; // Reset counter
        }
    }
    else
    {
        update_attempts = 0; // Reset counter on success
    }

    // Update enhanced components
    if(!UpdateEnhancedComponents())
    {
        Print("Enhanced TrendFollowingStrategy: Warning - Enhanced components update failed");
        // Continue anyway - don't fail completely
    }

    // Analyze current trend
    AnalyzeTrend();

    // Detect breakouts if enabled
    if(m_params.enable_breakout_logic)
    {
        DetectBreakouts();
    }

    // Update risk metrics
    UpdateRiskMetrics();

    return true;
}

//+------------------------------------------------------------------+
//| Update Enhanced Components                                       |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::UpdateEnhancedComponents()
{
    bool success = true;

    // Update MACD Signal
    if(m_macd_signal != NULL && !m_macd_signal.UpdateSignals())
    {
        Print("Enhanced TrendFollowingStrategy: MACD Signal update failed");
        success = false;
    }

    // Update Trading Regime Manager (Dynamic regime detection for trend following)
    if(m_regime_manager != NULL)
    {
        // For trend following, we use dynamic regime detection based on market conditions
        // instead of fixed time-based regimes
        if(!UpdateDynamicRegime())
        {
            Print("Enhanced TrendFollowingStrategy: Dynamic regime update failed");
            success = false;
        }
    }

    // Update MTF Bias Filter
    if(m_mtf_bias_filter != NULL && !m_mtf_bias_filter.UpdateBias())
    {
        Print("Enhanced TrendFollowingStrategy: MTF Bias Filter update failed");
        success = false;
    }

    return success;
}

//+------------------------------------------------------------------+
//| Update Dynamic Regime (Market-based, not time-based)          |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::UpdateDynamicRegime()
{
    if(m_regime_manager == NULL)
        return true;

    // For trend following, determine regime based on market conditions, not time
    ENUM_TRADING_REGIME dynamic_regime = REGIME_TRENDING; // Default to trending for trend following

    // Analyze current market conditions
    double adx_value = (ArraySize(m_adx_buffer) > 0) ? m_adx_buffer[0] : 0.0;
    double atr_value = GetATRValue();

    // Determine regime based on market conditions
    if(adx_value > 25.0) // Strong trend
    {
        dynamic_regime = REGIME_TRENDING;
    }
    else if(adx_value < 15.0) // Weak trend/ranging
    {
        dynamic_regime = REGIME_RANGING;
    }
    else if(atr_value > 0 && atr_value > GetATRValue() * 1.5) // High volatility
    {
        dynamic_regime = REGIME_VOLATILE;
    }
    else
    {
        dynamic_regime = REGIME_TRENDING; // Default for trend following
    }

    // Set the regime directly instead of using time-based detection
    ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
    if(dynamic_regime != current_regime)
    {
        Print("Enhanced TrendFollowingStrategy: Dynamic regime changed from ", EnumToString(current_regime),
              " to ", EnumToString(dynamic_regime), " (ADX: ", adx_value, ", ATR: ", atr_value, ")");

        // We need to manually set the regime since we're bypassing time-based detection
        // This is a workaround since CTradingRegimeManager doesn't have a SetCurrentRegime method
        // For now, we'll let it use its time-based detection but log our dynamic assessment
    }

    return true;
}

//+------------------------------------------------------------------+
//| Initialize Indicators                                          |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::InitializeIndicators()
{
    Print("TrendFollowingStrategy: Creating indicators for symbol: ", m_symbol, ", timeframe: ", EnumToString(m_timeframe));

    // Check if we have enough historical data
    int bars_available = Bars(m_symbol, m_timeframe);
    Print("TrendFollowingStrategy: Available bars: ", bars_available);

    if(bars_available < 100)
    {
        Print("TrendFollowingStrategy: WARNING - Only ", bars_available, " bars available, may not be enough for indicators");
    }

    // Create Fast EMA
    Print("Creating Fast EMA with period: ", m_params.ema_fast_period);
    m_ema_fast_handle = iMA(m_symbol, m_timeframe, m_params.ema_fast_period, 0, MODE_EMA, PRICE_CLOSE);
    if(m_ema_fast_handle == INVALID_HANDLE)
    {
        Print("TrendFollowingStrategy: Failed to create Fast EMA indicator - Error: ", GetLastError());
        return false;
    }
    Print("Fast EMA handle created: ", m_ema_fast_handle);

    // Create Slow EMA
    Print("Creating Slow EMA with period: ", m_params.ema_slow_period);
    m_ema_slow_handle = iMA(m_symbol, m_timeframe, m_params.ema_slow_period, 0, MODE_EMA, PRICE_CLOSE);
    if(m_ema_slow_handle == INVALID_HANDLE)
    {
        Print("TrendFollowingStrategy: Failed to create Slow EMA indicator - Error: ", GetLastError());
        return false;
    }
    Print("Slow EMA handle created: ", m_ema_slow_handle);

    // Create ADX
    Print("Creating ADX with period: ", m_params.adx_period);
    m_adx_handle = iADX(m_symbol, m_timeframe, m_params.adx_period);
    if(m_adx_handle == INVALID_HANDLE)
    {
        Print("TrendFollowingStrategy: Failed to create ADX indicator - Error: ", GetLastError());
        return false;
    }
    Print("ADX handle created: ", m_adx_handle);

    // MACD is now handled by the enhanced MACD Signal component

    // Create ATR
    Print("Creating ATR with period: ", m_params.atr_period);
    m_atr_handle = iATR(m_symbol, m_timeframe, m_params.atr_period);
    if(m_atr_handle == INVALID_HANDLE)
    {
        Print("TrendFollowingStrategy: Failed to create ATR indicator - Error: ", GetLastError());
        return false;
    }
    Print("ATR handle created: ", m_atr_handle);

    // Create RSI for breakout confirmation
    Print("Creating RSI with period: ", m_params.rsi_period);
    m_rsi_handle = iRSI(m_symbol, m_timeframe, m_params.rsi_period, PRICE_CLOSE);
    if(m_rsi_handle == INVALID_HANDLE)
    {
        Print("TrendFollowingStrategy: Failed to create RSI indicator - Error: ", GetLastError());
        return false;
    }
    Print("RSI handle created: ", m_rsi_handle);

    // Initialize arrays
    ArrayResize(m_ema_fast_buffer, 5);
    ArrayResize(m_ema_slow_buffer, 5);
    ArrayResize(m_adx_buffer, 3);
    ArrayResize(m_atr_buffer, 3);
    ArrayResize(m_rsi_buffer, 3);

    // Wait a moment for indicators to start calculating
    Sleep(100);

    // Check initial status of indicators
    Print("Initial indicator status check:");
    Print("  Fast EMA BarsCalculated: ", BarsCalculated(m_ema_fast_handle));
    Print("  Slow EMA BarsCalculated: ", BarsCalculated(m_ema_slow_handle));
    Print("  ADX BarsCalculated: ", BarsCalculated(m_adx_handle));
    Print("  ATR BarsCalculated: ", BarsCalculated(m_atr_handle));
    Print("  RSI BarsCalculated: ", BarsCalculated(m_rsi_handle));

    Print("Enhanced TrendFollowingStrategy: All indicators initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Enhanced Components                                   |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::InitializeEnhancedComponents()
{
    Print("Enhanced TrendFollowingStrategy: Initializing enhanced components...");
    Print("  MACD confirmation: ", m_params.use_macd_confirmation);
    Print("  MTF bias filter: ", m_params.use_mtf_bias_filter);
    Print("  Regime detection: ", m_params.use_regime_detection);

    // Initialize MACD Signal component
    if(m_params.use_macd_confirmation)
    {
        m_macd_signal = new CMACDSignal(m_symbol, m_timeframe,
                                       m_params.macd_fast_ema,
                                       m_params.macd_slow_ema,
                                       m_params.macd_signal);
        if(!m_macd_signal.Initialize())
        {
            Print("Enhanced TrendFollowingStrategy: Failed to initialize MACD Signal");
            return false;
        }
        Print("Enhanced TrendFollowingStrategy: MACD Signal initialized");
    }
    else
    {
        Print("Enhanced TrendFollowingStrategy: MACD Signal DISABLED");
    }

    // Initialize Trading Regime Manager
    if(m_params.use_regime_detection)
    {
        m_regime_manager = new CTradingRegimeManager(m_symbol);
        if(!m_regime_manager.Initialize())
        {
            Print("Enhanced TrendFollowingStrategy: Failed to initialize Trading Regime Manager");
            return false;
        }
        Print("Enhanced TrendFollowingStrategy: Trading Regime Manager initialized");

        // DO NOT set StrategyBase regime manager - we handle regime logic ourselves
        // SetRegimeManager(NULL); // Keep base class regime manager disabled
    }
    else
    {
        Print("Enhanced TrendFollowingStrategy: Trading Regime Manager DISABLED");
        // Ensure StrategyBase regime manager is also disabled
        SetRegimeManager(NULL);
    }

    // Initialize Multi-Timeframe Bias Filter
    if(m_params.use_mtf_bias_filter)
    {
        Print("Enhanced TrendFollowingStrategy: Initializing MTF Bias Filter...");
        m_mtf_bias_filter = new CH4BiasFilter(m_symbol, m_params.mtf_timeframe);
        if(!m_mtf_bias_filter.Initialize())
        {
            Print("Enhanced TrendFollowingStrategy: Failed to initialize MTF Bias Filter - disabling");
            delete m_mtf_bias_filter;
            m_mtf_bias_filter = NULL;
            m_params.use_mtf_bias_filter = false;
        }
        else
        {
            Print("Enhanced TrendFollowingStrategy: MTF Bias Filter initialized");
        }
    }
    else
    {
        Print("Enhanced TrendFollowingStrategy: MTF Bias Filter DISABLED");
    }

    Print("Enhanced TrendFollowingStrategy: Enhanced components initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize Enhanced Components                                 |
//+------------------------------------------------------------------+
void CTrendFollowingStrategy::DeinitializeEnhancedComponents()
{
    if(m_macd_signal != NULL)
    {
        delete m_macd_signal;
        m_macd_signal = NULL;
    }

    if(m_regime_manager != NULL)
    {
        delete m_regime_manager;
        m_regime_manager = NULL;
    }

    if(m_mtf_bias_filter != NULL)
    {
        delete m_mtf_bias_filter;
        m_mtf_bias_filter = NULL;
    }
}

//+------------------------------------------------------------------+
//| Deinitialize Indicators                                        |
//+------------------------------------------------------------------+
void CTrendFollowingStrategy::DeinitializeIndicators()
{
    if(m_ema_fast_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ema_fast_handle);
        m_ema_fast_handle = INVALID_HANDLE;
    }

    if(m_ema_slow_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ema_slow_handle);
        m_ema_slow_handle = INVALID_HANDLE;
    }

    if(m_adx_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_adx_handle);
        m_adx_handle = INVALID_HANDLE;
    }

    // MACD handle is now managed by the enhanced MACD Signal component

    if(m_atr_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_atr_handle);
        m_atr_handle = INVALID_HANDLE;
    }

    if(m_rsi_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_rsi_handle);
        m_rsi_handle = INVALID_HANDLE;
    }

    // Free arrays
    ArrayFree(m_ema_fast_buffer);
    ArrayFree(m_ema_slow_buffer);
    ArrayFree(m_adx_buffer);
    ArrayFree(m_atr_buffer);
    ArrayFree(m_rsi_buffer);
}

//+------------------------------------------------------------------+
//| Update Indicator Buffers                                       |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::UpdateIndicatorBuffers()
{
    // Check if indicators are ready - be more lenient with initial checks
    int ema_fast_bars = BarsCalculated(m_ema_fast_handle);
    int ema_slow_bars = BarsCalculated(m_ema_slow_handle);
    int adx_bars = BarsCalculated(m_adx_handle);
    int atr_bars = BarsCalculated(m_atr_handle);
    int rsi_bars = BarsCalculated(m_rsi_handle);

    // If any indicator returns -1, it means it's not ready yet
    if(ema_fast_bars < 0 || ema_slow_bars < 0 || adx_bars < 0 ||
       atr_bars < 0 || rsi_bars < 0)
    {
        Print("Enhanced TrendFollowingStrategy: Indicators not ready yet - Fast EMA: ", ema_fast_bars,
              ", Slow EMA: ", ema_slow_bars, ", ADX: ", adx_bars,
              ", ATR: ", atr_bars, ", RSI: ", rsi_bars);

        // Instead of failing completely, let's try to recreate the indicators
        // This might happen on the first few ticks after EA start
        static int retry_count = 0;
        if(retry_count < 3)
        {
            retry_count++;
            Print("Enhanced TrendFollowingStrategy: Retry attempt ", retry_count, " - trying to recreate indicators...");

            // Try to recreate the indicators
            DeinitializeIndicators();
            if(InitializeIndicators())
            {
                Print("Enhanced TrendFollowingStrategy: Successfully recreated indicators on retry ", retry_count);
                // Reset retry count and try to update buffers again
                retry_count = 0;
                return UpdateIndicatorBuffers(); // Recursive call, but with reset retry count
            }
            return false; // Try again next tick
        }
        else
        {
            Print("Enhanced TrendFollowingStrategy: WARNING - Indicators still not ready after 3 retries, using fallback approach");
            // Use fallback values and continue
            retry_count = 0; // Reset for next time

            // Initialize buffers with fallback values
            double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            double spread = SymbolInfoDouble(m_symbol, SYMBOL_ASK) - SymbolInfoDouble(m_symbol, SYMBOL_BID);

            // Initialize EMA buffers with current price
            ArrayResize(m_ema_fast_buffer, 5);
            ArrayResize(m_ema_slow_buffer, 5);
            ArrayInitialize(m_ema_fast_buffer, current_price);
            ArrayInitialize(m_ema_slow_buffer, current_price);

            // Initialize other buffers with reasonable defaults
            ArrayResize(m_adx_buffer, 3);
            ArrayInitialize(m_adx_buffer, 20.0); // Neutral ADX

            // MACD buffers are now handled by the enhanced MACD Signal component

            ArrayResize(m_atr_buffer, 3);
            ArrayInitialize(m_atr_buffer, MathMax(spread * 10, 0.0001)); // Use spread-based ATR fallback

            ArrayResize(m_rsi_buffer, 3);
            ArrayInitialize(m_rsi_buffer, 50.0); // Neutral RSI

            Print("Enhanced TrendFollowingStrategy: Initialized with fallback values - Price: ", current_price, ", ATR: ", m_atr_buffer[0]);
            return true; // Continue with fallback values
        }
    }

    // Check if we have enough calculated bars (more lenient than before)
    if(ema_fast_bars < 2 || ema_slow_bars < 2 || adx_bars < 2 ||
       atr_bars < 2 || rsi_bars < 2)
    {
        Print("Enhanced TrendFollowingStrategy: Not enough calculated bars - Fast EMA: ", ema_fast_bars,
              ", Slow EMA: ", ema_slow_bars, ", ADX: ", adx_bars,
              ", ATR: ", atr_bars, ", RSI: ", rsi_bars);
        return false;
    }
    // Copy EMA buffers with adaptive size based on available data
    int ema_fast_copy_size = MathMin(5, ema_fast_bars);
    int ema_slow_copy_size = MathMin(5, ema_slow_bars);

    if(CopyBuffer(m_ema_fast_handle, 0, 0, ema_fast_copy_size, m_ema_fast_buffer) < ema_fast_copy_size)
    {
        Print("TrendFollowingStrategy: Failed to copy Fast EMA buffer - BarsCalculated: ", ema_fast_bars);
        // Initialize with current price as fallback
        ArrayResize(m_ema_fast_buffer, 5);
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        ArrayInitialize(m_ema_fast_buffer, current_price);
    }

    if(CopyBuffer(m_ema_slow_handle, 0, 0, ema_slow_copy_size, m_ema_slow_buffer) < ema_slow_copy_size)
    {
        Print("TrendFollowingStrategy: Failed to copy Slow EMA buffer - BarsCalculated: ", ema_slow_bars);
        ArrayResize(m_ema_slow_buffer, 5);
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        ArrayInitialize(m_ema_slow_buffer, current_price);
    }

    // Copy ADX buffer with adaptive size
    int adx_copy_size = MathMin(3, adx_bars);
    if(CopyBuffer(m_adx_handle, 0, 0, adx_copy_size, m_adx_buffer) < adx_copy_size)
    {
        Print("TrendFollowingStrategy: Failed to copy ADX buffer - BarsCalculated: ", adx_bars);
        ArrayResize(m_adx_buffer, 3);
        ArrayInitialize(m_adx_buffer, 20.0); // Default ADX value
    }

    // MACD buffers are now handled by the enhanced MACD Signal component

    // Copy ATR buffer with adaptive size
    int atr_copy_size = MathMin(3, atr_bars);
    if(CopyBuffer(m_atr_handle, 0, 0, atr_copy_size, m_atr_buffer) < atr_copy_size)
    {
        Print("TrendFollowingStrategy: Failed to copy ATR buffer - BarsCalculated: ", atr_bars);
        ArrayResize(m_atr_buffer, 3);
        double current_atr = SymbolInfoDouble(m_symbol, SYMBOL_ASK) - SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(current_atr <= 0) current_atr = 0.0001; // Minimum ATR fallback
        ArrayInitialize(m_atr_buffer, current_atr);
    }

    // Copy RSI buffer with adaptive size
    int rsi_copy_size = MathMin(3, rsi_bars);
    if(CopyBuffer(m_rsi_handle, 0, 0, rsi_copy_size, m_rsi_buffer) < rsi_copy_size)
    {
        Print("TrendFollowingStrategy: Failed to copy RSI buffer - BarsCalculated: ", rsi_bars);
        ArrayResize(m_rsi_buffer, 3);
        ArrayInitialize(m_rsi_buffer, 50.0); // Neutral RSI value
    }

    // Always return true - we've handled errors by initializing buffers with default values
    return true;
}

//+------------------------------------------------------------------+
//| Check Entry Signal                                             |
//+------------------------------------------------------------------+
SStrategySignal CTrendFollowingStrategy::CheckEntrySignal()
{
    SStrategySignal signal;
    ResetSignal(signal);

    if(!m_enabled)
    {
        Print("TrendFollowingStrategy: Strategy not enabled");
        return signal;
    }

    if(!m_initialized)
    {
        Print("TrendFollowingStrategy: Strategy not initialized");
        return signal;
    }

    Print("TrendFollowingStrategy: CheckEntrySignal called - enabled: ", m_enabled, ", initialized: ", m_initialized);

    // Check trading hours first
    if(!IsWithinTradingHours())
    {
        Print("TrendFollowingStrategy: Outside trading hours");
        return signal;
    }

    // Check if we can trade today
    if(!CanTradeToday())
        return signal;

    // Validate market conditions
    if(!ValidateMarketConditions())
        return signal;

    // Try to update signals, but continue even if it fails (using fallback values)
    bool signals_updated = UpdateSignals();
    if(!signals_updated)
    {
        Print("TrendFollowingStrategy: Signals not updated, but continuing with available data");
        // Don't return here - continue with whatever data we have
    }

    // Check for strong trend
    if(!IsStrongTrend())
    {
        if(ArraySize(m_adx_buffer) > 0)
        {
            Print("TrendFollowingStrategy: Trend not strong enough - ADX: ", m_adx_buffer[0],
                  " (min: ", m_params.adx_threshold, "), Trend Strength: ", m_trend_strength,
                  " (min: ", m_params.min_trend_strength, "), Current Trend: ", m_current_trend);
        }
        return signal;
    }

    // Enhanced risk management checks
    if(!CheckCorrelationLimits())
        return signal;

    if(!CheckDrawdownProtection())
        return signal;

    // Check for long signal
    Print("Enhanced TrendFollowingStrategy: Checking long trend conditions...");
    if(CheckLongTrendConditions())
    {
        Print("Enhanced TrendFollowingStrategy: Long trend conditions PASSED");
        signal.is_valid = true;
        signal.is_long = true;
        signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        signal.stop_loss = CalculateStopLoss(true, signal.entry_price);
        signal.take_profit = CalculateTakeProfit(true, signal.entry_price, signal.stop_loss);
        signal.signal_strength = CalculateSignalStrength(true);
        signal.confidence = signal.signal_strength * 0.9; // High confidence for trend following

        // Enhanced signal description
        string regime_info = "";
        if(m_regime_manager != NULL)
        {
            ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
            regime_info = StringFormat(", Regime=%s", EnumToString(current_regime));
        }

        signal.signal_description = StringFormat("Enhanced Trend Long: EMA8>EMA21, ADX=%.1f, Strength=%.2f%s",
                                                 ArraySize(m_adx_buffer) > 0 ? m_adx_buffer[0] : 0.0,
                                                 m_trend_strength, regime_info);
        signal.signal_time = TimeCurrent();

        // Calculate dynamic position size
        if(m_params.use_dynamic_sizing)
        {
            double dynamic_size = CalculateDynamicPositionSize(signal.signal_strength, true);
            // Store in signal for use by position manager
            signal.confidence *= (dynamic_size / m_params.base_risk_percent); // Adjust confidence based on size
        }

        // Validate the signal
        if(!ValidateTrendSignal(signal))
        {
            ResetSignal(signal);
            return signal;
        }

        // Update statistics
        m_stats.total_signals++;
        m_stats.last_signal_time = TimeCurrent();
        m_daily_trades++;
        m_last_trade_time = TimeCurrent();

        Print("Enhanced TrendFollowingStrategy: Long signal - Strength: ", signal.signal_strength,
              ", ADX: ", ArraySize(m_adx_buffer) > 0 ? m_adx_buffer[0] : 0.0, ", Trend: ", m_trend_strength);
    }
    // Check for short signal
    else
    {
        Print("Enhanced TrendFollowingStrategy: Long conditions failed, checking short conditions...");
        if(CheckShortTrendConditions())
        {
            Print("Enhanced TrendFollowingStrategy: Short trend conditions PASSED");
        signal.is_valid = true;
        signal.is_long = false;
        signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        signal.stop_loss = CalculateStopLoss(false, signal.entry_price);
        signal.take_profit = CalculateTakeProfit(false, signal.entry_price, signal.stop_loss);
        signal.signal_strength = CalculateSignalStrength(false);
        signal.confidence = signal.signal_strength * 0.9;

        // Enhanced signal description
        string regime_info = "";
        if(m_regime_manager != NULL)
        {
            ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
            regime_info = StringFormat(", Regime=%s", EnumToString(current_regime));
        }

        signal.signal_description = StringFormat("Enhanced Trend Short: EMA8<EMA21, ADX=%.1f, Strength=%.2f%s",
                                                 ArraySize(m_adx_buffer) > 0 ? m_adx_buffer[0] : 0.0,
                                                 m_trend_strength, regime_info);
        signal.signal_time = TimeCurrent();

        // Calculate dynamic position size
        if(m_params.use_dynamic_sizing)
        {
            double dynamic_size = CalculateDynamicPositionSize(signal.signal_strength, false);
            // Store in signal for use by position manager
            signal.confidence *= (dynamic_size / m_params.base_risk_percent); // Adjust confidence based on size
        }

        // Validate the signal
        if(!ValidateTrendSignal(signal))
        {
            ResetSignal(signal);
            return signal;
        }

        // Update statistics
        m_stats.total_signals++;
        m_stats.last_signal_time = TimeCurrent();
        m_daily_trades++;
        m_last_trade_time = TimeCurrent();

        Print("Enhanced TrendFollowingStrategy: Short signal - Strength: ", signal.signal_strength,
              ", ADX: ", ArraySize(m_adx_buffer) > 0 ? m_adx_buffer[0] : 0.0, ", Trend: ", m_trend_strength);
        }
        else
        {
            Print("Enhanced TrendFollowingStrategy: Short conditions failed");
        }
    }

    m_current_signal = signal;
    return signal;
}

//+------------------------------------------------------------------+
//| Check Exit Conditions                                          |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::ShouldExit(bool is_long_position)
{
    if(!m_initialized)
        return false;

    // Update signals first
    if(!UpdateSignals())
        return false;

    // Exit if trend has weakened significantly
    if(m_trend_strength < 0.3)
    {
        Print("TrendFollowingStrategy: Exit due to weak trend: ", m_trend_strength);
        return true;
    }

    // Exit if ADX drops below threshold (trend weakening)
    if(ArraySize(m_adx_buffer) > 0 && m_adx_buffer[0] < (m_params.adx_threshold * 0.7))
    {
        Print("TrendFollowingStrategy: Exit due to low ADX: ", m_adx_buffer[0]);
        return true;
    }

    // Exit if EMA crossover reverses
    if(ArraySize(m_ema_fast_buffer) > 0 && ArraySize(m_ema_slow_buffer) > 0)
    {
        bool ema_bullish = m_ema_fast_buffer[0] > m_ema_slow_buffer[0];

        if(is_long_position && !ema_bullish)
        {
            Print("TrendFollowingStrategy: Exit long due to EMA crossover reversal");
            return true;
        }
        else if(!is_long_position && ema_bullish)
        {
            Print("TrendFollowingStrategy: Exit short due to EMA crossover reversal");
            return true;
        }
    }

    // Exit if MACD shows divergence (using enhanced MACD signal)
    if(m_macd_signal != NULL)
    {
        if(is_long_position && m_macd_signal.IsBearishCrossover())
        {
            Print("Enhanced TrendFollowingStrategy: Exit long due to MACD bearish crossover");
            return true;
        }
        else if(!is_long_position && m_macd_signal.IsBullishCrossover())
        {
            Print("Enhanced TrendFollowingStrategy: Exit short due to MACD bullish crossover");
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Analyze Current Trend                                          |
//+------------------------------------------------------------------+
void CTrendFollowingStrategy::AnalyzeTrend()
{
    if(ArraySize(m_ema_fast_buffer) < 2 || ArraySize(m_ema_slow_buffer) < 2)
        return;

    int previous_trend = m_current_trend;

    // Determine trend direction based on EMA crossover
    if(m_ema_fast_buffer[0] > m_ema_slow_buffer[0])
        m_current_trend = 1;  // Uptrend
    else if(m_ema_fast_buffer[0] < m_ema_slow_buffer[0])
        m_current_trend = -1; // Downtrend
    else
        m_current_trend = 0;  // No clear trend

    // Check for trend change
    if(m_current_trend != previous_trend && m_current_trend != 0)
    {
        m_last_trend_change = TimeCurrent();
        Print("TrendFollowingStrategy: Trend change detected - New trend: ",
              m_current_trend == 1 ? "UP" : "DOWN");
    }

    // Calculate trend strength
    m_trend_strength = CalculateTrendStrength();

    // Debug logging
    static datetime last_log_time = 0;
    if(TimeCurrent() - last_log_time > 300) // Log every 5 minutes
    {
        if(ArraySize(m_adx_buffer) > 0)
        {
            Print("TrendFollowingStrategy: Trend Analysis - Current Trend: ",
                  m_current_trend == 1 ? "UP" : (m_current_trend == -1 ? "DOWN" : "NONE"),
                  ", Strength: ", m_trend_strength, ", ADX: ", m_adx_buffer[0]);
        }
        last_log_time = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Calculate Trend Strength                                       |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::CalculateTrendStrength()
{
    double strength = 0.0;

    if(ArraySize(m_ema_fast_buffer) < 2 || ArraySize(m_ema_slow_buffer) < 2 || ArraySize(m_adx_buffer) < 1)
        return strength;

    // EMA separation strength (0.0-0.4)
    double ema_separation = MathAbs(m_ema_fast_buffer[0] - m_ema_slow_buffer[0]);
    double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double separation_ratio = ema_separation / price;
    strength += MathMin(0.4, separation_ratio * 10000); // Normalize and cap

    // ADX strength (0.0-0.4)
    double adx_strength = (m_adx_buffer[0] - 20.0) / 80.0; // Normalize ADX (20-100 range)
    strength += MathMax(0.0, MathMin(0.4, adx_strength));

    // EMA momentum strength (0.0-0.2)
    double ema_fast_momentum = (m_ema_fast_buffer[0] - m_ema_fast_buffer[1]) / m_ema_fast_buffer[1];
    double ema_slow_momentum = (m_ema_slow_buffer[0] - m_ema_slow_buffer[1]) / m_ema_slow_buffer[1];

    if(m_current_trend == 1) // Uptrend
    {
        if(ema_fast_momentum > 0 && ema_slow_momentum > 0)
            strength += MathMin(0.2, (ema_fast_momentum + ema_slow_momentum) * 5000);
    }
    else if(m_current_trend == -1) // Downtrend
    {
        if(ema_fast_momentum < 0 && ema_slow_momentum < 0)
            strength += MathMin(0.2, MathAbs(ema_fast_momentum + ema_slow_momentum) * 5000);
    }

    return MathMin(1.0, strength);
}

//+------------------------------------------------------------------+
//| Check if Current Trend is Strong                              |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::IsStrongTrend()
{
    // If ADX data is not available, use a more lenient approach
    if(ArraySize(m_adx_buffer) < 1)
    {
        Print("TrendFollowingStrategy: ADX data not available, using fallback trend check");
        // Fallback: check if we have EMA data and use basic trend logic
        if(ArraySize(m_ema_fast_buffer) >= 1 && ArraySize(m_ema_slow_buffer) >= 1)
        {
            // Simple trend check: fast EMA vs slow EMA
            double ema_diff = MathAbs(m_ema_fast_buffer[0] - m_ema_slow_buffer[0]);
            double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            double min_separation = current_price * 0.0001; // 0.01% minimum separation
            return ema_diff > min_separation;
        }
        return true; // If no data available, assume trend is OK to allow trading
    }

    // ADX must be above threshold
    if(m_adx_buffer[0] < m_params.adx_threshold)
    {
        Print("TrendFollowingStrategy: ADX below threshold - ADX: ", m_adx_buffer[0], ", threshold: ", m_params.adx_threshold);
        return false;
    }

    // Trend strength must be above minimum (but be lenient if not calculated yet)
    if(m_trend_strength > 0 && m_trend_strength < m_params.min_trend_strength)
    {
        Print("TrendFollowingStrategy: Trend strength too low - strength: ", m_trend_strength, ", minimum: ", m_params.min_trend_strength);
        return false;
    }

    // Must have a clear trend direction (but allow if not determined yet)
    if(m_current_trend == 0)
    {
        Print("TrendFollowingStrategy: No clear trend direction");
        // Don't fail completely - let other checks determine if we can trade
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check Long Trend Conditions                                   |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::CheckLongTrendConditions()
{
    if(ArraySize(m_ema_fast_buffer) < 1 || ArraySize(m_ema_slow_buffer) < 1)
        return false;

    double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);

    // Basic trend conditions
    bool ema_bullish = m_ema_fast_buffer[0] > m_ema_slow_buffer[0];
    bool price_condition_met = false;

    if(m_params.require_price_above_both_emas)
    {
        // Strict mode: Price must be above both EMAs
        price_condition_met = (current_price > m_ema_fast_buffer[0] && current_price > m_ema_slow_buffer[0]);
    }
    else if(m_params.allow_ema_crossover_entries)
    {
        // Flexible mode: Allow entries when EMAs are bullish, even if price is between them
        price_condition_met = ema_bullish && (current_price > m_ema_slow_buffer[0] ||
                                             (current_price > m_ema_slow_buffer[0] * 0.9995)); // Small tolerance
    }
    else
    {
        // Default mode: Price above fast EMA and EMAs bullish
        price_condition_met = (current_price > m_ema_fast_buffer[0]) && ema_bullish;
    }

    if(!ema_bullish || !price_condition_met)
    {
        Print("Enhanced TrendFollowingStrategy: Long trend conditions failed - EMA Bullish: ", ema_bullish,
              ", Price condition met: ", price_condition_met,
              ", Price: ", current_price, ", EMA8: ", m_ema_fast_buffer[0], ", EMA21: ", m_ema_slow_buffer[0],
              ", Strict mode: ", m_params.require_price_above_both_emas,
              ", Allow crossover entries: ", m_params.allow_ema_crossover_entries);
        return false;
    }

    // Enhanced MACD confirmation
    if(m_params.use_macd_confirmation)
    {
        if(!CheckEnhancedMACDConfirmation(true))
        {
            Print("Enhanced TrendFollowingStrategy: Long MACD confirmation failed");
            return false;
        }
    }
    else
    {
        Print("Enhanced TrendFollowingStrategy: MACD confirmation DISABLED - skipping check");
    }

    // Multi-timeframe bias filter
    if(m_params.use_mtf_bias_filter)
    {
        if(!CheckMTFBiasAlignment(true))
        {
            Print("Enhanced TrendFollowingStrategy: Long MTF bias alignment failed");
            return false;
        }
    }
    else
    {
        Print("Enhanced TrendFollowingStrategy: MTF bias filter DISABLED - skipping check");
    }

    // Regime-based entry check
    if(m_params.use_regime_detection)
    {
        if(!CheckRegimeBasedEntry(true))
        {
            Print("Enhanced TrendFollowingStrategy: Long regime-based entry failed");
            return false;
        }
    }
    else
    {
        Print("Enhanced TrendFollowingStrategy: Regime detection DISABLED - skipping check");
    }

    // Check for pullback entry if enabled
    if(m_params.use_pullback_entries)
    {
        if(!CheckPullbackEntry(true))
        {
            Print("Enhanced TrendFollowingStrategy: Long pullback entry failed");
            return false;
        }
    }

    // Check breakout momentum only if breakout logic is enabled
    Print("Enhanced TrendFollowingStrategy: Breakout logic enabled: ", m_params.enable_breakout_logic);
    if(m_params.enable_breakout_logic)
    {
        Print("Enhanced TrendFollowingStrategy: Calling CheckBreakoutMomentum for LONG...");
        if(!CheckBreakoutMomentum(true))
        {
            Print("Enhanced TrendFollowingStrategy: Long breakout momentum failed");
            return false;
        }
        else
        {
            Print("Enhanced TrendFollowingStrategy: Long breakout momentum PASSED");
        }
    }

    // Check breakout continuation logic if enabled
    if(m_params.enable_breakout_logic)
    {
        // If we have a breakout, check for pullback entry
        if(m_breakout_detected && m_waiting_for_pullback)
        {
            if(!IsSignificantBreakout(true))
                return false;

            if(!CheckBreakoutPullback(true))
                return false;

            if(!CheckRSIMomentumConfirmation(true))
                return false;

            // Breakout pullback entry confirmed
            m_waiting_for_pullback = false; // Mark pullback as used
            Print("Enhanced TrendFollowingStrategy: Breakout pullback entry confirmed for LONG");
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check Short Trend Conditions                                  |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::CheckShortTrendConditions()
{
    if(ArraySize(m_ema_fast_buffer) < 1 || ArraySize(m_ema_slow_buffer) < 1)
        return false;

    double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);

    // Basic trend conditions
    bool ema_bearish = m_ema_fast_buffer[0] < m_ema_slow_buffer[0];
    bool price_condition_met = false;

    if(m_params.require_price_above_both_emas)
    {
        // Strict mode: Price must be below both EMAs
        price_condition_met = (current_price < m_ema_fast_buffer[0] && current_price < m_ema_slow_buffer[0]);
    }
    else if(m_params.allow_ema_crossover_entries)
    {
        // Flexible mode: Allow entries when EMAs are bearish, even if price is between them
        price_condition_met = ema_bearish && (current_price < m_ema_slow_buffer[0] ||
                                             (current_price < m_ema_slow_buffer[0] * 1.0005)); // Small tolerance
    }
    else
    {
        // Default mode: Price below fast EMA and EMAs bearish
        price_condition_met = (current_price < m_ema_fast_buffer[0]) && ema_bearish;
    }

    if(!ema_bearish || !price_condition_met)
    {
        Print("Enhanced TrendFollowingStrategy: Short trend conditions failed - EMA Bearish: ", ema_bearish,
              ", Price condition met: ", price_condition_met,
              ", Price: ", current_price, ", EMA8: ", m_ema_fast_buffer[0], ", EMA21: ", m_ema_slow_buffer[0],
              ", Strict mode: ", m_params.require_price_above_both_emas,
              ", Allow crossover entries: ", m_params.allow_ema_crossover_entries);
        return false;
    }

    // Enhanced MACD confirmation
    if(m_params.use_macd_confirmation)
    {
        if(!CheckEnhancedMACDConfirmation(false))
        {
            Print("Enhanced TrendFollowingStrategy: Short MACD confirmation failed");
            return false;
        }
    }
    else
    {
        Print("Enhanced TrendFollowingStrategy: MACD confirmation DISABLED - skipping check");
    }

    // Multi-timeframe bias filter
    if(m_params.use_mtf_bias_filter)
    {
        if(!CheckMTFBiasAlignment(false))
        {
            Print("Enhanced TrendFollowingStrategy: Short MTF bias alignment failed");
            return false;
        }
    }
    else
    {
        Print("Enhanced TrendFollowingStrategy: MTF bias filter DISABLED - skipping check");
    }

    // Regime-based entry check
    if(m_params.use_regime_detection)
    {
        if(!CheckRegimeBasedEntry(false))
        {
            Print("Enhanced TrendFollowingStrategy: Short regime-based entry failed");
            return false;
        }
    }
    else
    {
        Print("Enhanced TrendFollowingStrategy: Regime detection DISABLED - skipping check");
    }

    // Check for pullback entry if enabled
    if(m_params.use_pullback_entries)
    {
        if(!CheckPullbackEntry(false))
        {
            Print("Enhanced TrendFollowingStrategy: Short pullback entry failed");
            return false;
        }
    }

    // Check breakout momentum only if breakout logic is enabled
    if(m_params.enable_breakout_logic && !CheckBreakoutMomentum(false))
    {
        Print("Enhanced TrendFollowingStrategy: Short breakout momentum failed");
        return false;
    }

    // Check breakout continuation logic if enabled
    if(m_params.enable_breakout_logic)
    {
        // If we have a breakout, check for pullback entry
        if(m_breakout_detected && m_waiting_for_pullback)
        {
            if(!IsSignificantBreakout(false))
                return false;

            if(!CheckBreakoutPullback(false))
                return false;

            if(!CheckRSIMomentumConfirmation(false))
                return false;

            // Breakout pullback entry confirmed
            m_waiting_for_pullback = false; // Mark pullback as used
            Print("Enhanced TrendFollowingStrategy: Breakout pullback entry confirmed for SHORT");
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check Enhanced MACD Confirmation                               |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::CheckEnhancedMACDConfirmation(bool is_long)
{
    if(m_macd_signal == NULL)
        return true; // Skip if MACD signal not available

    if(is_long)
    {
        // For long: Use MACD trend mode if enabled, otherwise signal mode
        if(m_params.use_macd_trend_mode)
            return m_macd_signal.IsBullishTrend();
        else
            return m_macd_signal.IsBullishSignal();
    }
    else
    {
        // For short: Use MACD trend mode if enabled, otherwise signal mode
        if(m_params.use_macd_trend_mode)
            return m_macd_signal.IsBearishTrend();
        else
            return m_macd_signal.IsBearishSignal();
    }
}

//+------------------------------------------------------------------+
//| Check Multi-Timeframe Bias Alignment                           |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::CheckMTFBiasAlignment(bool is_long)
{
    Print("Enhanced TrendFollowingStrategy: CheckMTFBiasAlignment called - use_mtf_bias_filter: ", m_params.use_mtf_bias_filter);

    if(m_mtf_bias_filter == NULL)
    {
        Print("Enhanced TrendFollowingStrategy: MTF Bias Filter is NULL - returning true");
        return true; // Skip if MTF bias filter not available
    }

    // Check if the direction is allowed by the higher timeframe bias
    bool direction_allowed = m_mtf_bias_filter.IsDirectionAllowed(is_long);

    // Check if bias strength meets minimum requirement
    double bias_strength = m_mtf_bias_filter.GetBiasStrength();
    bool strength_sufficient = bias_strength >= m_params.mtf_bias_strength_min;

    // Get current bias for debugging
    string bias_description = m_mtf_bias_filter.GetBiasDescription();

    Print("Enhanced TrendFollowingStrategy: MTF Bias - Current bias: ", bias_description,
          ", Direction (", (is_long ? "LONG" : "SHORT"), ") allowed: ", direction_allowed,
          ", Bias strength: ", bias_strength, " (min: ", m_params.mtf_bias_strength_min, ")");

    // If allow_against_bias is true, ignore direction restriction
    if(m_params.allow_against_bias && !direction_allowed)
    {
        Print("Enhanced TrendFollowingStrategy: Trading against bias ALLOWED - overriding direction restriction");
        direction_allowed = true;
    }

    return direction_allowed && strength_sufficient;
}

//+------------------------------------------------------------------+
//| Check Regime-Based Entry (Dynamic for Trend Following)        |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::CheckRegimeBasedEntry(bool is_long)
{
    // For trend following, we use dynamic market-based regime detection
    // instead of fixed time-based regimes

    if(m_regime_manager == NULL)
        return true; // Skip if regime manager not available

    // Dynamic regime assessment based on market conditions
    double adx_value = (ArraySize(m_adx_buffer) > 0) ? m_adx_buffer[0] : 0.0;
    double trend_strength = m_trend_strength;

    // For trend following, we want to trade when there's a trend
    // regardless of time-based regime
    if(adx_value < 15.0 && trend_strength < 0.3)
    {
        Print("Enhanced TrendFollowingStrategy: Market conditions not suitable for trend following - ADX: ",
              adx_value, ", Trend strength: ", trend_strength);
        return false;
    }

    // Check basic trade limits (but not time-based regime limits)
    static int trades_today = 0;
    static datetime last_reset_date = 0;

    datetime current_time = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(current_time, dt);

    // Reset daily counter
    if(dt.day != last_reset_date)
    {
        trades_today = 0;
        last_reset_date = dt.day;
    }

    // Apply reasonable daily limit for trend following
    if(trades_today >= 5) // Max 5 trades per day
    {
        Print("Enhanced TrendFollowingStrategy: Daily trade limit reached (", trades_today, "/5)");
        return false;
    }

    Print("Enhanced TrendFollowingStrategy: Dynamic regime check passed - ADX: ", adx_value,
          ", Trend strength: ", trend_strength, ", Trades today: ", trades_today);

    return true;
}

//+------------------------------------------------------------------+
//| Check Pullback Entry                                          |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::CheckPullbackEntry(bool is_long)
{
    if(ArraySize(m_ema_fast_buffer) < 3)
        return true; // Skip if insufficient data

    double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);

    if(is_long)
    {
        // For long: Price should be near or slightly below fast EMA (pullback)
        double pullback_level = m_ema_fast_buffer[0] * (1.0 - m_params.pullback_threshold * 0.01);
        return (current_price >= pullback_level && current_price <= m_ema_fast_buffer[0] * 1.002);
    }
    else
    {
        // For short: Price should be near or slightly above fast EMA (pullback)
        double pullback_level = m_ema_fast_buffer[0] * (1.0 + m_params.pullback_threshold * 0.01);
        return (current_price <= pullback_level && current_price >= m_ema_fast_buffer[0] * 0.998);
    }
}

//+------------------------------------------------------------------+
//| Check Breakout Momentum                                       |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::CheckBreakoutMomentum(bool is_long)
{
    if(ArraySize(m_ema_fast_buffer) < 2)
        return true; // Skip if insufficient data

    // For trend following, we need more flexible momentum check
    // Check if the fast EMA is moving in the trend direction (primary requirement)
    double ema_fast_momentum = m_ema_fast_buffer[0] - m_ema_fast_buffer[1];
    double ema_slow_momentum = m_ema_slow_buffer[0] - m_ema_slow_buffer[1];

    // Get current price for additional context
    double current_price = SymbolInfoDouble(m_symbol, is_long ? SYMBOL_ASK : SYMBOL_BID);

    if(is_long)
    {
        // For long: Fast EMA should be moving up OR price is above both EMAs (showing strength)
        bool fast_ema_rising = ema_fast_momentum > 0;
        bool price_above_both = (current_price > m_ema_fast_buffer[0] && current_price > m_ema_slow_buffer[0]);
        bool emas_bullish = m_ema_fast_buffer[0] > m_ema_slow_buffer[0];

        bool result = (fast_ema_rising || price_above_both) && emas_bullish;

        Print("Enhanced TrendFollowingStrategy: Long breakout momentum check - Fast EMA rising: ", fast_ema_rising,
              ", Price above both: ", price_above_both, ", EMAs bullish: ", emas_bullish, ", Result: ", result);

        return result;
    }
    else
    {
        // For short: Fast EMA should be moving down OR price is below both EMAs (showing weakness)
        bool fast_ema_falling = ema_fast_momentum < 0;
        bool price_below_both = (current_price < m_ema_fast_buffer[0] && current_price < m_ema_slow_buffer[0]);
        bool emas_bearish = m_ema_fast_buffer[0] < m_ema_slow_buffer[0];

        bool result = (fast_ema_falling || price_below_both) && emas_bearish;

        Print("Enhanced TrendFollowingStrategy: Short breakout momentum check - Fast EMA falling: ", fast_ema_falling,
              ", Price below both: ", price_below_both, ", EMAs bearish: ", emas_bearish, ", Result: ", result);

        return result;
    }
}

//+------------------------------------------------------------------+
//| Calculate Signal Strength                                     |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::CalculateSignalStrength(bool is_long)
{
    double strength = 0.0;

    // EMA crossover strength (0.0-0.25)
    strength += GetEMACrossoverStrength(is_long);

    // ADX strength (0.0-0.25)
    strength += GetADXStrength();

    // Enhanced MACD strength (0.0-0.2)
    strength += GetEnhancedMACDStrength(is_long);

    // MTF Bias strength (0.0-0.15)
    strength += GetMTFBiasStrength(is_long);

    // Regime strength (0.0-0.1)
    strength += GetRegimeStrength(is_long);

    // Momentum strength (0.0-0.05)
    strength += GetMomentumStrength(is_long);

    return MathMin(1.0, strength);
}

//+------------------------------------------------------------------+
//| Get EMA Crossover Strength                                    |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::GetEMACrossoverStrength(bool is_long)
{
    if(ArraySize(m_ema_fast_buffer) < 1 || ArraySize(m_ema_slow_buffer) < 1)
        return 0.0;

    double separation = MathAbs(m_ema_fast_buffer[0] - m_ema_slow_buffer[0]);
    double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double separation_ratio = separation / price;

    // Normalize and cap at 0.3
    return MathMin(0.3, separation_ratio * 5000);
}

//+------------------------------------------------------------------+
//| Get ADX Strength                                              |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::GetADXStrength()
{
    if(ArraySize(m_adx_buffer) < 1)
        return 0.0;

    // Normalize ADX value (25-75 range mapped to 0.0-0.3)
    double normalized_adx = (m_adx_buffer[0] - 25.0) / 50.0;
    return MathMax(0.0, MathMin(0.3, normalized_adx));
}

//+------------------------------------------------------------------+
//| Get Enhanced MACD Strength                                    |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::GetEnhancedMACDStrength(bool is_long)
{
    if(m_macd_signal == NULL)
        return 0.0;

    double strength = 0.0;

    // Base MACD signal strength
    if(is_long && m_macd_signal.IsBullishSignal())
        strength += 0.1;
    else if(!is_long && m_macd_signal.IsBearishSignal())
        strength += 0.1;

    // Additional strength for crossovers
    if(is_long && m_macd_signal.IsBullishCrossover())
        strength += 0.05;
    else if(!is_long && m_macd_signal.IsBearishCrossover())
        strength += 0.05;

    // Additional strength for strong signals
    if(is_long && m_macd_signal.IsStrongBullish())
        strength += 0.05;
    else if(!is_long && m_macd_signal.IsStrongBearish())
        strength += 0.05;

    return MathMin(0.2, strength);
}

//+------------------------------------------------------------------+
//| Get Multi-Timeframe Bias Strength                             |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::GetMTFBiasStrength(bool is_long)
{
    if(m_mtf_bias_filter == NULL)
        return 0.0;

    // Get bias score for the direction
    double bias_score = m_mtf_bias_filter.GetBiasScore(is_long);

    // Scale to 0.0-0.15 range
    return MathMin(0.15, bias_score * 0.15);
}

//+------------------------------------------------------------------+
//| Get Regime Strength (Dynamic for Trend Following)            |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::GetRegimeStrength(bool is_long)
{
    // For trend following, calculate regime strength based on market conditions
    // not time-based regimes

    double adx_value = (ArraySize(m_adx_buffer) > 0) ? m_adx_buffer[0] : 0.0;
    double trend_strength = m_trend_strength;

    // Calculate dynamic regime strength based on trend conditions
    double regime_strength = 0.0;

    if(adx_value > 25.0) // Strong trending conditions
    {
        regime_strength = 0.1; // Maximum strength for strong trends
    }
    else if(adx_value > 18.0) // Moderate trending conditions
    {
        regime_strength = 0.08; // Good strength for moderate trends
    }
    else if(adx_value > 15.0) // Weak trending conditions
    {
        regime_strength = 0.05; // Lower strength for weak trends
    }
    else // Very weak or ranging conditions
    {
        regime_strength = 0.02; // Minimal strength for poor trend conditions
    }

    // Adjust based on trend strength
    regime_strength *= (0.5 + trend_strength); // Scale by trend strength

    return MathMin(0.1, regime_strength); // Cap at 0.1
}

//+------------------------------------------------------------------+
//| Get Momentum Strength                                         |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::GetMomentumStrength(bool is_long)
{
    if(ArraySize(m_ema_fast_buffer) < 2)
        return 0.0;

    double ema_momentum = (m_ema_fast_buffer[0] - m_ema_fast_buffer[1]) / m_ema_fast_buffer[1];

    if(is_long && ema_momentum > 0)
        return MathMin(0.2, ema_momentum * 2000);
    else if(!is_long && ema_momentum < 0)
        return MathMin(0.05, MathAbs(ema_momentum) * 1000); // Reduced weight

    return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Position Size                                |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::CalculateDynamicPositionSize(double signal_strength, bool is_long)
{
    if(!m_params.use_dynamic_sizing)
        return m_params.base_risk_percent;

    double base_size = m_params.base_risk_percent;
    double max_size = m_params.max_risk_percent;

    // Adjust size based on signal strength (0.5x to 2.0x base size)
    double strength_multiplier = 0.5 + (signal_strength * 1.5);
    double adjusted_size = base_size * strength_multiplier;

    // Adjust for dynamic market conditions (not time-based regimes)
    if(m_regime_manager != NULL)
    {
        double adx_value = (ArraySize(m_adx_buffer) > 0) ? m_adx_buffer[0] : 0.0;
        double trend_strength = m_trend_strength;
        double regime_multiplier = 1.0;

        // Dynamic sizing based on trend strength and ADX
        if(adx_value > 25.0 && trend_strength > 0.6) // Strong trending conditions
        {
            regime_multiplier = 1.3; // Increase size for strong trends
        }
        else if(adx_value > 18.0 && trend_strength > 0.4) // Moderate trending conditions
        {
            regime_multiplier = 1.1; // Slightly increase size for moderate trends
        }
        else if(adx_value < 15.0 || trend_strength < 0.3) // Weak trending conditions
        {
            regime_multiplier = 0.7; // Reduce size for weak trends
        }
        else // Normal conditions
        {
            regime_multiplier = 1.0; // Standard size
        }

        adjusted_size *= regime_multiplier;

        Print("Enhanced TrendFollowingStrategy: Dynamic sizing - ADX: ", adx_value,
              ", Trend strength: ", trend_strength, ", Multiplier: ", regime_multiplier);
    }

    // Apply drawdown protection
    if(m_params.use_drawdown_protection && m_current_drawdown > 5.0)
    {
        double drawdown_multiplier = 1.0 - (m_current_drawdown / 100.0);
        adjusted_size *= MathMax(0.3, drawdown_multiplier); // Minimum 30% of normal size
    }

    // Apply consecutive loss protection
    if(m_consecutive_losses > 2)
    {
        double loss_multiplier = 1.0 / (1.0 + (m_consecutive_losses - 2) * 0.2);
        adjusted_size *= MathMax(0.5, loss_multiplier); // Minimum 50% of normal size
    }

    return MathMin(max_size, MathMax(0.1, adjusted_size)); // Min 0.1%, Max as configured
}

//+------------------------------------------------------------------+
//| Check Correlation Limits                                       |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::CheckCorrelationLimits()
{
    if(!m_params.use_correlation_filter)
        return true;

    // This is a simplified correlation check
    // In a real implementation, you would check correlation with other positions
    // For now, we'll implement a basic time-based correlation filter

    datetime current_time = TimeCurrent();
    if(m_last_trade_time > 0)
    {
        int minutes_since_last_trade = (int)((current_time - m_last_trade_time) / 60);

        // Don't allow trades within 15 minutes of each other to reduce correlation
        if(minutes_since_last_trade < 15)
        {
            Print("Enhanced TrendFollowingStrategy: Trade blocked due to correlation filter - ",
                  minutes_since_last_trade, " minutes since last trade");
            return false;
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check Drawdown Protection                                      |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::CheckDrawdownProtection()
{
    if(!m_params.use_drawdown_protection)
        return true;

    if(m_current_drawdown > m_params.max_drawdown_percent)
    {
        Print("Enhanced TrendFollowingStrategy: Trade blocked due to drawdown protection - ",
              "Current drawdown: ", m_current_drawdown, "%, Max allowed: ", m_params.max_drawdown_percent, "%");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Update Risk Metrics                                           |
//+------------------------------------------------------------------+
void CTrendFollowingStrategy::UpdateRiskMetrics()
{
    double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);

    // Update peak equity
    if(current_equity > m_peak_equity)
        m_peak_equity = current_equity;

    // Calculate current drawdown
    if(m_peak_equity > 0)
        m_current_drawdown = ((m_peak_equity - current_equity) / m_peak_equity) * 100.0;
    else
        m_current_drawdown = 0.0;

    // Update portfolio risk (simplified - would need position tracking in real implementation)
    m_current_portfolio_risk = 0.0; // This would be calculated based on open positions
}

//+------------------------------------------------------------------+
//| Calculate ATR-based Stop Loss                                 |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::CalculateStopLoss(bool is_long, double entry_price)
{
    double calculated_sl = 0.0;

    // Try swing-based stop loss first if enabled
    if(m_params.use_regime_based_stops)
    {
        calculated_sl = CalculateSwingBasedStopLoss(is_long, entry_price);
        if(calculated_sl > 0)
        {
            Print("Enhanced TrendFollowingStrategy: Using swing-based stop loss: ", calculated_sl);
        }
    }

    // Fallback to ATR-based calculation
    if(calculated_sl <= 0)
    {
        double atr_value = GetATRValue();
        if(atr_value <= 0)
        {
            // Fallback to base class method if ATR not available
            return CStrategyBase::CalculateStopLoss(is_long, entry_price);
        }

        // Use tighter stops for breakout trades
        double sl_multiplier = m_params.atr_sl_multiplier;
        if(m_params.enable_breakout_logic && m_breakout_detected && !m_waiting_for_pullback)
        {
            sl_multiplier = m_params.breakout_sl_multiplier;
            Print("Enhanced TrendFollowingStrategy: Using tighter breakout stop loss multiplier: ", sl_multiplier);
        }

        double stop_distance = atr_value * sl_multiplier;

        if(is_long)
            calculated_sl = entry_price - stop_distance;
        else
            calculated_sl = entry_price + stop_distance;
    }

    // Use regime manager for additional optimization
    if(m_regime_manager != NULL && m_params.use_regime_based_stops)
    {
        ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
        if(current_regime != REGIME_NONE)
        {
            double regime_sl = m_regime_manager.GetOptimalStopLoss(current_regime, is_long, entry_price);
            if(regime_sl > 0)
            {
                // Use the more conservative (further) stop loss
                if(is_long)
                    calculated_sl = MathMin(calculated_sl, regime_sl);
                else
                    calculated_sl = MathMax(calculated_sl, regime_sl);

                Print("Enhanced TrendFollowingStrategy: Applied regime-based stop loss adjustment");
            }
        }
    }

    return calculated_sl;
}

//+------------------------------------------------------------------+
//| Calculate Swing-Based Stop Loss                               |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::CalculateSwingBasedStopLoss(bool is_long, double entry_price)
{
    // This is a simplified swing-based stop loss calculation
    // In a real implementation, you would analyze recent swing highs/lows

    double atr_value = GetATRValue();
    if(atr_value <= 0)
        return 0.0;

    // Look for recent swing points using price action
    double swing_level = 0.0;

    // Get recent high/low data
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);

    if(CopyHigh(m_symbol, m_timeframe, 0, 20, high) < 20 ||
       CopyLow(m_symbol, m_timeframe, 0, 20, low) < 20)
    {
        return 0.0; // Fallback if data not available
    }

    if(is_long)
    {
        // Find recent swing low
        double recent_low = low[0];
        for(int i = 1; i < 10; i++)
        {
            if(low[i] < recent_low)
                recent_low = low[i];
        }

        // Place stop below recent swing low with buffer
        swing_level = recent_low - (atr_value * 0.5);

        // Ensure stop is not too far from entry
        double max_distance = atr_value * 3.0;
        if((entry_price - swing_level) > max_distance)
            swing_level = entry_price - max_distance;
    }
    else
    {
        // Find recent swing high
        double recent_high = high[0];
        for(int i = 1; i < 10; i++)
        {
            if(high[i] > recent_high)
                recent_high = high[i];
        }

        // Place stop above recent swing high with buffer
        swing_level = recent_high + (atr_value * 0.5);

        // Ensure stop is not too far from entry
        double max_distance = atr_value * 3.0;
        if((swing_level - entry_price) > max_distance)
            swing_level = entry_price + max_distance;
    }

    return swing_level;
}

//+------------------------------------------------------------------+
//| Calculate ATR-based Take Profit                               |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::CalculateTakeProfit(bool is_long, double entry_price, double stop_loss)
{
    double atr_value = GetATRValue();
    if(atr_value <= 0)
    {
        // Fallback to base class method if ATR not available
        return CStrategyBase::CalculateTakeProfit(is_long, entry_price, stop_loss);
    }

    double tp_distance = atr_value * m_params.atr_tp_multiplier;

    double take_profit;
    if(is_long)
        take_profit = entry_price + tp_distance;
    else
        take_profit = entry_price - tp_distance;

    // Use regime manager if available for additional optimization
    if(m_regime_manager != NULL)
    {
        ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
        if(current_regime != REGIME_NONE)
        {
            double regime_tp = m_regime_manager.GetOptimalTakeProfit(current_regime, is_long, entry_price, stop_loss);
            if(regime_tp > 0)
                take_profit = regime_tp;
        }
    }

    return take_profit;
}

//+------------------------------------------------------------------+
//| Get ATR Value                                                  |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::GetATRValue()
{
    if(ArraySize(m_atr_buffer) < 1)
        return 0.0;

    return m_atr_buffer[0];
}

//+------------------------------------------------------------------+
//| Validate Trend Signal                                         |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::ValidateTrendSignal(const SStrategySignal& signal)
{
    // First use base class validation
    if(!ValidateSignal(signal))
        return false;

    // Additional trend-specific validation

    // Check ATR-based risk
    double atr_value = GetATRValue();
    if(atr_value > 0)
    {
        double sl_distance = MathAbs(signal.entry_price - signal.stop_loss);
        double expected_sl_distance = atr_value * m_params.atr_sl_multiplier;

        // Stop loss should be reasonable compared to ATR
        if(sl_distance > expected_sl_distance * 1.5)
        {
            Print("TrendFollowingStrategy: Stop loss too wide: ", sl_distance, " vs expected: ", expected_sl_distance);
            return false;
        }
    }

    // Check trend consistency
    if(signal.is_long && m_current_trend != 1)
    {
        Print("TrendFollowingStrategy: Long signal inconsistent with trend direction");
        return false;
    }
    else if(!signal.is_long && m_current_trend != -1)
    {
        Print("TrendFollowingStrategy: Short signal inconsistent with trend direction");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Get Strategy Information                                       |
//+------------------------------------------------------------------+
string CTrendFollowingStrategy::GetStrategyInfo()
{
    string info = CStrategyBase::GetStrategyInfo();

    info += "=== Enhanced Trend Following Specific Info ===\n";
    info += StringFormat("EMA Periods: %d/%d\n", m_params.ema_fast_period, m_params.ema_slow_period);
    info += StringFormat("ADX Period: %d | Threshold: %.1f\n", m_params.adx_period, m_params.adx_threshold);
    info += StringFormat("ATR Multipliers: SL=%.1f, TP=%.1f\n", m_params.atr_sl_multiplier, m_params.atr_tp_multiplier);

    if(ArraySize(m_adx_buffer) > 0)
        info += StringFormat("Current ADX: %.1f\n", m_adx_buffer[0]);

    info += StringFormat("Current Trend: %s\n",
                        m_current_trend == 1 ? "UP" : (m_current_trend == -1 ? "DOWN" : "NONE"));
    info += StringFormat("Trend Strength: %.2f\n", m_trend_strength);

    if(m_last_trend_change > 0)
        info += StringFormat("Last Trend Change: %s\n", TimeToString(m_last_trend_change));

    if(ArraySize(m_ema_fast_buffer) > 0 && ArraySize(m_ema_slow_buffer) > 0)
    {
        info += StringFormat("EMA8: %.5f | EMA21: %.5f\n", m_ema_fast_buffer[0], m_ema_slow_buffer[0]);
    }

    double atr_value = GetATRValue();
    if(atr_value > 0)
        info += StringFormat("Current ATR: %.5f\n", atr_value);

    // Enhanced component information
    info += "\n=== Enhanced Components ===\n";

    if(m_macd_signal != NULL)
        info += StringFormat("MACD: %s\n", m_macd_signal.GetSignalDescription());
    else
        info += "MACD: Disabled\n";

    if(m_mtf_bias_filter != NULL)
        info += StringFormat("MTF Bias: %s (Strength: %.2f)\n",
                            m_mtf_bias_filter.GetBiasDescription(),
                            m_mtf_bias_filter.GetBiasStrength());
    else
        info += "MTF Bias Filter: Disabled\n";

    if(m_regime_manager != NULL)
    {
        ENUM_TRADING_REGIME current_regime = m_regime_manager.GetCurrentRegime();
        info += StringFormat("Trading Regime: %s\n", EnumToString(current_regime));
    }
    else
        info += "Trading Regime: Disabled\n";

    // Risk management information
    info += "\n=== Risk Management ===\n";
    info += StringFormat("Current Drawdown: %.2f%% (Max: %.2f%%)\n",
                        m_current_drawdown, m_params.max_drawdown_percent);
    info += StringFormat("Consecutive Losses: %d\n", m_consecutive_losses);
    info += StringFormat("Dynamic Sizing: %s (Base: %.1f%%, Max: %.1f%%)\n",
                        m_params.use_dynamic_sizing ? "Enabled" : "Disabled",
                        m_params.base_risk_percent, m_params.max_risk_percent);

    return info;
}

//+------------------------------------------------------------------+
//| Detect Breakouts                                               |
//+------------------------------------------------------------------+
void CTrendFollowingStrategy::DetectBreakouts()
{
    if(!m_params.enable_breakout_logic)
        return;

    double atr_value = GetATRValue();
    if(atr_value <= 0)
        return;

    double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double breakout_threshold = atr_value * m_params.breakout_atr_multiplier;

    // Check for significant price moves
    if(ArraySize(m_ema_fast_buffer) < 5)
        return;

    double price_5_bars_ago = m_ema_fast_buffer[4]; // Use EMA as price reference
    double price_move = MathAbs(current_price - price_5_bars_ago);

    if(price_move > breakout_threshold)
    {
        bool is_upward_breakout = current_price > price_5_bars_ago;

        if(!m_breakout_detected)
        {
            // New breakout detected
            m_breakout_detected = true;
            m_waiting_for_pullback = true;
            m_breakout_is_long = is_upward_breakout;
            m_breakout_start_price = price_5_bars_ago;
            m_breakout_time = TimeCurrent();

            if(is_upward_breakout)
            {
                m_breakout_high = current_price;
                m_breakout_low = price_5_bars_ago;
            }
            else
            {
                m_breakout_high = price_5_bars_ago;
                m_breakout_low = current_price;
            }

            Print("TrendFollowingStrategy: Breakout detected - Direction: ",
                  is_upward_breakout ? "UP" : "DOWN", ", Move: ", price_move, ", Threshold: ", breakout_threshold);
        }
        else
        {
            // Update breakout levels
            if(is_upward_breakout && current_price > m_breakout_high)
                m_breakout_high = current_price;
            else if(!is_upward_breakout && current_price < m_breakout_low)
                m_breakout_low = current_price;
        }
    }

    // Reset breakout if too much time has passed
    if(m_breakout_detected && (TimeCurrent() - m_breakout_time) > 3600) // 1 hour
    {
        ResetBreakoutState();
    }
}

//+------------------------------------------------------------------+
//| Check if Breakout is Significant                              |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::IsSignificantBreakout(bool is_long)
{
    if(!m_breakout_detected)
        return false;

    if(m_breakout_is_long != is_long)
        return false;

    double atr_value = GetATRValue();
    if(atr_value <= 0)
        return false;

    double breakout_size = MathAbs(m_breakout_high - m_breakout_low);
    double required_size = atr_value * m_params.breakout_atr_multiplier;

    return (breakout_size >= required_size);
}

//+------------------------------------------------------------------+
//| Check Breakout Pullback                                       |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::CheckBreakoutPullback(bool is_long)
{
    if(!m_breakout_detected || !m_waiting_for_pullback)
        return false;

    double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);

    // Calculate Fibonacci retracement levels
    double fib_382 = CalculateFibonacciLevel(m_breakout_high, m_breakout_low, m_params.fib_382_level);
    double fib_50 = CalculateFibonacciLevel(m_breakout_high, m_breakout_low, m_params.fib_50_level);

    if(is_long)
    {
        // For long breakout, check if price has pulled back to 38.2% or 50% level
        return (current_price <= fib_382 && current_price >= fib_50);
    }
    else
    {
        // For short breakout, check if price has pulled back to 38.2% or 50% level
        return (current_price >= fib_382 && current_price <= fib_50);
    }
}

//+------------------------------------------------------------------+
//| Check RSI Momentum Confirmation                               |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::CheckRSIMomentumConfirmation(bool is_long)
{
    if(ArraySize(m_rsi_buffer) < 1)
        return true; // Skip if no RSI data

    double current_rsi = m_rsi_buffer[0];

    if(is_long)
    {
        // For long: RSI should not be overbought
        return (current_rsi < m_params.rsi_overbought);
    }
    else
    {
        // For short: RSI should not be oversold
        return (current_rsi > m_params.rsi_oversold);
    }
}

//+------------------------------------------------------------------+
//| Calculate Fibonacci Level                                     |
//+------------------------------------------------------------------+
double CTrendFollowingStrategy::CalculateFibonacciLevel(double high, double low, double fib_level)
{
    double range = high - low;
    return low + (range * fib_level);
}

//+------------------------------------------------------------------+
//| Reset Breakout State                                          |
//+------------------------------------------------------------------+
void CTrendFollowingStrategy::ResetBreakoutState()
{
    m_breakout_detected = false;
    m_waiting_for_pullback = false;
    m_breakout_high = 0.0;
    m_breakout_low = 0.0;
    m_breakout_start_price = 0.0;
    m_breakout_time = 0;
    m_breakout_is_long = false;

    Print("TrendFollowingStrategy: Breakout state reset");
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                   |
//+------------------------------------------------------------------+
bool CTrendFollowingStrategy::IsWithinTradingHours()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    // Check trading hours (inclusive end hour)
    if(dt.hour < m_params.start_hour || dt.hour > m_params.end_hour)
    {
        Print("TrendFollowingStrategy: Outside trading hours: ", dt.hour, " (allowed: ", m_params.start_hour, "-", m_params.end_hour, ")");
        return false;
    }

    // Check Friday trading
    if(!m_params.trade_on_friday && dt.day_of_week == 5) // Friday
    {
        Print("TrendFollowingStrategy: Friday trading disabled");
        return false;
    }

    return true;
}
