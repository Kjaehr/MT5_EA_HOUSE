//+------------------------------------------------------------------+
//|                                           AdmiralPivotPoints.mqh |
//|                                  Admiral Pivot Points Calculator |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Admiral Pivot Points calculation class                          |
//+------------------------------------------------------------------+
class CAdmiralPivotPoints
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_pivot_timeframe;
    
    // Pivot levels
    double            m_pivot_point;
    double            m_resistance1;
    double            m_resistance2;
    double            m_resistance3;
    double            m_support1;
    double            m_support2;
    double            m_support3;
    
    // Last calculation data
    datetime          m_last_calculation_time;
    double            m_last_high;
    double            m_last_low;
    double            m_last_close;
    
    bool              m_initialized;

public:
    //--- Constructor/Destructor
                      CAdmiralPivotPoints(string symbol, ENUM_TIMEFRAMES pivot_tf = PERIOD_H1);
                     ~CAdmiralPivotPoints();
    
    //--- Initialization
    bool              Initialize();
    
    //--- Main calculation methods
    bool              CalculatePivotLevels();
    bool              UpdatePivotLevels();
    
    //--- Getter methods
    double            GetPivotPoint() const { return m_pivot_point; }
    double            GetResistance1() const { return m_resistance1; }
    double            GetResistance2() const { return m_resistance2; }
    double            GetResistance3() const { return m_resistance3; }
    double            GetSupport1() const { return m_support1; }
    double            GetSupport2() const { return m_support2; }
    double            GetSupport3() const { return m_support3; }
    
    //--- Utility methods
    double            GetNextResistanceLevel(double current_price);
    double            GetNextSupportLevel(double current_price);
    double            GetNearestPivotLevel(double current_price);
    bool              IsPriceNearPivot(double price, double tolerance_points = 5.0);
    
    //--- Information methods
    string            GetPivotLevelsString();
    bool              IsInitialized() const { return m_initialized; }
    datetime          GetLastCalculationTime() const { return m_last_calculation_time; }

