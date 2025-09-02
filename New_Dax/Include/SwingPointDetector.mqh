//+------------------------------------------------------------------+
//|                                           SwingPointDetector.mqh |
//|                                   Swing Point Detection Class    |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Swing Point structure                                           |
//+------------------------------------------------------------------+
struct SSwingPoint
{
    datetime          time;
    double            price;
    int               bar_index;
    bool              is_high;
    bool              is_valid;
};

//+------------------------------------------------------------------+
//| Swing Point Detection Class                                    |
//+------------------------------------------------------------------+
class CSwingPointDetector
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    
    // Detection parameters
    int               m_lookback_bars;
    int               m_min_swing_distance;
    double            m_min_swing_size;
    
    // Swing point data
    SSwingPoint       m_last_swing_high;
    SSwingPoint       m_last_swing_low;
    SSwingPoint       m_previous_swing_high;
    SSwingPoint       m_previous_swing_low;
    
    // Arrays for swing points history
    SSwingPoint       m_swing_highs[];
    SSwingPoint       m_swing_lows[];
    int               m_max_history;
    
    bool              m_initialized;

public:
    //--- Constructor/Destructor
                      CSwingPointDetector(string symbol, ENUM_TIMEFRAMES timeframe,
                                         int lookback_bars = 5, int max_history = 50);
                     ~CSwingPointDetector();
    
    //--- Initialization
    bool              Initialize();
    
    //--- Main detection methods
    bool              UpdateSwingPoints();
    bool              DetectNewSwingPoints();
    
    //--- Swing point access methods
    SSwingPoint       GetLastSwingHigh() const { return m_last_swing_high; }
    SSwingPoint       GetLastSwingLow() const { return m_last_swing_low; }
    SSwingPoint       GetPreviousSwingHigh() const { return m_previous_swing_high; }
    SSwingPoint       GetPreviousSwingLow() const { return m_previous_swing_low; }
    
    //--- Stop loss calculation methods
    double            GetBullishStopLoss(double entry_price, int pip_buffer = 5);
    double            GetBearishStopLoss(double entry_price, int pip_buffer = 5);
    double            GetDynamicStopLoss(bool is_long, double entry_price, int pip_buffer = 5);
    
    //--- Utility methods
    bool              IsSwingHigh(int bar_index);
    bool              IsSwingLow(int bar_index);
    double            GetSwingHighPrice(int bars_back = 0);
    double            GetSwingLowPrice(int bars_back = 0);
    double            FindNearestSwingLow(double reference_price);
    double            FindNearestSwingHigh(double reference_price);
    
    //--- Configuration methods
    void              SetLookbackBars(int lookback) { if(lookback > 0) m_lookback_bars = lookback; }
    void              SetMinSwingDistance(int distance) { if(distance > 0) m_min_swing_distance = distance; }
    void              SetMinSwingSize(double size) { if(size > 0) m_min_swing_size = size; }
    
    //--- Information methods
    bool              IsInitialized() const { return m_initialized; }
    string            GetSwingPointsInfo();
    int               GetSwingHighsCount() const { return ArraySize(m_swing_highs); }
    int               GetSwingLowsCount() const { return ArraySize(m_swing_lows); }

private:
    //--- Internal methods
    bool              DetectSwingHigh(int bar_index);
    bool              DetectSwingLow(int bar_index);
    void              AddSwingHigh(SSwingPoint &swing_point);
    void              AddSwingLow(SSwingPoint &swing_point);
    bool              ValidateSwingPoint(const SSwingPoint &swing_point);
    void              InitializeSwingPoint(SSwingPoint &swing_point);
    double            CalculateStopLossLevel(double reference_price, bool is_long, int pip_buffer);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSwingPointDetector::CSwingPointDetector(string symbol, ENUM_TIMEFRAMES timeframe,
                                        int lookback_bars, int max_history)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_lookback_bars = lookback_bars;
    m_max_history = max_history;
    
    // Set default parameters
    m_min_swing_distance = 3;
    m_min_swing_size = 0.0; // Will be calculated based on symbol
    
    // Initialize swing points
    InitializeSwingPoint(m_last_swing_high);
    InitializeSwingPoint(m_last_swing_low);
    InitializeSwingPoint(m_previous_swing_high);
    InitializeSwingPoint(m_previous_swing_low);
    
    // Initialize arrays
    ArrayResize(m_swing_highs, 0);
    ArrayResize(m_swing_lows, 0);
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSwingPointDetector::~CSwingPointDetector()
{
    ArrayFree(m_swing_highs);
    ArrayFree(m_swing_lows);
}

