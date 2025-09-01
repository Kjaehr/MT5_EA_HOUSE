//+------------------------------------------------------------------+
//|                                          VolumeProfileHelper.mqh |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| Volume Profile Helper Class                                     |
//| Integrates DAX Volume Profile indicator with EA                 |
//+------------------------------------------------------------------+
class CVolumeProfileHelper
{
private:
    int               m_indicator_handle;
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    bool              m_initialized;
    
    //--- Buffer indices
    enum ENUM_VP_BUFFERS
    {
        VP_POC = 0,
        VP_VALUE_AREA_HIGH = 1,
        VP_VALUE_AREA_LOW = 2,
        VP_VOLUME_NODES_HIGH = 3,
        VP_VOLUME_NODES_LOW = 4
    };
    
    //--- Data arrays
    double            m_poc_data[];
    double            m_vah_data[];
    double            m_val_data[];
    double            m_nodes_high_data[];
    double            m_nodes_low_data[];

public:
    //--- Constructor/Destructor
                      CVolumeProfileHelper(string symbol, ENUM_TIMEFRAMES timeframe);
                     ~CVolumeProfileHelper();
    
    //--- Initialization
    bool              Initialize(int profile_period = 20, int price_levels = 50, double value_area_percent = 70.0);
    void              Deinitialize();
    
    //--- Data retrieval methods
    double            GetCurrentPOC();
    double            GetCurrentValueAreaHigh();
    double            GetCurrentValueAreaLow();
    bool              IsPriceInValueArea(double price);
    bool              IsPriceNearPOC(double price, double tolerance_points = 5.0);
    
    //--- Volume node methods
    bool              IsPriceNearVolumeNode(double price, double tolerance_points = 3.0);
    double            GetNearestVolumeNode(double price, bool above = true);
    
    //--- Support/Resistance methods
    double            GetVolumeBasedSupport(double current_price);
    double            GetVolumeBasedResistance(double current_price);
    
    //--- Trading signal methods
    bool              IsPOCBreakout(double current_price, double previous_price);
    bool              IsValueAreaBreakout(double current_price, bool &is_upward);
    double            GetOptimalEntryLevel(double signal_price, bool is_long);
    double            GetVolumeBasedTarget(double entry_price, bool is_long);
    
    //--- Update methods
    bool              UpdateData();
    bool              IsDataReady();
    
    //--- Utility methods
    void              PrintVolumeProfile();
    string            GetStatusString();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVolumeProfileHelper::CVolumeProfileHelper(string symbol, ENUM_TIMEFRAMES timeframe)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_indicator_handle = INVALID_HANDLE;
    m_initialized = false;
    
