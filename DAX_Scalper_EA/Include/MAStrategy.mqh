//+------------------------------------------------------------------+
//|                                                   MAStrategy.mqh |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"

#include "StrategyBase.mqh"

//+------------------------------------------------------------------+
//| Moving Average Strategy class                                    |
//+------------------------------------------------------------------+
class CMAStrategy : public CStrategyBase
{
private:
    int               m_rsi_handle;       // RSI handle
    int               m_ma_fast_handle;   // Fast MA handle
    int               m_ma_slow_handle;   // Slow MA handle
    int               m_rsi_period;       // RSI period
    int               m_ma_fast_period;   // Fast MA period
    int               m_ma_slow_period;   // Slow MA period
    double            m_rsi_overbought;   // RSI overbought level
    double            m_rsi_oversold;     // RSI oversold level

    //--- Internal methods
    bool              CheckMASignal(double &ma_fast[], double &ma_slow[], bool &is_bullish, bool &has_momentum);
    bool              CheckRSIFilter(double &rsi[], bool is_long_signal);

public:
    //--- Constructor/Destructor
                      CMAStrategy(string symbol, ENUM_TIMEFRAMES timeframe);
                     ~CMAStrategy();

    //--- Strategy interface implementation
    virtual bool      Initialize() override;
    virtual void      Deinitialize() override;
    virtual SSignal   CheckSignal() override;
    virtual bool      ShouldExit(SPositionInfo& position) override;

    //--- Configuration methods
    void              SetRSIPeriod(int period) { m_rsi_period = period; }
    void              SetMAFastPeriod(int period) { m_ma_fast_period = period; }
    void              SetMASlowPeriod(int period) { m_ma_slow_period = period; }
    void              SetRSILevels(double overbought, double oversold) { m_rsi_overbought = overbought; m_rsi_oversold = oversold; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMAStrategy::CMAStrategy(string symbol, ENUM_TIMEFRAMES timeframe) : CStrategyBase("MA_Signal", symbol, timeframe)
{
    m_rsi_handle = INVALID_HANDLE;
    m_ma_fast_handle = INVALID_HANDLE;
    m_ma_slow_handle = INVALID_HANDLE;
    m_rsi_period = 9;
    m_ma_fast_period = 5;
    m_ma_slow_period = 13;
    m_rsi_overbought = 80.0;
    m_rsi_oversold = 20.0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMAStrategy::~CMAStrategy()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize strategy                                              |
//+------------------------------------------------------------------+
bool CMAStrategy::Initialize()
{
    // Create indicator handles
    m_rsi_handle = iRSI(m_symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);
    m_ma_fast_handle = iMA(m_symbol, m_timeframe, m_ma_fast_period, 0, MODE_EMA, PRICE_CLOSE);
    m_ma_slow_handle = iMA(m_symbol, m_timeframe, m_ma_slow_period, 0, MODE_EMA, PRICE_CLOSE);

    if(m_rsi_handle == INVALID_HANDLE || m_ma_fast_handle == INVALID_HANDLE || m_ma_slow_handle == INVALID_HANDLE)
    {
        if(m_logger != NULL)
            m_logger.Error("Failed to create indicator handles for MA strategy");
        return false;
    }

    if(m_logger != NULL)
        m_logger.Info("MA strategy initialized successfully");

    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize strategy                                            |
//+------------------------------------------------------------------+
void CMAStrategy::Deinitialize()
{
    if(m_rsi_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_rsi_handle);
        m_rsi_handle = INVALID_HANDLE;
    }

    if(m_ma_fast_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ma_fast_handle);
        m_ma_fast_handle = INVALID_HANDLE;
    }

    if(m_ma_slow_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ma_slow_handle);
        m_ma_slow_handle = INVALID_HANDLE;
    }

    if(m_logger != NULL)
        m_logger.Info("MA strategy deinitialized");
}

//+------------------------------------------------------------------+
//| Check for MA signal                                              |
//+------------------------------------------------------------------+
SSignal CMAStrategy::CheckSignal()
{
    SSignal signal;
    signal.is_valid = false;
    signal.confidence = 0.0;
    signal.signal_time = TimeCurrent();

    if(!m_enabled || !ValidateMarketConditions())
        return signal;

    //--- Get indicator values
    double rsi[], ma_fast[], ma_slow[];
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(ma_fast, true);
    ArraySetAsSeries(ma_slow, true);

    int rsi_copied = CopyBuffer(m_rsi_handle, 0, 0, 3, rsi);
    int ma_fast_copied = CopyBuffer(m_ma_fast_handle, 0, 0, 3, ma_fast);
    int ma_slow_copied = CopyBuffer(m_ma_slow_handle, 0, 0, 3, ma_slow);

    if(rsi_copied < 3 || ma_fast_copied < 3 || ma_slow_copied < 3)
    {
        if(m_logger != NULL)
            m_logger.Warning("Insufficient indicator data for MA analysis");
        return signal;
    }

    if(ArraySize(rsi) < 3 || ArraySize(ma_fast) < 3 || ArraySize(ma_slow) < 3)
    {
        if(m_logger != NULL)
            m_logger.Warning("Indicator array size insufficient");
        return signal;
    }

    //--- Check MA signals
    bool is_bullish, has_momentum;
    if(!CheckMASignal(ma_fast, ma_slow, is_bullish, has_momentum))
        return signal;

    //--- Apply RSI filter
    if(!CheckRSIFilter(rsi, is_bullish))
        return signal;

    //--- Generate signal
    if(is_bullish && has_momentum)
    {
        signal.is_valid = true;
        signal.signal_type = ORDER_TYPE_BUY;
        signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);

        // Calculate SL/TP based on config
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        double min_stop_level = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

        if(m_config != NULL)
        {
            // Ensure SL/TP distances are larger than minimum stop level with very large buffer for DAX
            double sl_distance = MathMax(m_config.GetStopLoss() * point, min_stop_level + 50 * point);
            double tp_distance = MathMax(m_config.GetTakeProfit() * point, min_stop_level + 50 * point);

            signal.stop_loss = signal.entry_price - sl_distance;
            signal.take_profit = signal.entry_price + tp_distance;

        }
        else
        {
            signal.stop_loss = signal.entry_price - 30 * point;
            signal.take_profit = signal.entry_price + 60 * point;
        }

        signal.confidence = 0.7;
        signal.reason = StringFormat("MA LONG: FastMA=%.5f SlowMA=%.5f RSI=%.1f",
                                    ma_fast[0], ma_slow[0], rsi[0]);

        m_stats.total_signals++;
        m_stats.last_signal_time = signal.signal_time;

        if(m_logger != NULL)
            m_logger.Info(signal.reason);
    }
    else if(!is_bullish && has_momentum)
    {
        signal.is_valid = true;
        signal.signal_type = ORDER_TYPE_SELL;
        signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);

