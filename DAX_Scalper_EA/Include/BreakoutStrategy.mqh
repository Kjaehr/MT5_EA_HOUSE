//+------------------------------------------------------------------+
//|                                            BreakoutStrategy.mqh |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"

#include "StrategyBase.mqh"

//+------------------------------------------------------------------+
//| Breakout Strategy class                                          |
//+------------------------------------------------------------------+
class CBreakoutStrategy : public CStrategyBase
{
private:
    int               m_ema50_handle;     // EMA50 handle for trend bias
    int               m_lookback_bars;    // Bars to look for breakout
    double            m_retest_buffer;    // Retest buffer in points
    double            m_range_multiplier; // TP multiplier
    double            m_min_range_quality;// Minimum body-to-range ratio

    //--- Internal methods
    bool              CheckRangeQuality(double &high[], double &low[], double &open[], double &close[]);
    bool              CheckTrendBias(bool is_long);
    double            CalculateRangeTP(double entry_price, double range, bool is_long);

public:
    //--- Constructor/Destructor
                      CBreakoutStrategy(string symbol, ENUM_TIMEFRAMES timeframe);
                     ~CBreakoutStrategy();

    //--- Strategy interface implementation
    virtual bool      Initialize() override;
    virtual void      Deinitialize() override;
    virtual SSignal   CheckSignal() override;
    virtual bool      ShouldExit(SPositionInfo& position) override;