private:
    //--- Internal calculation methods
    bool              GetPivotData(double &high, double &low, double &close);
    void              CalculateTraditionalPivots(double high, double low, double close);
    bool              ShouldRecalculate();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAdmiralPivotPoints::CAdmiralPivotPoints(string symbol, ENUM_TIMEFRAMES pivot_tf)
{
    m_symbol = symbol;
    m_pivot_timeframe = pivot_tf;
    
    // Initialize pivot levels
    m_pivot_point = 0.0;
    m_resistance1 = 0.0;
    m_resistance2 = 0.0;
    m_resistance3 = 0.0;
    m_support1 = 0.0;
    m_support2 = 0.0;
    m_support3 = 0.0;
    
    // Initialize calculation data
    m_last_calculation_time = 0;
    m_last_high = 0.0;
    m_last_low = 0.0;
    m_last_close = 0.0;
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAdmiralPivotPoints::~CAdmiralPivotPoints()
{
    // Cleanup if needed
}

//+------------------------------------------------------------------+
//| Initialize pivot points calculator                               |
//+------------------------------------------------------------------+
bool CAdmiralPivotPoints::Initialize()
{
    if(StringLen(m_symbol) == 0)
    {
        Print("AdmiralPivotPoints: Invalid symbol");
        return false;
    }
    
    // Calculate initial pivot levels
    if(!CalculatePivotLevels())
    {
        Print("AdmiralPivotPoints: Failed to calculate initial pivot levels");
        return false;
    }
    
    m_initialized = true;
    Print("AdmiralPivotPoints: Initialized successfully for ", m_symbol, " on ", EnumToString(m_pivot_timeframe));
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate pivot levels using traditional formulas               |
//+------------------------------------------------------------------+
bool CAdmiralPivotPoints::CalculatePivotLevels()
{
    double high, low, close;
    
    if(!GetPivotData(high, low, close))
    {
        Print("AdmiralPivotPoints: Failed to get pivot data");
        return false;
    }
    
    // Store calculation data
    m_last_high = high;
    m_last_low = low;
    m_last_close = close;
    m_last_calculation_time = TimeCurrent();
    
    // Calculate traditional pivot points
    CalculateTraditionalPivots(high, low, close);
    
    Print("AdmiralPivotPoints: Calculated - P:", m_pivot_point, 
          " R1:", m_resistance1, " R2:", m_resistance2, " R3:", m_resistance3,
          " S1:", m_support1, " S2:", m_support2, " S3:", m_support3);
    
    return true;
}

//+------------------------------------------------------------------+
//| Update pivot levels if needed                                   |
//+------------------------------------------------------------------+
bool CAdmiralPivotPoints::UpdatePivotLevels()
{
    if(!m_initialized)
        return false;
        
    if(ShouldRecalculate())
    {
        return CalculatePivotLevels();
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get pivot data for calculation                                  |
//+------------------------------------------------------------------+
bool CAdmiralPivotPoints::GetPivotData(double &high, double &low, double &close)
{
    // Get the previous completed period data
    int shift = 1; // Previous completed bar
    
    high = iHigh(m_symbol, m_pivot_timeframe, shift);
    low = iLow(m_symbol, m_pivot_timeframe, shift);
    close = iClose(m_symbol, m_pivot_timeframe, shift);
    
    if(high <= 0 || low <= 0 || close <= 0)
    {
        Print("AdmiralPivotPoints: Invalid price data - H:", high, " L:", low, " C:", close);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate traditional pivot points using Admiral formulas      |
//+------------------------------------------------------------------+
void CAdmiralPivotPoints::CalculateTraditionalPivots(double high, double low, double close)
{
    // Traditional Admiral Pivot Points formulas
    m_pivot_point = (high + low + close) / 3.0;
    
    // Resistance levels
    m_resistance1 = (2.0 * m_pivot_point) - low;
    m_resistance2 = m_pivot_point + (high - low);
    m_resistance3 = high + 2.0 * (m_pivot_point - low);
    
    // Support levels
    m_support1 = (2.0 * m_pivot_point) - high;
    m_support2 = m_pivot_point - (high - low);
    m_support3 = low - 2.0 * (high - m_pivot_point);
}

//+------------------------------------------------------------------+
//| Check if recalculation is needed                               |
//+------------------------------------------------------------------+
bool CAdmiralPivotPoints::ShouldRecalculate()
{
    datetime current_bar_time = iTime(m_symbol, m_pivot_timeframe, 0);
    datetime last_bar_time = iTime(m_symbol, m_pivot_timeframe, 1);
    
    // Recalculate when a new period starts
    return (m_last_calculation_time < last_bar_time);
}

//+------------------------------------------------------------------+
//| Get next resistance level above current price                   |
//+------------------------------------------------------------------+
double CAdmiralPivotPoints::GetNextResistanceLevel(double current_price)
{
    if(current_price < m_resistance1)
        return m_resistance1;
    else if(current_price < m_resistance2)
        return m_resistance2;
    else if(current_price < m_resistance3)
        return m_resistance3;
    else
        return m_resistance3; // Above all resistance levels
}

//+------------------------------------------------------------------+
//| Get next support level below current price                      |
//+------------------------------------------------------------------+
double CAdmiralPivotPoints::GetNextSupportLevel(double current_price)
{
    if(current_price > m_support1)
        return m_support1;
    else if(current_price > m_support2)
        return m_support2;
    else if(current_price > m_support3)
        return m_support3;
    else
        return m_support3; // Below all support levels
}

//+------------------------------------------------------------------+
//| Get nearest pivot level to current price                        |
//+------------------------------------------------------------------+
double CAdmiralPivotPoints::GetNearestPivotLevel(double current_price)
{
    double levels[] = {m_support3, m_support2, m_support1, m_pivot_point, 
                       m_resistance1, m_resistance2, m_resistance3};
    
    double nearest_level = m_pivot_point;
    double min_distance = MathAbs(current_price - m_pivot_point);
    
    for(int i = 0; i < ArraySize(levels); i++)
    {
        double distance = MathAbs(current_price - levels[i]);
        if(distance < min_distance)
        {
            min_distance = distance;
            nearest_level = levels[i];
        }
    }
    
    return nearest_level;
}

//+------------------------------------------------------------------+
//| Check if price is near a pivot level                           |
//+------------------------------------------------------------------+
bool CAdmiralPivotPoints::IsPriceNearPivot(double price, double tolerance_points = 5.0)
{
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double tolerance = tolerance_points * point;
    
    double levels[] = {m_support3, m_support2, m_support1, m_pivot_point, 
                       m_resistance1, m_resistance2, m_resistance3};
    
    for(int i = 0; i < ArraySize(levels); i++)
    {
        if(MathAbs(price - levels[i]) <= tolerance)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get pivot levels as formatted string                           |
//+------------------------------------------------------------------+
string CAdmiralPivotPoints::GetPivotLevelsString()
{
    return StringFormat("Pivot Levels - P:%.5f R1:%.5f R2:%.5f R3:%.5f S1:%.5f S2:%.5f S3:%.5f",
                       m_pivot_point, m_resistance1, m_resistance2, m_resistance3,
                       m_support1, m_support2, m_support3);
}