        // Calculate SL/TP based on config
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        double min_stop_level = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

        if(m_config != NULL)
        {
            // Ensure SL/TP distances are larger than minimum stop level with very large buffer for DAX
            double sl_distance = MathMax(m_config.GetStopLoss() * point, min_stop_level + 50 * point);
            double tp_distance = MathMax(m_config.GetTakeProfit() * point, min_stop_level + 50 * point);

            signal.stop_loss = signal.entry_price + sl_distance;
            signal.take_profit = signal.entry_price - tp_distance;


        }
        else
        {
            signal.stop_loss = signal.entry_price + 30 * point;
            signal.take_profit = signal.entry_price - 60 * point;
        }

        signal.confidence = 0.7;
        signal.reason = StringFormat("MA SHORT: FastMA=%.5f SlowMA=%.5f RSI=%.1f",
                                    ma_fast[0], ma_slow[0], rsi[0]);

        m_stats.total_signals++;
        m_stats.last_signal_time = signal.signal_time;

        if(m_logger != NULL)
            m_logger.Info(signal.reason);
    }

    return signal;
}

//+------------------------------------------------------------------+
//| Check if position should be exited                              |
//+------------------------------------------------------------------+
bool CMAStrategy::ShouldExit(SPositionInfo& position)
{
    if(!position.exists) return false;

    // Get current RSI value for exit signal
    double rsi[];
    ArraySetAsSeries(rsi, true);

    int rsi_copied = CopyBuffer(m_rsi_handle, 0, 0, 1, rsi);
    if(rsi_copied < 1 || ArraySize(rsi) < 1)
        return false;

    // Exit long positions if RSI is overbought
    if(position.type == POSITION_TYPE_BUY && rsi[0] > m_rsi_overbought)
    {
        if(m_logger != NULL)
            m_logger.Info("Long position exit due to RSI overbought: " + DoubleToString(rsi[0], 1));
        return true;
    }

    // Exit short positions if RSI is oversold
    if(position.type == POSITION_TYPE_SELL && rsi[0] < m_rsi_oversold)
    {
        if(m_logger != NULL)
            m_logger.Info("Short position exit due to RSI oversold: " + DoubleToString(rsi[0], 1));
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check MA signal conditions                                       |
//+------------------------------------------------------------------+
bool CMAStrategy::CheckMASignal(double &ma_fast[], double &ma_slow[], bool &is_bullish, bool &has_momentum)
{
    is_bullish = false;
    has_momentum = false;

    // Check MA alignment
    bool ma_bullish = (ma_fast[0] > ma_slow[0]);
    bool ma_bearish = (ma_fast[0] < ma_slow[0]);

    // Check momentum
    bool ma_momentum_up = (ma_fast[0] > ma_fast[1] && ma_slow[0] >= ma_slow[1]);
    bool ma_momentum_down = (ma_fast[0] < ma_fast[1] && ma_slow[0] <= ma_slow[1]);

    if(ma_bullish && ma_momentum_up)
    {
        is_bullish = true;
        has_momentum = true;
        return true;
    }
    else if(ma_bearish && ma_momentum_down)
    {
        is_bullish = false;
        has_momentum = true;
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check RSI filter                                                 |
//+------------------------------------------------------------------+
bool CMAStrategy::CheckRSIFilter(double &rsi[], bool is_long_signal)
{
    // Strict RSI filter to reduce bad trades
    bool rsi_not_extreme_high = (rsi[0] < 70.0);  // More strict for long signals
    bool rsi_not_extreme_low = (rsi[0] > 30.0);   // More strict for short signals

    if(is_long_signal)
        return rsi_not_extreme_high;
    else
        return rsi_not_extreme_low;
}