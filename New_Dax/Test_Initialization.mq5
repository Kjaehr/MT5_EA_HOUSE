//+------------------------------------------------------------------+
//|                                           Test_Initialization.mq5 |
//|                                    Test EA Initialization Only     |
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
    Print("=== Testing EA Initialization ===");
    
    // Initialize strategy
    g_strategy = new CAdmiralStrategy(_Symbol, PERIOD_M15);
    
    // Configure strategy with new features enabled
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
    
    // Test getting status
    if(g_strategy != NULL)
    {
        Print("Strategy Status:");
        Print(g_strategy.GetStrategyStatus());
        
        Print("Advanced Components Status:");
        Print(g_strategy.GetAdvancedComponentsStatus());
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== Test Deinitialization ===");
    
    if(g_strategy != NULL)
    {
        delete g_strategy;
        g_strategy = NULL;
    }
    
    Print("Test completed. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Do nothing - this is just an initialization test
    static bool first_tick = true;
    if(first_tick)
    {
        Print("=== First Tick Received ===");
        
        if(g_strategy != NULL)
        {
            // Test signal update
            if(g_strategy.UpdateSignals())
            {
                Print("SUCCESS: Signals updated successfully");
                
                // Test signal check
                SAdmiralSignal signal = g_strategy.CheckEntrySignal();
                Print("Signal check result: Valid=", signal.is_valid, " Long=", signal.is_long, " Strength=", signal.signal_strength);
            }
            else
            {
                Print("WARNING: Failed to update signals");
            }
        }
        
        first_tick = false;
    }
}