//+------------------------------------------------------------------+
//| Initialize swing point detector                                |
//+------------------------------------------------------------------+
bool CSwingPointDetector::Initialize()
{
    if(StringLen(m_symbol) == 0)
    {
        Print("SwingPointDetector: Invalid symbol");
        return false;
    }
    
    // Calculate minimum swing size based on symbol characteristics
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    m_min_swing_size = 10 * point; // Minimum 10 points swing
    
    // Detect initial swing points
    if(!DetectNewSwingPoints())
    {
        Print("SwingPointDetector: Failed to detect initial swing points");
        return false;
    }
    
    m_initialized = true;
    Print("SwingPointDetector: Initialized successfully for ", m_symbol, " on ", EnumToString(m_timeframe));
    Print("SwingPointDetector: Lookback bars: ", m_lookback_bars, " Min swing size: ", m_min_swing_size);
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize swing point structure                               |
//+------------------------------------------------------------------+
void CSwingPointDetector::InitializeSwingPoint(SSwingPoint &swing_point)
{
    swing_point.time = 0;
    swing_point.price = 0.0;
    swing_point.bar_index = -1;
    swing_point.is_high = false;
    swing_point.is_valid = false;
}

//+------------------------------------------------------------------+
//| Update swing points                                            |
//+------------------------------------------------------------------+
bool CSwingPointDetector::UpdateSwingPoints()
{
    if(!m_initialized)
        return false;
    
    return DetectNewSwingPoints();
}

//+------------------------------------------------------------------+
//| Detect new swing points                                       |
//+------------------------------------------------------------------+
bool CSwingPointDetector::DetectNewSwingPoints()
{
    int bars_to_check = 15; // Drastically reduced to 15 bars for recent swing points only

    for(int i = m_lookback_bars; i < bars_to_check; i++)
    {
        // Check for swing high
        if(IsSwingHigh(i))
        {
            DetectSwingHigh(i);
        }

        // Check for swing low
        if(IsSwingLow(i))
        {
            DetectSwingLow(i);
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check if bar is a swing high                                  |
//+------------------------------------------------------------------+
bool CSwingPointDetector::IsSwingHigh(int bar_index)
{
    if(bar_index < m_lookback_bars)
        return false;
    
    double current_high = iHigh(m_symbol, m_timeframe, bar_index);
    if(current_high <= 0)
        return false;
    
    // Check if current high is higher than surrounding bars
    for(int i = 1; i <= m_lookback_bars; i++)
    {
        double left_high = iHigh(m_symbol, m_timeframe, bar_index + i);
        double right_high = iHigh(m_symbol, m_timeframe, bar_index - i);
        
        if(left_high >= current_high || right_high >= current_high)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if bar is a swing low                                   |
//+------------------------------------------------------------------+
bool CSwingPointDetector::IsSwingLow(int bar_index)
{
    if(bar_index < m_lookback_bars)
        return false;
    
    double current_low = iLow(m_symbol, m_timeframe, bar_index);
    if(current_low <= 0)
        return false;
    
    // Check if current low is lower than surrounding bars
    for(int i = 1; i <= m_lookback_bars; i++)
    {
        double left_low = iLow(m_symbol, m_timeframe, bar_index + i);
        double right_low = iLow(m_symbol, m_timeframe, bar_index - i);
        
        if(left_low <= current_low || right_low <= current_low)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect swing high                                             |
//+------------------------------------------------------------------+
bool CSwingPointDetector::DetectSwingHigh(int bar_index)
{
    SSwingPoint new_swing_high;
    new_swing_high.time = iTime(m_symbol, m_timeframe, bar_index);
    new_swing_high.price = iHigh(m_symbol, m_timeframe, bar_index);
    new_swing_high.bar_index = bar_index;
    new_swing_high.is_high = true;
    new_swing_high.is_valid = true;
    
    if(!ValidateSwingPoint(new_swing_high))
        return false;
    
    // Update swing high history
    m_previous_swing_high = m_last_swing_high;
    m_last_swing_high = new_swing_high;
    
    AddSwingHigh(new_swing_high);
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect swing low                                              |
//+------------------------------------------------------------------+
bool CSwingPointDetector::DetectSwingLow(int bar_index)
{
    SSwingPoint new_swing_low;
    new_swing_low.time = iTime(m_symbol, m_timeframe, bar_index);
    new_swing_low.price = iLow(m_symbol, m_timeframe, bar_index);
    new_swing_low.bar_index = bar_index;
    new_swing_low.is_high = false;
    new_swing_low.is_valid = true;
    
    if(!ValidateSwingPoint(new_swing_low))
        return false;
    
    // Update swing low history
    m_previous_swing_low = m_last_swing_low;
    m_last_swing_low = new_swing_low;
    
    AddSwingLow(new_swing_low);
    
    return true;
}

//+------------------------------------------------------------------+
//| Add swing high to history                                     |
//+------------------------------------------------------------------+
void CSwingPointDetector::AddSwingHigh(SSwingPoint &swing_point)
{
    int size = ArraySize(m_swing_highs);
    ArrayResize(m_swing_highs, size + 1);
    m_swing_highs[size] = swing_point;
    
    // Limit history size
    if(size >= m_max_history)
    {
        ArrayCopy(m_swing_highs, m_swing_highs, 0, 1, size - 1);
        ArrayResize(m_swing_highs, size - 1);
    }
}

//+------------------------------------------------------------------+
//| Add swing low to history                                      |
//+------------------------------------------------------------------+
void CSwingPointDetector::AddSwingLow(SSwingPoint &swing_point)
{
    int size = ArraySize(m_swing_lows);
    ArrayResize(m_swing_lows, size + 1);
    m_swing_lows[size] = swing_point;
    
    // Limit history size
    if(size >= m_max_history)
    {
        ArrayCopy(m_swing_lows, m_swing_lows, 0, 1, size - 1);
        ArrayResize(m_swing_lows, size - 1);
    }
}

//+------------------------------------------------------------------+
//| Validate swing point                                          |
//+------------------------------------------------------------------+
bool CSwingPointDetector::ValidateSwingPoint(const SSwingPoint &swing_point)
{
    if(swing_point.price <= 0 || swing_point.time <= 0)
        return false;
    
    // Check minimum swing size
    if(m_min_swing_size > 0)
    {
        if(swing_point.is_high && m_last_swing_low.is_valid)
        {
            double swing_size = swing_point.price - m_last_swing_low.price;
            if(swing_size < m_min_swing_size)
                return false;
        }
        else if(!swing_point.is_high && m_last_swing_high.is_valid)
        {
            double swing_size = m_last_swing_high.price - swing_point.price;
            if(swing_size < m_min_swing_size)
                return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get bullish stop loss (below last swing low)                 |
//+------------------------------------------------------------------+
double CSwingPointDetector::GetBullishStopLoss(double entry_price, int pip_buffer)
{
    if(!m_last_swing_low.is_valid)
    {
        Print("DEBUG SWING: No valid swing low found");
        return 0.0;
    }

    Print("DEBUG SWING: Last swing low = ", m_last_swing_low.price, " Entry = ", entry_price);

    // SAFETY CHECK: Swing low must be BELOW entry for LONG position
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double pip_size = 0.1; // 1 pip for DAX = 0.1 price units
    double max_sl_distance = 50 * pip_size; // Maximum 50 pips SL distance
    double sl_distance = entry_price - m_last_swing_low.price;

    if(m_last_swing_low.price >= entry_price)
    {
        Print("WARNING: Swing low (", m_last_swing_low.price, ") is above entry (", entry_price, "). Using default SL.");
        return 0.0; // Return 0 to force default SL
    }

    if(sl_distance > max_sl_distance)
    {
        Print("WARNING: Swing low too far (", sl_distance/pip_size, " pips). Max allowed: 50 pips. Using default SL.");
        return 0.0; // Return 0 to force default SL
    }

    double sl = CalculateStopLossLevel(m_last_swing_low.price, true, pip_buffer);
    Print("DEBUG SWING: Calculated bullish SL = ", sl);
    return sl;
}

//+------------------------------------------------------------------+
//| Get bearish stop loss (above last swing high)                |
//+------------------------------------------------------------------+
double CSwingPointDetector::GetBearishStopLoss(double entry_price, int pip_buffer)
{
    if(!m_last_swing_high.is_valid)
    {
        Print("DEBUG SWING: No valid swing high found");
        return 0.0;
    }

    Print("DEBUG SWING: Last swing high = ", m_last_swing_high.price, " Entry = ", entry_price);

    // SAFETY CHECK: Swing high must be ABOVE entry for SHORT position
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double pip_size = 0.1; // 1 pip for DAX = 0.1 price units
    double max_sl_distance = 50 * pip_size; // Maximum 50 pips SL distance
    double sl_distance = m_last_swing_high.price - entry_price;

    if(m_last_swing_high.price <= entry_price)
    {
        Print("WARNING: Swing high (", m_last_swing_high.price, ") is below entry (", entry_price, "). Using default SL.");
        return 0.0; // Return 0 to force default SL
    }

    if(sl_distance > max_sl_distance)
    {
        Print("WARNING: Swing high too far (", sl_distance/pip_size, " pips). Max allowed: 50 pips. Using default SL.");
        return 0.0; // Return 0 to force default SL
    }

    double sl = CalculateStopLossLevel(m_last_swing_high.price, false, pip_buffer);
    Print("DEBUG SWING: Calculated bearish SL = ", sl);
    return sl;
}

//+------------------------------------------------------------------+
//| Get dynamic stop loss based on direction                      |
//+------------------------------------------------------------------+
double CSwingPointDetector::GetDynamicStopLoss(bool is_long, double entry_price, int pip_buffer)
{
    if(is_long)
        return GetBullishStopLoss(entry_price, pip_buffer);
    else
        return GetBearishStopLoss(entry_price, pip_buffer);
}

//+------------------------------------------------------------------+
//| Calculate stop loss level with pip buffer                     |
//+------------------------------------------------------------------+
double CSwingPointDetector::CalculateStopLossLevel(double reference_price, bool is_long, int pip_buffer)
{
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double buffer = pip_buffer * point;
    double min_stop_level = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

    double calculated_sl;
    if(is_long)
        calculated_sl = reference_price - buffer; // Stop below swing low
    else
        calculated_sl = reference_price + buffer; // Stop above swing high

    // Validate minimum distance
    double current_price = is_long ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double sl_distance = MathAbs(current_price - calculated_sl);
    double min_required = MathMax(min_stop_level + 30 * point, 100 * point); // Minimum 100 points or broker requirement + buffer

    if(sl_distance < min_required)
    {
        Print("WARNING: Swing SL too close (", sl_distance/point, " points). Adjusting to minimum (", min_required/point, " points)");
        if(is_long)
            calculated_sl = current_price - min_required;
        else
            calculated_sl = current_price + min_required;
    }

    return calculated_sl;
}

//+------------------------------------------------------------------+
//| Get swing points information                                  |
//+------------------------------------------------------------------+
string CSwingPointDetector::GetSwingPointsInfo()
{
    string info = "Swing Points: ";
    
    if(m_last_swing_high.is_valid)
        info += StringFormat("Last High: %.5f ", m_last_swing_high.price);
    else
        info += "Last High: N/A ";
    
    if(m_last_swing_low.is_valid)
        info += StringFormat("Last Low: %.5f ", m_last_swing_low.price);
    else
        info += "Last Low: N/A ";
    
    info += StringFormat("History: %d highs, %d lows", ArraySize(m_swing_highs), ArraySize(m_swing_lows));
    
    return info;
}

//+------------------------------------------------------------------+
//| Find nearest swing low below reference price                  |
//+------------------------------------------------------------------+
double CSwingPointDetector::FindNearestSwingLow(double reference_price)
{
    double best_swing_low = 0.0;
    double min_distance = DBL_MAX;

    // Check recent bars for swing lows below reference price
    for(int i = m_lookback_bars; i < 50; i++)
    {
        if(IsSwingLow(i))
        {
            double swing_price = iLow(m_symbol, m_timeframe, i);
            if(swing_price < reference_price)
            {
                double distance = reference_price - swing_price;
                if(distance < min_distance)
                {
                    min_distance = distance;
                    best_swing_low = swing_price;
                }
            }
        }
    }

    return best_swing_low;
}

//+------------------------------------------------------------------+
//| Find nearest swing high above reference price                 |
//+------------------------------------------------------------------+
double CSwingPointDetector::FindNearestSwingHigh(double reference_price)
{
    double best_swing_high = 0.0;
    double min_distance = DBL_MAX;

    // Check recent bars for swing highs above reference price
    for(int i = m_lookback_bars; i < 50; i++)
    {
        if(IsSwingHigh(i))
        {
            double swing_price = iHigh(m_symbol, m_timeframe, i);
            if(swing_price > reference_price)
            {
                double distance = swing_price - reference_price;
                if(distance < min_distance)
                {
                    min_distance = distance;
                    best_swing_high = swing_price;
                }
            }
        }
    }

    return best_swing_high;
}
