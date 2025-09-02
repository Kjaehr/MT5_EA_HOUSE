//+------------------------------------------------------------------+
//|                                             Test_Robust_Init.mq5 |
//|                                    Test Robust EA Initialization  |
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
    Print("=== Testing Robust EA Initialization ===");
    Print("Symbol: ", _Symbol);
    Print("Timeframe: ", EnumToString(_Period));
    
    // Initialize strategy
    g_strategy = new CAdmiralStrategy(_Symbol, PERIOD_M15);
    
    // Configure strategy with progressive feature enabling
    Print("Configuring strategy features...");
    
    // Start with basic features
    g_strategy.SetMinSignalStrength(0.7);
    g_strategy.SetStopLossBuffer(7);
    g_strategy.SetUseDynamicStops(true);
    g_strategy.SetUsePivotTargets(true);
    g_strategy.SetUseMACDTrend(false);
    
    // Enable advanced features one by one
    g_strategy.SetUseRegimeBasedTrading(true);
    Print("Regime-based trading: ENABLED");
    
    g_strategy.SetUseH4BiasFilter(true);
    Print("H4 bias filter: ENABLED");
    
    g_strategy.SetUseDeterministicSignals(true);
    Print("Deterministic signals: ENABLED");
    
    g_strategy.SetUsePivotZones(true);
    Print("Pivot zones: ENABLED");
    
    // Try to initialize
    Print("Attempting to initialize strategy...");
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
        Print("=== STRATEGY STATUS ===");
        Print(g_strategy.GetStrategyStatus());
        
        Print("=== ADVANCED COMPONENTS STATUS ===");
        Print(g_strategy.GetAdvancedComponentsStatus());
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== Robust Test Deinitialization ===");
    
    if(g_strategy != NULL)
    {
        Print("Final strategy status:");
        Print(g_strategy.GetStrategyStatus());
        
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
    static bool first_tick = true;
    static int tick_count = 0;
    
    if(first_tick)
    {
        Print("=== First Tick Received ===");
        first_tick = false;
    }
    
    tick_count++;
    
    // Test every 10 ticks
    if(tick_count % 10 == 0 && g_strategy != NULL)
    {
        Print("=== Tick ", tick_count, " Test ===");
        
        // Test signal update
        if(g_strategy.UpdateSignals())
        {
            Print("SUCCESS: Signals updated successfully");
            
            // Test signal check
            SAdmiralSignal signal = g_strategy.CheckEntrySignal();
            if(signal.is_valid)
            {
                Print("SIGNAL FOUND: ", signal.signal_description);
                Print("Direction: ", signal.is_long ? "LONG" : "SHORT");
                Print("Entry: ", signal.entry_price);
                Print("SL: ", signal.stop_loss);
                Print("TP: ", signal.take_profit);
                Print("Strength: ", signal.signal_strength);
            }
            else
            {
                Print("No valid signal at this time");
            }
        }
        else
        {
            Print("WARNING: Failed to update signals");
        }
        
        // Stop after 50 ticks to avoid spam
        if(tick_count >= 50)
        {
            Print("=== Test completed after 50 ticks ===");
            ExpertRemove();
        }
    }
}
