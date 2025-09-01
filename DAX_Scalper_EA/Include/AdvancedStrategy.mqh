//+------------------------------------------------------------------+
//|                                           AdvancedStrategy.mqh |
//|                                  Copyright 2024, Tobias Kjaehr   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Tobias Kjaehr"
#property link      ""
#property version   "1.00"

#include "StrategyBase.mqh"
#include "IndicatorManager.mqh"
#include "TradeManager.mqh"

//+------------------------------------------------------------------+
//| Advanced Strategy using all 5 indicators                        |
//+------------------------------------------------------------------+
class CAdvancedStrategy : public CStrategyBase
{
private:
    CIndicatorManager*    m_indicator_manager;
    
    // Strategy parameters
    double                m_min_signal_strength;
    double                m_exit_signal_threshold;
    int                   m_confirmation_bars;
    bool                  m_use_regime_filter;
    bool                  m_use_volume_filter;
    bool                  m_use_microstructure_filter;
    
    // Position management
    bool                  m_in_position;
    int                   m_position_type;  // 1=long, -1=short
    datetime              m_entry_time;
    double                m_entry_price;
    
    // Signal tracking
    SIndicatorSignals     m_last_signals;
    int                   m_signal_confirmation_count;
    
public:
    //--- Constructor/Destructor
    CAdvancedStrategy(string symbol, ENUM_TIMEFRAMES timeframe);
    ~CAdvancedStrategy();
    
    //--- Initialization
    virtual bool Initialize() override;
    virtual void Deinitialize() override;
    
    //--- Configuration
    void SetMinSignalStrength(double strength) { m_min_signal_strength = strength; }
    void SetExitThreshold(double threshold) { m_exit_signal_threshold = threshold; }
    void SetConfirmationBars(int bars) { m_confirmation_bars = bars; }
    void SetRegimeFilter(bool enable) { m_use_regime_filter = enable; }
    void SetVolumeFilter(bool enable) { m_use_volume_filter = enable; }
    void SetMicrostructureFilter(bool enable) { m_use_microstructure_filter = enable; }
    
    //--- Strategy execution
    virtual void OnTick() override;
    virtual void OnBar();

    //--- Signal analysis
    virtual bool CheckLongEntry();
    virtual bool CheckShortEntry();
    virtual bool CheckLongExit();
    virtual bool CheckShortExit();

    //--- Position management
    virtual void OnPositionOpened(int ticket, int type, double volume, double price);
    virtual void OnPositionClosed(int ticket, double profit);
    
    //--- Base class pure virtual methods (must be implemented)
    virtual SSignal CheckSignal() override;
    virtual bool ShouldExit(SPositionInfo& position) override;

