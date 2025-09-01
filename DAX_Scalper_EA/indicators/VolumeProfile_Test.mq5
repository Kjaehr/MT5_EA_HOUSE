//+------------------------------------------------------------------+
//|                                           VolumeProfile_Test.mq5 |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"
#property version   "1.00"

//--- Include Volume Profile Helper
#include "../Include/VolumeProfileHelper.mqh"

//--- Input parameters
input int      TestPeriod = 20;           // Test period for volume profile
input bool     ShowDebugInfo = true;     // Show debug information
input bool     TestIntegration = true;   // Test EA integration features

//--- Global objects
CVolumeProfileHelper* g_volume_profile = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Volume Profile Test EA Starting ===");
    
    //--- Initialize Volume Profile Helper
    g_volume_profile = new CVolumeProfileHelper(_Symbol, _Period);
    if(g_volume_profile == NULL)
    {
        Print("Failed to create Volume Profile Helper");
        return INIT_FAILED;
    }
    
    //--- Initialize with test parameters
    if(!g_volume_profile.Initialize(TestPeriod, 50, 70.0))
    {
        Print("Failed to initialize Volume Profile Helper");
        delete g_volume_profile;
        g_volume_profile = NULL;
        return INIT_FAILED;
    }
    
    Print("Volume Profile Test EA initialized successfully");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(g_volume_profile != NULL)
    {
        delete g_volume_profile;
        g_volume_profile = NULL;
    }
    
    Print("Volume Profile Test EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime last_test_time = 0;
    static int tick_count = 0;
    
    tick_count++;
    
    //--- Run tests every 10 seconds
    if(TimeCurrent() - last_test_time >= 10)
    {
        last_test_time = TimeCurrent();
        
        if(ShowDebugInfo)
            RunVolumeProfileTests();
    }
    
    //--- Test integration features every 100 ticks
    if(TestIntegration && tick_count % 100 == 0)
    {
        TestEAIntegration();
    }
}

//+------------------------------------------------------------------+
//| Run Volume Profile Tests                                        |
//+------------------------------------------------------------------+
void RunVolumeProfileTests()
{
    if(g_volume_profile == NULL || !g_volume_profile.IsDataReady())
    {
        Print("Volume Profile data not ready");
        return;
    }
    
    Print("\n=== Volume Profile Test Results ===");
    
    //--- Get current market data
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    //--- Test basic data retrieval
    double poc = g_volume_profile.GetCurrentPOC();
    double vah = g_volume_profile.GetCurrentValueAreaHigh();
    double val = g_volume_profile.GetCurrentValueAreaLow();
    
    Print("Current Price: ", DoubleToString(current_price, _Digits));
    Print("POC: ", DoubleToString(poc, _Digits));
    Print("Value Area High: ", DoubleToString(vah, _Digits));
    Print("Value Area Low: ", DoubleToString(val, _Digits));
    
    if(vah > 0 && val > 0)
    {
        Print("Value Area Range: ", DoubleToString(vah - val, _Digits), " points");
    }
    
    //--- Test price analysis
    bool in_value_area = g_volume_profile.IsPriceInValueArea(current_price);
    bool near_poc = g_volume_profile.IsPriceNearPOC(current_price, 5.0);
    
    Print("Price in Value Area: ", (in_value_area ? "YES" : "NO"));
    Print("Price near POC: ", (near_poc ? "YES" : "NO"));
    
    //--- Test support/resistance levels
    double support = g_volume_profile.GetVolumeBasedSupport(current_price);
    double resistance = g_volume_profile.GetVolumeBasedResistance(current_price);
    
    if(support > 0)
        Print("Volume-based Support: ", DoubleToString(support, _Digits));
    if(resistance > 0)
        Print("Volume-based Resistance: ", DoubleToString(resistance, _Digits));
    
    //--- Test breakout detection
    static double previous_price = 0;
    if(previous_price > 0)
    {
        bool poc_breakout = g_volume_profile.IsPOCBreakout(current_price, previous_price);
        if(poc_breakout)
            Print("*** POC BREAKOUT DETECTED ***");
        
        bool is_upward;
        bool va_breakout = g_volume_profile.IsValueAreaBreakout(current_price, is_upward);
        if(va_breakout)
            Print("*** VALUE AREA BREAKOUT: ", (is_upward ? "UPWARD" : "DOWNWARD"), " ***");
    }
    previous_price = current_price;
    
    //--- Print status
    Print("Status: ", g_volume_profile.GetStatusString());
    Print("=====================================\n");
}

