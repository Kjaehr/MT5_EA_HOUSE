//+------------------------------------------------------------------+
//|                                              PivotZoneManager.mqh |
//|                           Advanced Pivot Zone Detection & Trading |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

#include "AdmiralPivotPoints.mqh"
#include "TradingRegimeManager.mqh"

//+------------------------------------------------------------------+
//| Pivot Zone Structure                                             |
//+------------------------------------------------------------------+
struct SPivotZone
{
    double center_price;       // Pivot level center
    double upper_bound;        // Zone upper boundary
    double lower_bound;        // Zone lower boundary
    string level_name;         // R1, R2, S1, etc.
    bool is_resistance;        // True for resistance, false for support
    bool has_been_tested;      // Track if zone has been tested today
    datetime last_test_time;   // When was it last tested
    int test_count;           // Number of tests today
    
    // Constructor
    SPivotZone()
    {
        center_price = 0.0;
        upper_bound = 0.0;
        lower_bound = 0.0;
        level_name = "";
        is_resistance = false;
        has_been_tested = false;
        last_test_time = 0;
        test_count = 0;
    }

    // Copy constructor to fix deprecation warning
    SPivotZone(const SPivotZone &other)
    {
        center_price = other.center_price;
        upper_bound = other.upper_bound;
        lower_bound = other.lower_bound;
        level_name = other.level_name;
        is_resistance = other.is_resistance;
        has_been_tested = other.has_been_tested;
        last_test_time = other.last_test_time;
        test_count = other.test_count;
    }
};

//+------------------------------------------------------------------+
//| Zone Interaction Types                                           |
//+------------------------------------------------------------------+
enum ENUM_ZONE_INTERACTION
{
    ZONE_NO_INTERACTION = 0,   // Price not near any zone
    ZONE_APPROACHING = 1,      // Price approaching zone
    ZONE_INSIDE = 2,           // Price inside zone
    ZONE_BREAKOUT = 3,         // Price broke through zone
    ZONE_RETEST = 4,           // Price retesting zone after breakout
    ZONE_REJECTION = 5         // Price rejected from zone
};

//+------------------------------------------------------------------+
//| Pivot Zone Manager Class                                         |
//+------------------------------------------------------------------+
class CPivotZoneManager
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    
    // Components
    CAdmiralPivotPoints* m_pivot_points;
    CTradingRegimeManager* m_regime_manager;
    
    // Zone data
    SPivotZone        m_zones[7]; // R3, R2, R1, P, S1, S2, S3
    double            m_zone_width_multiplier;
    
    // Current market state
    double            m_current_price;
    ENUM_ZONE_INTERACTION m_current_interaction;
    int               m_nearest_zone_index;
    
    // Tracking
    datetime          m_last_update;
    datetime          m_last_reset_date;
    
    bool              m_initialized;

public:
    //--- Constructor/Destructor
                      CPivotZoneManager(string symbol, ENUM_TIMEFRAMES timeframe,
                                       CAdmiralPivotPoints* pivot_points, CTradingRegimeManager* regime_manager);
                     ~CPivotZoneManager();
    
    //--- Initialization
    bool              Initialize();
    void              Deinitialize();
    
    //--- Main update methods
    bool              UpdateZones();
    bool              UpdateMarketInteraction();
    
    //--- Zone analysis methods
    ENUM_ZONE_INTERACTION GetCurrentInteraction() const { return m_current_interaction; }
    SPivotZone        GetNearestZone();
    SPivotZone        GetZoneByIndex(int index);
    
    //--- Trading signal methods
    bool              IsBreakoutRetestSetup(bool is_long);
    bool              IsZoneRejectionSetup(bool is_long);
    bool              CanTradeZone(int zone_index);
    
    //--- Entry validation
    bool              ValidateBreakoutEntry(bool is_long, double entry_price);
    bool              ValidateRejectionEntry(bool is_long, double entry_price);
    bool              IsInMiddleOfNowhere(double price);
    
    //--- Zone management
    void              RegisterZoneTest(int zone_index);
    void              ResetDailyZoneData();
    
    //--- Information methods
    string            GetZoneAnalysis();
    string            GetNearestZoneInfo();
    bool              IsInitialized() const { return m_initialized; }