    //--- Set array properties
    ArraySetAsSeries(m_poc_data, true);
    ArraySetAsSeries(m_vah_data, true);
    ArraySetAsSeries(m_val_data, true);
    ArraySetAsSeries(m_nodes_high_data, true);
    ArraySetAsSeries(m_nodes_low_data, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CVolumeProfileHelper::~CVolumeProfileHelper()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize Volume Profile Helper                                |
//+------------------------------------------------------------------+
bool CVolumeProfileHelper::Initialize(int profile_period = 20, int price_levels = 50, double value_area_percent = 70.0)
{
    //--- Create indicator handle
    m_indicator_handle = iCustom(m_symbol, m_timeframe, "DAXVolumeProfile",
                                profile_period, price_levels, value_area_percent);
    
    if(m_indicator_handle == INVALID_HANDLE)
    {
        Print("Failed to create Volume Profile indicator handle");
        return false;
    }
    
    //--- Wait for indicator to calculate
    int attempts = 0;
    while(BarsCalculated(m_indicator_handle) < 10 && attempts < 100)
    {
        Sleep(50);
        attempts++;
    }
    
    if(BarsCalculated(m_indicator_handle) < 10)
    {
        Print("Volume Profile indicator failed to calculate");
        return false;
    }
    
    m_initialized = true;
    Print("Volume Profile Helper initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize                                                     |
//+------------------------------------------------------------------+
void CVolumeProfileHelper::Deinitialize()
{
    if(m_indicator_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_indicator_handle);
        m_indicator_handle = INVALID_HANDLE;
    }
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Update indicator data                                            |
//+------------------------------------------------------------------+
bool CVolumeProfileHelper::UpdateData()
{
    if(!m_initialized || m_indicator_handle == INVALID_HANDLE)
        return false;
    
    //--- Copy data from indicator buffers
    if(CopyBuffer(m_indicator_handle, VP_POC, 0, 10, m_poc_data) <= 0)
        return false;
        
    if(CopyBuffer(m_indicator_handle, VP_VALUE_AREA_HIGH, 0, 10, m_vah_data) <= 0)
        return false;
        
    if(CopyBuffer(m_indicator_handle, VP_VALUE_AREA_LOW, 0, 10, m_val_data) <= 0)
        return false;
        
    if(CopyBuffer(m_indicator_handle, VP_VOLUME_NODES_HIGH, 0, 10, m_nodes_high_data) <= 0)
        return false;
        
    if(CopyBuffer(m_indicator_handle, VP_VOLUME_NODES_LOW, 0, 10, m_nodes_low_data) <= 0)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Get current POC price                                           |
//+------------------------------------------------------------------+
double CVolumeProfileHelper::GetCurrentPOC()
{
    if(!UpdateData()) return 0.0;
    
    for(int i = 0; i < ArraySize(m_poc_data); i++)
    {
        if(m_poc_data[i] != EMPTY_VALUE && m_poc_data[i] > 0)
            return m_poc_data[i];
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| Get current Value Area High                                     |
//+------------------------------------------------------------------+
double CVolumeProfileHelper::GetCurrentValueAreaHigh()
{
    if(!UpdateData()) return 0.0;
    
    for(int i = 0; i < ArraySize(m_vah_data); i++)
    {
        if(m_vah_data[i] != EMPTY_VALUE && m_vah_data[i] > 0)
            return m_vah_data[i];
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| Get current Value Area Low                                      |
//+------------------------------------------------------------------+
double CVolumeProfileHelper::GetCurrentValueAreaLow()
{
    if(!UpdateData()) return 0.0;
    
    for(int i = 0; i < ArraySize(m_val_data); i++)
    {
        if(m_val_data[i] != EMPTY_VALUE && m_val_data[i] > 0)
            return m_val_data[i];
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| Check if price is in Value Area                                 |
//+------------------------------------------------------------------+
bool CVolumeProfileHelper::IsPriceInValueArea(double price)
{
    double vah = GetCurrentValueAreaHigh();
    double val = GetCurrentValueAreaLow();
    
    if(vah <= 0 || val <= 0) return false;
    
    return (price >= val && price <= vah);
}

//+------------------------------------------------------------------+
//| Check if price is near POC                                      |
//+------------------------------------------------------------------+
bool CVolumeProfileHelper::IsPriceNearPOC(double price, double tolerance_points = 5.0)
{
    double poc = GetCurrentPOC();
    if(poc <= 0) return false;
    
    double tolerance = tolerance_points * _Point;
    return (MathAbs(price - poc) <= tolerance);
}

//+------------------------------------------------------------------+
//| Get volume-based support level                                  |
//+------------------------------------------------------------------+
double CVolumeProfileHelper::GetVolumeBasedSupport(double current_price)
{
    double poc = GetCurrentPOC();
    double val = GetCurrentValueAreaLow();
    
    if(current_price > poc && poc > 0)
        return poc;  // POC acts as support
    else if(val > 0)
        return val;  // Value Area Low as support
    
    return 0.0;
}

//+------------------------------------------------------------------+
//| Get volume-based resistance level                               |
//+------------------------------------------------------------------+
double CVolumeProfileHelper::GetVolumeBasedResistance(double current_price)
{
    double poc = GetCurrentPOC();
    double vah = GetCurrentValueAreaHigh();
    
    if(current_price < poc && poc > 0)
        return poc;  // POC acts as resistance
    else if(vah > 0)
        return vah;  // Value Area High as resistance
    
    return 0.0;
}

//+------------------------------------------------------------------+
//| Check for POC breakout                                          |
//+------------------------------------------------------------------+
bool CVolumeProfileHelper::IsPOCBreakout(double current_price, double previous_price)
{
    double poc = GetCurrentPOC();
    if(poc <= 0) return false;
    
    // Check if price crossed POC
    return ((previous_price <= poc && current_price > poc) || 
            (previous_price >= poc && current_price < poc));
}

//+------------------------------------------------------------------+
//| Check for Value Area breakout                                   |
//+------------------------------------------------------------------+
bool CVolumeProfileHelper::IsValueAreaBreakout(double current_price, bool &is_upward)
{
    double vah = GetCurrentValueAreaHigh();
    double val = GetCurrentValueAreaLow();
    
    if(vah <= 0 || val <= 0) return false;
    
    if(current_price > vah)
    {
        is_upward = true;
        return true;
    }
    else if(current_price < val)
    {
        is_upward = false;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get optimal entry level based on volume profile                 |
//+------------------------------------------------------------------+
double CVolumeProfileHelper::GetOptimalEntryLevel(double signal_price, bool is_long)
{
    double poc = GetCurrentPOC();
    
    if(poc <= 0) return signal_price;
    
    if(is_long)
    {
        // For long entries, prefer entry near POC or support
        double support = GetVolumeBasedSupport(signal_price);
        return (support > 0) ? support : signal_price;
    }
    else
    {
        // For short entries, prefer entry near POC or resistance
        double resistance = GetVolumeBasedResistance(signal_price);
        return (resistance > 0) ? resistance : signal_price;
    }
}

//+------------------------------------------------------------------+
//| Get volume-based target                                         |
//+------------------------------------------------------------------+
double CVolumeProfileHelper::GetVolumeBasedTarget(double entry_price, bool is_long)
{
    if(is_long)
    {
        double resistance = GetVolumeBasedResistance(entry_price);
        return (resistance > entry_price) ? resistance : 0.0;
    }
    else
    {
        double support = GetVolumeBasedSupport(entry_price);
        return (support < entry_price && support > 0) ? support : 0.0;
    }
}

//+------------------------------------------------------------------+
//| Check if data is ready                                          |
//+------------------------------------------------------------------+
bool CVolumeProfileHelper::IsDataReady()
{
    return (m_initialized && m_indicator_handle != INVALID_HANDLE && 
            BarsCalculated(m_indicator_handle) > 10);
}

//+------------------------------------------------------------------+
//| Print volume profile information                                |
//+------------------------------------------------------------------+
void CVolumeProfileHelper::PrintVolumeProfile()
{
    if(!IsDataReady()) return;
    
    double poc = GetCurrentPOC();
    double vah = GetCurrentValueAreaHigh();
    double val = GetCurrentValueAreaLow();
    
    Print("=== Volume Profile ===");
    Print("POC: ", DoubleToString(poc, _Digits));
    Print("Value Area High: ", DoubleToString(vah, _Digits));
    Print("Value Area Low: ", DoubleToString(val, _Digits));
    Print("Value Area Range: ", DoubleToString(vah - val, _Digits), " points");
}

//+------------------------------------------------------------------+
//| Get status string                                               |
//+------------------------------------------------------------------+
string CVolumeProfileHelper::GetStatusString()
{
    if(!IsDataReady()) return "Volume Profile: Not Ready";
    
    double poc = GetCurrentPOC();
    double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    
    string status = "VP: POC=" + DoubleToString(poc, _Digits);
    
    if(IsPriceInValueArea(current_price))
        status += " [IN VA]";
    else
        status += " [OUT VA]";
        
    if(IsPriceNearPOC(current_price))
        status += " [NEAR POC]";
    
    return status;
}