//+------------------------------------------------------------------+
//| Test EA Integration Features                                    |
//+------------------------------------------------------------------+
void TestEAIntegration()
{
    if(g_volume_profile == NULL || !g_volume_profile.IsDataReady())
        return;
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    //--- Test optimal entry levels
    double long_entry = g_volume_profile.GetOptimalEntryLevel(current_price, true);
    double short_entry = g_volume_profile.GetOptimalEntryLevel(current_price, false);
    
    //--- Test volume-based targets
    double long_target = g_volume_profile.GetVolumeBasedTarget(current_price, true);
    double short_target = g_volume_profile.GetVolumeBasedTarget(current_price, false);
    
    //--- Simulate trading signals
    bool in_value_area = g_volume_profile.IsPriceInValueArea(current_price);
    bool near_poc = g_volume_profile.IsPriceNearPOC(current_price, 3.0);
    
    //--- Example trading logic
    if(!in_value_area && near_poc)
    {
        Print("TRADING SIGNAL: Price outside Value Area but near POC - Potential reversal setup");
        
        if(long_target > current_price)
        {
            Print("LONG SETUP: Entry=", DoubleToString(long_entry, _Digits), 
                  " Target=", DoubleToString(long_target, _Digits));
        }
        
        if(short_target < current_price && short_target > 0)
        {
            Print("SHORT SETUP: Entry=", DoubleToString(short_entry, _Digits), 
                  " Target=", DoubleToString(short_target, _Digits));
        }
    }
    
    //--- Test breakout scenarios
    bool is_upward;
    if(g_volume_profile.IsValueAreaBreakout(current_price, is_upward))
    {
        Print("BREAKOUT SIGNAL: Value Area ", (is_upward ? "UPWARD" : "DOWNWARD"), " breakout");
        
        if(is_upward && long_target > current_price)
        {
            Print("BREAKOUT LONG: Target=", DoubleToString(long_target, _Digits));
        }
        else if(!is_upward && short_target < current_price && short_target > 0)
        {
            Print("BREAKOUT SHORT: Target=", DoubleToString(short_target, _Digits));
        }
    }
}

//+------------------------------------------------------------------+
//| OnTimer function for periodic tests                             |
//+------------------------------------------------------------------+
void OnTimer()
{
    if(g_volume_profile != NULL)
    {
        g_volume_profile.PrintVolumeProfile();
    }
}

//+------------------------------------------------------------------+
//| Test function for manual execution                              |
//+------------------------------------------------------------------+
void TestVolumeProfileManual()
{
    Print("=== Manual Volume Profile Test ===");
    
    if(g_volume_profile == NULL)
    {
        Print("Volume Profile Helper not initialized");
        return;
    }
    
    if(!g_volume_profile.IsDataReady())
    {
        Print("Volume Profile data not ready");
        return;
    }
    
    //--- Print comprehensive volume profile information
    g_volume_profile.PrintVolumeProfile();
    
    //--- Test all integration methods
    double test_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    Print("Testing with price: ", DoubleToString(test_price, _Digits));
    Print("In Value Area: ", g_volume_profile.IsPriceInValueArea(test_price));
    Print("Near POC: ", g_volume_profile.IsPriceNearPOC(test_price));
    Print("Support: ", DoubleToString(g_volume_profile.GetVolumeBasedSupport(test_price), _Digits));
    Print("Resistance: ", DoubleToString(g_volume_profile.GetVolumeBasedResistance(test_price), _Digits));
    Print("Long Entry: ", DoubleToString(g_volume_profile.GetOptimalEntryLevel(test_price, true), _Digits));
    Print("Short Entry: ", DoubleToString(g_volume_profile.GetOptimalEntryLevel(test_price, false), _Digits));
    Print("Long Target: ", DoubleToString(g_volume_profile.GetVolumeBasedTarget(test_price, true), _Digits));
    Print("Short Target: ", DoubleToString(g_volume_profile.GetVolumeBasedTarget(test_price, false), _Digits));
    
    Print("=== Manual Test Complete ===");
}