private:
    //--- Internal methods
    void              CalculateZoneBoundaries();
    int               FindNearestZoneIndex(double price);
    ENUM_ZONE_INTERACTION DetermineZoneInteraction(double price, int zone_index);
    bool              IsRetestValid(int zone_index, bool is_long);
    void              CheckDailyReset();
    double            GetZoneWidth();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPivotZoneManager::CPivotZoneManager(string symbol, ENUM_TIMEFRAMES timeframe,
                                     CAdmiralPivotPoints* pivot_points, CTradingRegimeManager* regime_manager)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_pivot_points = pivot_points;
    m_regime_manager = regime_manager;
    
    m_zone_width_multiplier = 0.7; // ±0.7 × ATR
    
    m_current_price = 0.0;
    m_current_interaction = ZONE_NO_INTERACTION;
    m_nearest_zone_index = -1;
    
    m_last_update = 0;
    m_last_reset_date = 0;
    
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPivotZoneManager::~CPivotZoneManager()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize pivot zone manager                                   |
//+------------------------------------------------------------------+
bool CPivotZoneManager::Initialize()
{
    if(StringLen(m_symbol) == 0 || m_pivot_points == NULL || m_regime_manager == NULL)
    {
        Print("PivotZoneManager: Invalid parameters");
        return false;
    }
    
    if(!m_pivot_points.IsInitialized())
    {
        Print("PivotZoneManager: Pivot points not initialized");
        return false;
    }
    
    // Initialize zone names
    m_zones[0].level_name = "R3";
    m_zones[0].is_resistance = true;
    m_zones[1].level_name = "R2";
    m_zones[1].is_resistance = true;
    m_zones[2].level_name = "R1";
    m_zones[2].is_resistance = true;
    m_zones[3].level_name = "P";
    m_zones[3].is_resistance = false; // Pivot can act as both
    m_zones[4].level_name = "S1";
    m_zones[4].is_resistance = false;
    m_zones[5].level_name = "S2";
    m_zones[5].is_resistance = false;
    m_zones[6].level_name = "S3";
    m_zones[6].is_resistance = false;
    
    // Wait for pivot points to be ready
    Sleep(100);

    // Initial update - try a few times if it fails
    int attempts = 0;
    while(attempts < 3 && !UpdateZones())
    {
        attempts++;
        Print("PivotZoneManager: Initial zones update attempt ", attempts, " failed, retrying...");
        Sleep(100);
    }

    if(attempts >= 3)
    {
        Print("PivotZoneManager: Failed to update initial zones after 3 attempts - using defaults");
        // Initialize with default zone values
        for(int i = 0; i < 7; i++)
        {
            m_zones[i].center_price = 0.0;
            m_zones[i].upper_bound = 0.0;
            m_zones[i].lower_bound = 0.0;
        }
    }
    
    ResetDailyZoneData();
    
    m_initialized = true;
    Print("PivotZoneManager: Initialized successfully");
    
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize pivot zone manager                                 |
//+------------------------------------------------------------------+
void CPivotZoneManager::Deinitialize()
{
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Update pivot zones                                               |
//+------------------------------------------------------------------+
bool CPivotZoneManager::UpdateZones()
{
    // Allow update during initialization (m_initialized may be false)

    // Check for daily reset (only if initialized)
    if(m_initialized)
        CheckDailyReset();
    
    // Update pivot points first
    if(!m_pivot_points.UpdatePivotLevels())
        return false;
    
    // Get current pivot levels
    m_zones[0].center_price = m_pivot_points.GetResistance3();
    m_zones[1].center_price = m_pivot_points.GetResistance2();
    m_zones[2].center_price = m_pivot_points.GetResistance1();
    m_zones[3].center_price = m_pivot_points.GetPivotPoint();
    m_zones[4].center_price = m_pivot_points.GetSupport1();
    m_zones[5].center_price = m_pivot_points.GetSupport2();
    m_zones[6].center_price = m_pivot_points.GetSupport3();
    
    // Calculate zone boundaries
    CalculateZoneBoundaries();
    
    // Update market interaction
    UpdateMarketInteraction();
    
    m_last_update = TimeCurrent();
    return true;
}

//+------------------------------------------------------------------+
//| Update market interaction with zones                            |
//+------------------------------------------------------------------+
bool CPivotZoneManager::UpdateMarketInteraction()
{
    m_current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    if(m_current_price <= 0)
    {
        Print("PivotZoneManager: Failed to get current price, error: ", GetLastError());
        return false;
    }
    
    // Find nearest zone
    m_nearest_zone_index = FindNearestZoneIndex(m_current_price);
    
    if(m_nearest_zone_index >= 0)
    {
        m_current_interaction = DetermineZoneInteraction(m_current_price, m_nearest_zone_index);
    }
    else
    {
        m_current_interaction = ZONE_NO_INTERACTION;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate zone boundaries                                        |
//+------------------------------------------------------------------+
void CPivotZoneManager::CalculateZoneBoundaries()
{
    double zone_width = GetZoneWidth();
    
    for(int i = 0; i < 7; i++)
    {
        if(m_zones[i].center_price > 0)
        {
            m_zones[i].upper_bound = m_zones[i].center_price + zone_width;
            m_zones[i].lower_bound = m_zones[i].center_price - zone_width;
        }
    }
}

//+------------------------------------------------------------------+
//| Get zone width based on ATR                                     |
//+------------------------------------------------------------------+
double CPivotZoneManager::GetZoneWidth()
{
    if(m_regime_manager == NULL)
        return 1.0; // Default 1 point
    
    double atr = m_regime_manager.GetCurrentATR();
    if(atr <= 0)
        return 1.0;
    
    return atr * m_zone_width_multiplier;
}

//+------------------------------------------------------------------+
//| Find nearest zone index                                         |
//+------------------------------------------------------------------+
int CPivotZoneManager::FindNearestZoneIndex(double price)
{
    double min_distance = DBL_MAX;
    int nearest_index = -1;
    
    for(int i = 0; i < 7; i++)
    {
        if(m_zones[i].center_price <= 0)
            continue;
        
        double distance = MathAbs(price - m_zones[i].center_price);
        if(distance < min_distance)
        {
            min_distance = distance;
            nearest_index = i;
        }
    }
    
    return nearest_index;
}

//+------------------------------------------------------------------+
//| Determine zone interaction type                                 |
//+------------------------------------------------------------------+
ENUM_ZONE_INTERACTION CPivotZoneManager::DetermineZoneInteraction(double price, int zone_index)
{
    if(zone_index < 0 || zone_index >= 7)
        return ZONE_NO_INTERACTION;
    
    SPivotZone zone = m_zones[zone_index];
    
    // Check if price is inside zone
    if(price >= zone.lower_bound && price <= zone.upper_bound)
        return ZONE_INSIDE;
    
    // Check if price is approaching zone (within 2x zone width)
    double approach_distance = GetZoneWidth() * 2.0;
    if(MathAbs(price - zone.center_price) <= approach_distance)
        return ZONE_APPROACHING;
    
    return ZONE_NO_INTERACTION;
}

//+------------------------------------------------------------------+
//| Check for breakout retest setup                                |
//+------------------------------------------------------------------+
bool CPivotZoneManager::IsBreakoutRetestSetup(bool is_long)
{
    if(m_nearest_zone_index < 0)
        return false;
    
    SPivotZone zone = m_zones[m_nearest_zone_index];
    
    // For long: look for retest of resistance that was broken
    // For short: look for retest of support that was broken
    
    if(is_long && !zone.is_resistance)
        return false;
    
    if(!is_long && zone.is_resistance)
        return false;
    
    // Check if zone was recently broken and now being retested
    return IsRetestValid(m_nearest_zone_index, is_long);
}

//+------------------------------------------------------------------+
//| Check for zone rejection setup                                  |
//+------------------------------------------------------------------+
bool CPivotZoneManager::IsZoneRejectionSetup(bool is_long)
{
    if(m_current_interaction != ZONE_INSIDE && m_current_interaction != ZONE_APPROACHING)
        return false;
    
    if(m_nearest_zone_index < 0)
        return false;
    
    SPivotZone zone = m_zones[m_nearest_zone_index];
    
    // For long: reject from support
    // For short: reject from resistance
    
    if(is_long && zone.is_resistance)
        return false;
    
    if(!is_long && !zone.is_resistance)
        return false;
    
    return CanTradeZone(m_nearest_zone_index);
}

//+------------------------------------------------------------------+
//| Check if zone can be traded                                     |
//+------------------------------------------------------------------+
bool CPivotZoneManager::CanTradeZone(int zone_index)
{
    if(zone_index < 0 || zone_index >= 7)
        return false;
    
    // Limit one trade per zone per day
    return m_zones[zone_index].test_count == 0;
}

//+------------------------------------------------------------------+
//| Validate if retest is valid                                     |
//+------------------------------------------------------------------+
bool CPivotZoneManager::IsRetestValid(int zone_index, bool is_long)
{
    // Simplified retest validation
    // In a full implementation, this would track breakout history
    
    if(!CanTradeZone(zone_index))
        return false;
    
    // Check if we're in the right interaction state
    return (m_current_interaction == ZONE_APPROACHING || m_current_interaction == ZONE_INSIDE);
}

//+------------------------------------------------------------------+
//| Check if price is in middle of nowhere                          |
//+------------------------------------------------------------------+
bool CPivotZoneManager::IsInMiddleOfNowhere(double price)
{
    if(m_nearest_zone_index < 0)
        return true;
    
    double distance_to_nearest = MathAbs(price - m_zones[m_nearest_zone_index].center_price);
    double max_allowed_distance = GetZoneWidth() * 0.7; // Must be within 0.7x ATR of nearest pivot
    
    return distance_to_nearest > max_allowed_distance;
}

//+------------------------------------------------------------------+
//| Register zone test                                              |
//+------------------------------------------------------------------+
void CPivotZoneManager::RegisterZoneTest(int zone_index)
{
    if(zone_index >= 0 && zone_index < 7)
    {
        m_zones[zone_index].has_been_tested = true;
        m_zones[zone_index].last_test_time = TimeCurrent();
        m_zones[zone_index].test_count++;
        
        Print("PivotZoneManager: Registered test of zone ", m_zones[zone_index].level_name);
    }
}

//+------------------------------------------------------------------+
//| Reset daily zone data                                           |
//+------------------------------------------------------------------+
void CPivotZoneManager::ResetDailyZoneData()
{
    for(int i = 0; i < 7; i++)
    {
        m_zones[i].has_been_tested = false;
        m_zones[i].last_test_time = 0;
        m_zones[i].test_count = 0;
    }
    
    m_last_reset_date = TimeCurrent();
    Print("PivotZoneManager: Daily zone data reset");
}

//+------------------------------------------------------------------+
//| Check for daily reset                                           |
//+------------------------------------------------------------------+
void CPivotZoneManager::CheckDailyReset()
{
    datetime current_time = TimeCurrent();
    MqlDateTime dt_current, dt_last;
    
    TimeToStruct(current_time, dt_current);
    TimeToStruct(m_last_reset_date, dt_last);
    
    if(dt_current.day != dt_last.day || dt_current.mon != dt_last.mon || dt_current.year != dt_last.year)
    {
        ResetDailyZoneData();
    }
}

//+------------------------------------------------------------------+
//| Get nearest zone                                                |
//+------------------------------------------------------------------+
SPivotZone CPivotZoneManager::GetNearestZone()
{
    if(m_nearest_zone_index >= 0 && m_nearest_zone_index < 7)
        return m_zones[m_nearest_zone_index];
    
    SPivotZone empty_zone;
    return empty_zone;
}

//+------------------------------------------------------------------+
//| Get zone by index                                               |
//+------------------------------------------------------------------+
SPivotZone CPivotZoneManager::GetZoneByIndex(int index)
{
    if(index >= 0 && index < 7)
        return m_zones[index];
    
    SPivotZone empty_zone;
    return empty_zone;
}

//+------------------------------------------------------------------+
//| Get zone analysis                                               |
//+------------------------------------------------------------------+
string CPivotZoneManager::GetZoneAnalysis()
{
    string analysis = "=== PIVOT ZONE ANALYSIS ===\n";
    analysis += StringFormat("Current Price: %.1f\n", m_current_price);
    analysis += "Zone Interaction: " + EnumToString(m_current_interaction) + "\n";
    analysis += StringFormat("Zone Width: %.1f points\n", GetZoneWidth());

    if(m_nearest_zone_index >= 0)
    {
        SPivotZone zone = m_zones[m_nearest_zone_index];
        analysis += "Nearest Zone: " + zone.level_name + StringFormat(" (%.1f) [%.1f - %.1f]\n",
                                zone.center_price, zone.lower_bound, zone.upper_bound);
        analysis += StringFormat("Zone Tests Today: %d\n", zone.test_count);
    }

    return analysis;
}

//+------------------------------------------------------------------+
//| Get nearest zone info                                           |
//+------------------------------------------------------------------+
string CPivotZoneManager::GetNearestZoneInfo()
{
    if(m_nearest_zone_index < 0)
        return "No nearby zones";
    
    SPivotZone zone = m_zones[m_nearest_zone_index];
    return StringFormat("%s: %.1f [%.1f-%.1f] Tests:%d", 
                       zone.level_name, zone.center_price, zone.lower_bound, zone.upper_bound, zone.test_count);
}