    //--- Information
    virtual string GetStrategyInfo() override;
    
private:
    //--- Internal methods
    bool UpdateIndicators();
    bool ValidateEntry(bool is_long);
    bool ValidateExit();
    void UpdatePositionStatus();
    double CalculatePositionSize(bool is_long);
    void LogSignalAnalysis();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAdvancedStrategy::CAdvancedStrategy(string symbol, ENUM_TIMEFRAMES timeframe) : CStrategyBase("AdvancedStrategy", symbol, timeframe)
{
    m_indicator_manager = NULL;
    
    // Default parameters
    m_min_signal_strength = 0.6;
    m_exit_signal_threshold = 0.4;
    m_confirmation_bars = 2;
    m_use_regime_filter = true;
    m_use_volume_filter = true;
    m_use_microstructure_filter = true;
    
    // Position tracking
    m_in_position = false;
    m_position_type = 0;
    m_entry_time = 0;
    m_entry_price = 0.0;
    
    // Signal tracking
    ZeroMemory(m_last_signals);
    m_signal_confirmation_count = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAdvancedStrategy::~CAdvancedStrategy()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize strategy                                              |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::Initialize()
{
    if(!CStrategyBase::Initialize())
        return false;
    
    // Create indicator manager
    m_indicator_manager = new CIndicatorManager(m_symbol, m_timeframe);
    if(m_indicator_manager == NULL)
    {
        if(m_logger != NULL)
            m_logger.Error("Failed to create indicator manager");
        return false;
    }
    
    // Configure indicator manager
    m_indicator_manager.SetLogger(m_logger);
    m_indicator_manager.SetSignalThreshold(m_min_signal_strength);
    m_indicator_manager.SetLookbackBars(m_confirmation_bars);
    
    // DISABLE ALL PROBLEMATIC INDICATORS - Use only simple profitable strategies
    m_indicator_manager.EnableMomentum(false);        // DISABLE Multi-Timeframe Momentum
    m_indicator_manager.EnableRegime(false);          // DISABLE Market Regime Filter
    m_indicator_manager.EnableSMC(false);             // DISABLE Smart Money Concepts
    m_indicator_manager.EnableVolume(false);          // DISABLE Volume Profile
    m_indicator_manager.EnableMicrostructure(false);  // DISABLE Microstructure
    
    // Initialize indicator manager
    if(!m_indicator_manager.Initialize())
    {
        if(m_logger != NULL)
            m_logger.Error("Failed to initialize indicator manager");
        return false;
    }
    
    if(m_logger != NULL)
        m_logger.Info("Advanced Strategy initialized successfully");
    
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize strategy                                            |
//+------------------------------------------------------------------+
void CAdvancedStrategy::Deinitialize()
{
    if(m_indicator_manager != NULL)
    {
        m_indicator_manager.Deinitialize();
        delete m_indicator_manager;
        m_indicator_manager = NULL;
    }
    
    CStrategyBase::Deinitialize();
}

//+------------------------------------------------------------------+
//| On tick event                                                    |
//+------------------------------------------------------------------+
void CAdvancedStrategy::OnTick()
{
    if(!m_is_initialized)
        return;

    // Only update position status - no heavy calculations on every tick
    UpdatePositionStatus();

    // Skip indicator updates on tick for performance - only update on new bars
    // Microstructure is disabled anyway for performance
}

//+------------------------------------------------------------------+
//| On bar event                                                     |
//+------------------------------------------------------------------+
void CAdvancedStrategy::OnBar()
{
    if(!m_is_initialized)
        return;
    
    // Update all indicators
    if(!UpdateIndicators())
    {
        if(m_logger != NULL)
            m_logger.Debug("Indicators not ready yet");
        return;
    }
    
    // Log signal analysis
    LogSignalAnalysis();
    
    // Check for exit signals first
    if(m_in_position)
    {
        if(ValidateExit())
        {
            if(m_logger != NULL)
                m_logger.Info("Exit signal detected");
            // Exit logic will be handled by the main EA
        }
        return; // Don't look for new entries while in position
    }
    
    // Check for entry signals
    if(CheckLongEntry())
    {
        if(m_logger != NULL)
            m_logger.Info("Long entry signal confirmed");
    }
    else if(CheckShortEntry())
    {
        if(m_logger != NULL)
            m_logger.Info("Short entry signal confirmed");
    }
}

//+------------------------------------------------------------------+
//| Update indicators                                                |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::UpdateIndicators()
{
    if(m_indicator_manager == NULL)
        return false;
    
    return m_indicator_manager.UpdateSignals();
}

//+------------------------------------------------------------------+
//| Check long entry conditions                                      |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::CheckLongEntry()
{
    if(m_indicator_manager == NULL || !m_indicator_manager.AreIndicatorsReady())
        return false;
    
    // Get current signals
    SIndicatorSignals signals = m_indicator_manager.GetCurrentSignals();
    
    // Check if we have a bullish signal
    if(!signals.strong_bullish_signal || !signals.entry_confirmation)
        return false;
    
    // Validate entry conditions
    if(!ValidateEntry(true))
        return false;
    
    // Check signal strength
    if(signals.signal_strength < m_min_signal_strength)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check short entry conditions                                     |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::CheckShortEntry()
{
    if(m_indicator_manager == NULL || !m_indicator_manager.AreIndicatorsReady())
        return false;
    
    // Get current signals
    SIndicatorSignals signals = m_indicator_manager.GetCurrentSignals();
    
    // Check if we have a bearish signal
    if(!signals.strong_bearish_signal || !signals.entry_confirmation)
        return false;
    
    // Validate entry conditions
    if(!ValidateEntry(false))
        return false;
    
    // Check signal strength
    if(signals.signal_strength < m_min_signal_strength)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check long exit conditions                                       |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::CheckLongExit()
{
    if(!m_in_position || m_position_type != 1)
        return false;

    if(m_indicator_manager == NULL)
        return false;

    SIndicatorSignals signals = m_indicator_manager.GetCurrentSignals();

    // Exit on strong bearish signal
    if(signals.strong_bearish_signal && signals.signal_strength > m_exit_signal_threshold)
        return true;

    // Exit on explicit exit signal
    if(signals.exit_signal)
        return true;

    // Exit on momentum reversal
    if(signals.momentum.bearish_confluence)
        return true;

    return false;
}

//+------------------------------------------------------------------+
//| Check short exit conditions                                      |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::CheckShortExit()
{
    if(!m_in_position || m_position_type != -1)
        return false;

    if(m_indicator_manager == NULL)
        return false;

    SIndicatorSignals signals = m_indicator_manager.GetCurrentSignals();

    // Exit on strong bullish signal
    if(signals.strong_bullish_signal && signals.signal_strength > m_exit_signal_threshold)
        return true;

    // Exit on explicit exit signal
    if(signals.exit_signal)
        return true;

    // Exit on momentum reversal
    if(signals.momentum.bullish_confluence)
        return true;

    return false;
}

//+------------------------------------------------------------------+
//| Validate entry conditions                                        |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::ValidateEntry(bool is_long)
{
    if(m_indicator_manager == NULL)
        return false;

    SIndicatorSignals signals = m_indicator_manager.GetCurrentSignals();

    // Regime filter
    if(m_use_regime_filter)
    {
        // Avoid trading in ranging markets
        if(signals.regime.regime_type == 0 && signals.regime.volatility_index < 30.0)
            return false;

        // Check trend alignment
        if(is_long && signals.regime.trend_strength < 40.0)
            return false;
        if(!is_long && signals.regime.trend_strength > 60.0)
            return false;
    }

    // Volume filter
    if(m_use_volume_filter)
    {
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);

        // For long entries, prefer price above POC
        if(is_long && current_price < signals.volume.poc_price)
            return false;

        // For short entries, prefer price below POC
        if(!is_long && current_price > signals.volume.poc_price)
            return false;
    }

    // Microstructure filter
    if(m_use_microstructure_filter)
    {
        // Check tick direction alignment
        if(is_long && signals.microstructure.tick_direction < -20.0)
            return false;
        if(!is_long && signals.microstructure.tick_direction > 20.0)
            return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Validate exit conditions                                         |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::ValidateExit()
{
    if(m_position_type == 1)
        return CheckLongExit();
    else if(m_position_type == -1)
        return CheckShortExit();

    return false;
}

//+------------------------------------------------------------------+
//| Update position status                                           |
//+------------------------------------------------------------------+
void CAdvancedStrategy::UpdatePositionStatus()
{
    // This would typically check with the trade manager
    // For now, we'll rely on the OnPositionOpened/Closed callbacks
}

//+------------------------------------------------------------------+
//| Position opened callback                                         |
//+------------------------------------------------------------------+
void CAdvancedStrategy::OnPositionOpened(int ticket, int type, double volume, double price)
{
    m_in_position = true;
    m_position_type = (type == ORDER_TYPE_BUY) ? 1 : -1;
    m_entry_time = TimeCurrent();
    m_entry_price = price;

    if(m_logger != NULL)
    {
        string direction = (m_position_type == 1) ? "LONG" : "SHORT";
        m_logger.Info(StringFormat("Position opened: %s at %.2f, Ticket: %d",
                                  direction, price, ticket));
    }
}

//+------------------------------------------------------------------+
//| Position closed callback                                         |
//+------------------------------------------------------------------+
void CAdvancedStrategy::OnPositionClosed(int ticket, double profit)
{
    if(m_logger != NULL)
    {
        string direction = (m_position_type == 1) ? "LONG" : "SHORT";
        m_logger.Info(StringFormat("Position closed: %s, Profit: %.2f, Ticket: %d",
                                  direction, profit, ticket));
    }

    m_in_position = false;
    m_position_type = 0;
    m_entry_time = 0;
    m_entry_price = 0.0;
}

//+------------------------------------------------------------------+
//| Get strategy information                                         |
//+------------------------------------------------------------------+
string CAdvancedStrategy::GetStrategyInfo()
{
    string info = "Advanced Multi-Indicator Strategy\n";
    info += "Signal Strength Threshold: " + DoubleToString(m_min_signal_strength, 2) + "\n";
    info += "Exit Threshold: " + DoubleToString(m_exit_signal_threshold, 2) + "\n";
    info += "Confirmation Bars: " + IntegerToString(m_confirmation_bars) + "\n";
    info += "Filters: ";
    if(m_use_regime_filter) info += "Regime ";
    if(m_use_volume_filter) info += "Volume ";
    if(m_use_microstructure_filter) info += "Microstructure ";
    info += "\n";

    if(m_indicator_manager != NULL)
    {
        info += "Current Signals: " + m_indicator_manager.GetSignalSummary() + "\n";
    }

    return info;
}

//+------------------------------------------------------------------+
//| Log signal analysis                                              |
//+------------------------------------------------------------------+
void CAdvancedStrategy::LogSignalAnalysis()
{
    if(m_logger == NULL || m_indicator_manager == NULL)
        return;

    SIndicatorSignals signals = m_indicator_manager.GetCurrentSignals();

    // Only log when signal strength is significant
    if(signals.signal_strength > 0.3)
    {
        m_logger.Debug("Signal Analysis: " + m_indicator_manager.GetSignalSummary());
    }
}

//+------------------------------------------------------------------+
//| Check signal (base class implementation)                        |
//+------------------------------------------------------------------+
SSignal CAdvancedStrategy::CheckSignal()
{
    SSignal signal;
    signal.is_valid = false;
    signal.confidence = 0.0;
    signal.signal_time = TimeCurrent();
    signal.reason = "";

    if(!m_is_initialized || m_indicator_manager == NULL)
        return signal;

    // Check for long entry
    if(CheckLongEntry())
    {
        signal.is_valid = true;
        signal.signal_type = ORDER_TYPE_BUY;
        signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        signal.confidence = m_indicator_manager.GetCurrentSignals().signal_strength;
        signal.reason = "Advanced Strategy Long Entry";

        // Calculate stop loss and take profit using config values
        // For DAX, use direct point values (not SYMBOL_POINT which is too small)
        if(m_config != NULL)
        {
            signal.stop_loss = signal.entry_price - m_config.GetStopLoss();  // Direct points
            signal.take_profit = signal.entry_price + m_config.GetTakeProfit(); // Direct points
        }
        else
        {
            // Default values for DAX (30 points SL, 60 points TP)
            signal.stop_loss = signal.entry_price - 30.0;
            signal.take_profit = signal.entry_price + 60.0;
        }
    }
    // Check for short entry
    else if(CheckShortEntry())
    {
        signal.is_valid = true;
        signal.signal_type = ORDER_TYPE_SELL;
        signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        signal.confidence = m_indicator_manager.GetCurrentSignals().signal_strength;
        signal.reason = "Advanced Strategy Short Entry";

        // Calculate stop loss and take profit using config values
        // For DAX, use direct point values (not SYMBOL_POINT which is too small)
        if(m_config != NULL)
        {
            signal.stop_loss = signal.entry_price + m_config.GetStopLoss();  // Direct points
            signal.take_profit = signal.entry_price - m_config.GetTakeProfit(); // Direct points
        }
        else
        {
            // Default values for DAX (30 points SL, 60 points TP)
            signal.stop_loss = signal.entry_price + 30.0;
            signal.take_profit = signal.entry_price - 60.0;
        }
    }

    return signal;
}

//+------------------------------------------------------------------+
//| Should exit position (base class implementation)                |
//+------------------------------------------------------------------+
bool CAdvancedStrategy::ShouldExit(SPositionInfo& position)
{
    if(!position.exists || !m_is_initialized)
        return false;

    // Update our internal position tracking
    if(!m_in_position)
    {
        m_in_position = true;
        m_position_type = (position.type == POSITION_TYPE_BUY) ? 1 : -1;
        m_entry_time = position.open_time;
        m_entry_price = position.open_price;
    }

    // Use our existing exit logic
    return ValidateExit();
}

//+------------------------------------------------------------------+
//| Calculate position size                                          |
//+------------------------------------------------------------------+
double CAdvancedStrategy::CalculatePositionSize(bool is_long)
{
    // Basic position sizing - should be enhanced with proper risk management
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_percent = 0.02; // 2% risk per trade
    double risk_amount = account_balance * risk_percent;

    // Calculate position size based on stop loss distance
    double entry_price = is_long ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);
    // For DAX, use direct point values (not SYMBOL_POINT which is too small)
    double stop_distance = (m_config != NULL) ? m_config.GetStopLoss() : 30.0;

    double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);

    if(tick_value == 0 || tick_size == 0 || stop_distance == 0)
        return 0.1; // Default minimum lot size

    double position_size = risk_amount / (stop_distance / tick_size * tick_value);

    // Apply lot size constraints
    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

    position_size = MathMax(position_size, min_lot);
    position_size = MathMin(position_size, max_lot);
    position_size = MathRound(position_size / lot_step) * lot_step;

    return position_size;
}
