//+------------------------------------------------------------------+
//|                                    Test_Seasonal_Adjustments.mq5 |
//|                                    Test Seasonal Multipliers     |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

#include "Include/AdmiralStrategy.mqh"

// Global variables
CAdmiralStrategy* g_strategy = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Testing Seasonal Adjustments ===");
    
    // Initialize strategy
    g_strategy = new CAdmiralStrategy(_Symbol, PERIOD_M15);
    
    // Configure strategy
    g_strategy.SetUseRegimeBasedTrading(true);
    g_strategy.SetUseH4BiasFilter(true);
    g_strategy.SetUseDeterministicSignals(true);
    g_strategy.SetUsePivotZones(true);
    
    if(!g_strategy.Initialize())
    {
        Print("ERROR: Failed to initialize strategy");
        delete g_strategy;
        g_strategy = NULL;
        return INIT_FAILED;
    }
    
    Print("SUCCESS: Strategy initialized successfully");
    
    // Test seasonal adjustments for all months
    TestSeasonalAdjustments();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== Seasonal Test Deinitialization ===");
    
    if(g_strategy != NULL)
    {
        delete g_strategy;
        g_strategy = NULL;
    }
    
    Print("Test completed. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Test seasonal adjustments for all months                        |
//+------------------------------------------------------------------+
void TestSeasonalAdjustments()
{
    if(g_strategy == NULL || g_strategy.GetRegimeManager() == NULL)
    {
        Print("ERROR: Strategy or regime manager not available");
        return;
    }
    
    CTradingRegimeManager* regime_mgr = g_strategy.GetRegimeManager();
    
    Print("\n=== SEASONAL MULTIPLIERS TEST ===");
    Print("Month | Risk Mult | Target Mult | Description");
    Print("------|-----------|-------------|------------");
    
    // Test each month
    string months[] = {"JAN", "FEB", "MAR", "APR", "MAJ", "JUN", 
                      "JUL", "AUG", "SEP", "OKT", "NOV", "DEC"};
    
    for(int month = 1; month <= 12; month++)
    {
        // Simulate different months by temporarily changing system time
        // Note: This is for testing only - in real trading, current time is used
        
        double risk_mult = GetSeasonalRiskMultiplierForMonth(month);
        double target_mult = GetSeasonalTargetMultiplierForMonth(month);
        string description = GetSeasonalDescriptionForMonth(month);
        
        Print(StringFormat("%s   |   %.1f     |    %.1f      | %s", 
                          months[month-1], risk_mult, target_mult, description));
    }
    
    Print("\n=== CURRENT MONTH DETAILS ===");
    Print("Current seasonal description: ", regime_mgr.GetSeasonalDescription());
    Print("Current risk multiplier: ", regime_mgr.GetSeasonalRiskMultiplier());
    Print("Current target multiplier: ", regime_mgr.GetSeasonalTargetMultiplier());
    
    // Test position sizing impact
    TestPositionSizingImpact();
    
    // Test take profit impact
    TestTakeProfitImpact();
}

//+------------------------------------------------------------------+
//| Test position sizing impact                                      |
//+------------------------------------------------------------------+
void TestPositionSizingImpact()
{
    Print("\n=== POSITION SIZING IMPACT TEST ===");
    
    if(g_strategy.GetRegimeManager() == NULL)
        return;
        
    double base_lot = 0.01;
    double seasonal_mult = g_strategy.GetRegimeManager().GetSeasonalRiskMultiplier();
    double adjusted_lot = base_lot * seasonal_mult;
    
    Print("Base lot size: ", base_lot);
    Print("Seasonal multiplier: ", seasonal_mult);
    Print("Adjusted lot size: ", adjusted_lot);
    
    int current_month = TimeMonth(TimeCurrent());
    if(current_month == 7 || current_month == 8 || current_month == 9)
    {
        Print("HIGH PERFORMANCE MONTH: Increased position size for better profits");
    }
    else if(current_month == 3 || current_month == 4)
    {
        Print("LOW PERFORMANCE MONTH: Reduced position size for capital preservation");
    }
    else if(current_month == 10 || current_month == 11)
    {
        Print("DRAWDOWN RISK MONTH: Conservative position sizing");
    }
}

//+------------------------------------------------------------------+
//| Test take profit impact                                          |
//+------------------------------------------------------------------+
void TestTakeProfitImpact()
{
    Print("\n=== TAKE PROFIT IMPACT TEST ===");
    
    if(g_strategy.GetRegimeManager() == NULL)
        return;
        
    double base_r_multiple = 2.0; // Standard 2R target
    double seasonal_mult = g_strategy.GetRegimeManager().GetSeasonalTargetMultiplier();
    double adjusted_r = base_r_multiple * seasonal_mult;
    
    Print("Base R multiple: ", base_r_multiple);
    Print("Seasonal multiplier: ", seasonal_mult);
    Print("Adjusted R multiple: ", adjusted_r);
    
    // Example calculation
    double entry_price = 18500.0;
    double sl_price = 18480.0; // 20 points SL
    double sl_distance = MathAbs(entry_price - sl_price);
    double tp_distance = sl_distance * adjusted_r;
    double tp_price = entry_price + tp_distance;
    
    Print("Example LONG trade:");
    Print("Entry: ", entry_price);
    Print("SL: ", sl_price, " (", sl_distance, " points)");
    Print("TP: ", tp_price, " (", tp_distance, " points, ", adjusted_r, "R)");
}

//+------------------------------------------------------------------+
//| Helper functions for testing different months                   |
//+------------------------------------------------------------------+
double GetSeasonalRiskMultiplierForMonth(int month)
{
    switch(month)
    {
        case 7:  return 1.4;  // Juli
        case 8:  return 1.3;  // August  
        case 9:  return 1.4;  // September
        case 3:  return 0.6;  // Marts
        case 4:  return 0.6;  // April
        case 10: return 0.7;  // Oktober
        case 11: return 0.7;  // November
        case 12: return 0.8;  // December
        case 1:  return 0.8;  // Januar
        case 2:  return 0.9;  // Februar
        case 5:  return 1.0;  // Maj
        case 6:  return 1.1;  // Juni
        default: return 1.0;
    }
}

double GetSeasonalTargetMultiplierForMonth(int month)
{
    switch(month)
    {
        case 7:  return 1.3;  // Juli
        case 8:  return 1.2;  // August
        case 9:  return 1.3;  // September
        case 3:  return 0.8;  // Marts
        case 4:  return 0.8;  // April
        case 10: return 0.9;  // Oktober
        case 11: return 0.9;  // November
        default: return 1.0;
    }
}

string GetSeasonalDescriptionForMonth(int month)
{
    switch(month)
    {
        case 7:  return "JULI (Høj Performance)";
        case 8:  return "AUGUST (Høj Performance)";
        case 9:  return "SEPTEMBER (Høj Performance)";
        case 3:  return "MARTS (Lav Performance)";
        case 4:  return "APRIL (Lav Performance)";
        case 10: return "OKTOBER (Drawdown Risiko)";
        case 11: return "NOVEMBER (Drawdown Risiko)";
        case 12: return "DECEMBER (Jul Volatilitet)";
        case 1:  return "JANUAR (Nytårs Effekt)";
        case 2:  return "FEBRUAR (Stabilisering)";
        case 5:  return "MAJ (Neutral)";
        case 6:  return "JUNI (Let Positiv)";
        default: return "UKENDT";
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Do nothing - this is just a seasonal test
}