    //--- Configuration methods
    void              SetLookbackBars(int bars) { m_lookback_bars = bars; }
    void              SetRetestBuffer(double buffer) { m_retest_buffer = buffer; }
    void              SetRangeMultiplier(double multiplier) { m_range_multiplier = multiplier; }
    void              SetMinRangeQuality(double quality) { m_min_range_quality = quality; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBreakoutStrategy::CBreakoutStrategy(string symbol, ENUM_TIMEFRAMES timeframe) : CStrategyBase("Breakout", symbol, timeframe)
{
    m_ema50_handle = INVALID_HANDLE;
    m_lookback_bars = 4;
    m_retest_buffer = 2.0;
    m_range_multiplier = 1.25;
    m_min_range_quality = 0.33;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBreakoutStrategy::~CBreakoutStrategy()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize strategy                                              |
//+------------------------------------------------------------------+
bool CBreakoutStrategy::Initialize()
{
    // Create EMA50 handle for trend bias on M15
    m_ema50_handle = iMA(m_symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);

    if(m_ema50_handle == INVALID_HANDLE)
    {
        if(m_logger != NULL)
            m_logger.Error("Failed to create EMA50 handle for breakout strategy");
        return false;
    }

    if(m_logger != NULL)
        m_logger.Info("Breakout strategy initialized successfully");

    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize strategy                                            |
//+------------------------------------------------------------------+
void CBreakoutStrategy::Deinitialize()
{
    if(m_ema50_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ema50_handle);
        m_ema50_handle = INVALID_HANDLE;
    }

    if(m_logger != NULL)
        m_logger.Info("Breakout strategy deinitialized");
}

//+------------------------------------------------------------------+
//| Check for breakout signal                                        |
//+------------------------------------------------------------------+
SSignal CBreakoutStrategy::CheckSignal()
{
    SSignal signal;
    signal.is_valid = false;
    signal.confidence = 0.0;
    signal.signal_time = TimeCurrent();

    if(!m_enabled || !ValidateMarketConditions())
        return signal;

    //--- Get price data
    double high[], low[], close[], open[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);

    // Need current + previous bar for retest logic
    int bars_needed = m_lookback_bars + 2;
    int high_copied = CopyHigh(m_symbol, m_timeframe, 0, bars_needed, high);
    int low_copied = CopyLow(m_symbol, m_timeframe, 0, bars_needed, low);
    int close_copied = CopyClose(m_symbol, m_timeframe, 0, bars_needed, close);
    int open_copied = CopyOpen(m_symbol, m_timeframe, 0, bars_needed, open);

    if(high_copied < bars_needed || low_copied < bars_needed ||
       close_copied < bars_needed || open_copied < bars_needed)
    {
        if(m_logger != NULL)
            m_logger.Warning("Insufficient data for breakout analysis");
        return signal;
    }

    //--- Calculate range from bars 2-5 (skip current and previous bar)
    double breakout_high = high[ArrayMaximum(high, 2, m_lookback_bars)];
    double breakout_low = low[ArrayMinimum(low, 2, m_lookback_bars)];
    double range = breakout_high - breakout_low;

    //--- Check range quality
    double quality_high[], quality_low[], quality_open[], quality_close[];
    ArrayResize(quality_high, m_lookback_bars);
    ArrayResize(quality_low, m_lookback_bars);
    ArrayResize(quality_open, m_lookback_bars);
    ArrayResize(quality_close, m_lookback_bars);

    for(int i = 0; i < m_lookback_bars; i++)
    {
        quality_high[i] = high[i + 2];
        quality_low[i] = low[i + 2];
        quality_open[i] = open[i + 2];
        quality_close[i] = close[i + 2];
    }

    if(!CheckRangeQuality(quality_high, quality_low, quality_open, quality_close))
    {
        return signal;
    }

    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double retest_buffer_price = m_retest_buffer * point;

    //--- LONG: Previous bar closed above breakout_high, current bar retests and closes up
    bool long_breakout = close[1] > breakout_high;  // Previous bar broke above
    bool long_retest = low[0] <= (breakout_high + retest_buffer_price) &&
                       low[0] >= (breakout_high - retest_buffer_price);  // Current bar retested
    bool long_close_up = close[0] > open[0];  // Current bar closed up

    //--- SHORT: Previous bar closed below breakout_low, current bar retests and closes down
    bool short_breakout = close[1] < breakout_low;  // Previous bar broke below
    bool short_retest = high[0] >= (breakout_low - retest_buffer_price) &&
                        high[0] <= (breakout_low + retest_buffer_price);  // Current bar retested
    bool short_close_down = close[0] < open[0];  // Current bar closed down

    if(long_breakout && long_retest && long_close_up && CheckTrendBias(true))
    {
        signal.is_valid = true;
        signal.signal_type = ORDER_TYPE_BUY;
        signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        signal.stop_loss = breakout_low - 2.0 * point;
        signal.take_profit = CalculateRangeTP(signal.entry_price, range, true);
        signal.confidence = 0.8;
        signal.reason = StringFormat("BREAKOUT LONG: Range=%.1f points, High=%.5f Retest=%.5f",
                                     range/point, breakout_high, low[0]);

        m_stats.total_signals++;
        m_stats.last_signal_time = signal.signal_time;

        if(m_logger != NULL)
        {
            m_logger.Info(signal.reason + StringFormat(" SL=%.5f TP=%.5f",
                          signal.stop_loss, signal.take_profit));
        }
    }
    else if(short_breakout && short_retest && short_close_down && CheckTrendBias(false))
    {
        signal.is_valid = true;
        signal.signal_type = ORDER_TYPE_SELL;
        signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        signal.stop_loss = breakout_high + 2.0 * point;
        signal.take_profit = CalculateRangeTP(signal.entry_price, range, false);
        signal.confidence = 0.8;
        signal.reason = StringFormat("BREAKOUT SHORT: Range=%.1f points, Low=%.5f Retest=%.5f",
                                     range/point, breakout_low, high[0]);

        m_stats.total_signals++;
        m_stats.last_signal_time = signal.signal_time;

        if(m_logger != NULL)
        {
            m_logger.Info(signal.reason + StringFormat(" SL=%.5f TP=%.5f",
                          signal.stop_loss, signal.take_profit));
        }
    }

    return signal;
}

//+------------------------------------------------------------------+
//| Check if position should be exited                              |
//+------------------------------------------------------------------+
bool CBreakoutStrategy::ShouldExit(SPositionInfo& position)
{
    // Basic exit conditions - can be enhanced
    if(!position.exists) return false;

    // Time-based exit (optional)
    datetime current_time = TimeCurrent();
    int position_age_minutes = (int)((current_time - position.open_time) / 60);

    if(position_age_minutes > 240) // 4 hours max
    {
        if(m_logger != NULL)
            m_logger.Info("Position exit due to time limit (4 hours)");
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check range quality using body-to-range ratio                   |
//+------------------------------------------------------------------+
bool CBreakoutStrategy::CheckRangeQuality(double &high[], double &low[], double &open[], double &close[])
{
    double total_body = 0.0;
    double total_range = 0.0;

    for(int i = 0; i < m_lookback_bars; i++)
    {
        total_body += MathAbs(close[i] - open[i]);
        total_range += (high[i] - low[i]);
    }

    double quality = (total_range > 0) ? total_body / total_range : 0.0;
    return quality >= m_min_range_quality;
}

//+------------------------------------------------------------------+
//| Check M15 EMA50 trend bias                                       |
//+------------------------------------------------------------------+
bool CBreakoutStrategy::CheckTrendBias(bool is_long)
{
    double ema50[];
    ArraySetAsSeries(ema50, true);

    int copied = CopyBuffer(m_ema50_handle, 0, 0, 16, ema50);
    if(copied < 16 || ArraySize(ema50) < 16)
        return false;

    // Calculate slope: current vs 15 bars ago
    double slope = ema50[0] - ema50[15];

    if(is_long)
        return slope > 0;  // Uptrend for long
    else
        return slope < 0;  // Downtrend for short
}

//+------------------------------------------------------------------+
//| Calculate range-based take profit                               |
//+------------------------------------------------------------------+
double CBreakoutStrategy::CalculateRangeTP(double entry_price, double range, bool is_long)
{
    double tp_distance = m_range_multiplier * range;

    if(is_long)
        return entry_price + tp_distance;
    else
        return entry_price - tp_distance;
}