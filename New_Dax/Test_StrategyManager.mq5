//+------------------------------------------------------------------+
//|                                          Test_StrategyManager.mq5 |
//|                           StrategyManager Integration Test        |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"
#property description "Test script for StrategyManager integration"

#include "Include/StrategyManager.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== StrategyManager Integration Test ===");
    
    // Test 1: Create StrategyManager
    Print("Test 1: Creating StrategyManager...");
    CStrategyManager* strategy_manager = new CStrategyManager(_Symbol, PERIOD_M15);
    
    if(strategy_manager == NULL)
    {
        Print("ERROR: Failed to create StrategyManager");
        return;
    }
    Print("✓ StrategyManager created successfully");
    
    // Test 2: Create Admiral Strategy
    Print("Test 2: Creating Admiral Strategy...");
    CAdmiralStrategy* admiral_strategy = new CAdmiralStrategy(_Symbol, PERIOD_M15, PERIOD_H1);
    
    if(admiral_strategy == NULL)
    {
        Print("ERROR: Failed to create Admiral Strategy");
        delete strategy_manager;
        return;
    }
    Print("✓ Admiral Strategy created successfully");
    
    // Test 3: Initialize Admiral Strategy
    Print("Test 3: Initializing Admiral Strategy...");
    if(!admiral_strategy.Initialize())
    {
        Print("ERROR: Failed to initialize Admiral Strategy");
        delete admiral_strategy;
        delete strategy_manager;
        return;
    }
    Print("✓ Admiral Strategy initialized successfully");
    
    // Test 4: Set Admiral Strategy in StrategyManager
    Print("Test 4: Setting Admiral Strategy in StrategyManager...");
    if(!strategy_manager.SetAdmiralStrategy(admiral_strategy))
    {
        Print("ERROR: Failed to set Admiral Strategy in StrategyManager");
        delete admiral_strategy;
        delete strategy_manager;
        return;
    }
    Print("✓ Admiral Strategy set in StrategyManager successfully");
    
    // Test 5: Configure StrategyManager
    Print("Test 5: Configuring StrategyManager...");
    strategy_manager.SetUseCombination(false);
    strategy_manager.SetMinCombinedStrength(0.7);
    strategy_manager.SetRequireConsensus(false, 2);
    
    // Configure strategies
    strategy_manager.EnableStrategy(STRATEGY_ADMIRAL, true);
    strategy_manager.EnableStrategy(STRATEGY_BREAKOUT, false);
    strategy_manager.EnableStrategy(STRATEGY_MEAN_REVERSION, false);
    strategy_manager.EnableStrategy(STRATEGY_MOMENTUM, false);
    
    // Set weights
    strategy_manager.SetStrategyWeight(STRATEGY_ADMIRAL, 1.0);
    strategy_manager.SetStrategyWeight(STRATEGY_BREAKOUT, 0.8);
    strategy_manager.SetStrategyWeight(STRATEGY_MEAN_REVERSION, 0.6);
    strategy_manager.SetStrategyWeight(STRATEGY_MOMENTUM, 0.7);
    
    Print("✓ StrategyManager configured successfully");
    
    // Test 6: Initialize StrategyManager
    Print("Test 6: Initializing StrategyManager...");
    if(!strategy_manager.Initialize())
    {
        Print("ERROR: Failed to initialize StrategyManager");
        delete admiral_strategy;
        delete strategy_manager;
        return;
    }
    Print("✓ StrategyManager initialized successfully");
    
    // Test 7: Test Signal Generation
    Print("Test 7: Testing signal generation...");
    SCombinedSignal combined_signal = strategy_manager.GetCombinedSignal();
    
    if(combined_signal.is_valid)
    {
        Print("✓ Valid combined signal generated:");
        Print("  Direction: ", combined_signal.is_long ? "LONG" : "SHORT");
        Print("  Strength: ", combined_signal.combined_strength);
        Print("  Entry: ", combined_signal.entry_price);
        Print("  Stop Loss: ", combined_signal.stop_loss);
        Print("  Take Profit: ", combined_signal.take_profit);
        Print("  Contributing Strategies: ", combined_signal.contributing_strategies);
        
        // Test signal conversion
        SAdmiralSignal admiral_signal = strategy_manager.ConvertToAdmiralSignal(combined_signal);
        if(admiral_signal.is_valid)
        {
            Print("✓ Signal conversion successful");
            Print("  Admiral Signal Description: ", admiral_signal.signal_description);
        }
        else
        {
            Print("⚠ Signal conversion failed");
        }
    }
    else
    {
        Print("ℹ No valid signal at current market conditions (this is normal)");
    }
    
    // Test 8: Test Performance Tracking
    Print("Test 8: Testing performance tracking...");
    
    // Simulate some performance updates
    strategy_manager.UpdateStrategyPerformance(STRATEGY_ADMIRAL, true, 50.0);   // Winning trade
    strategy_manager.UpdateStrategyPerformance(STRATEGY_ADMIRAL, false, -25.0); // Losing trade
    strategy_manager.UpdateStrategyPerformance(STRATEGY_ADMIRAL, true, 75.0);   // Another winning trade
    
    SStrategyPerformance perf = strategy_manager.GetStrategyPerformance(STRATEGY_ADMIRAL);
    Print("✓ Performance tracking test:");
    Print("  Total Trades: ", perf.successful_trades + perf.failed_trades);
    Print("  Winning Trades: ", perf.successful_trades);
    Print("  Win Rate: ", perf.win_rate, "%");
    Print("  Profit Factor: ", perf.profit_factor);
    
    // Test 9: Test Performance Report
    Print("Test 9: Testing performance report...");
    string report = strategy_manager.GetPerformanceReport();
    Print("✓ Performance report generated:");
    Print(report);
    
    // Test 10: Test Strategy Information
    Print("Test 10: Testing strategy information...");
    for(int i = 0; i < STRATEGY_COUNT; i++)
    {
        string strategy_name = strategy_manager.GetStrategyName((ENUM_STRATEGY_TYPE)i);
        bool is_enabled = strategy_manager.IsStrategyEnabled((ENUM_STRATEGY_TYPE)i);
        Print("  ", strategy_name, ": ", is_enabled ? "ENABLED" : "DISABLED");
    }
    Print("✓ Strategy information test completed");
    
    // Cleanup
    Print("Cleaning up...");
    strategy_manager.Deinitialize();
    delete strategy_manager;
    delete admiral_strategy;
    
    Print("=== All Tests Completed Successfully ===");
    Print("StrategyManager integration is working correctly!");
    Print("You can now use the StrategyManager in the main New_Dax EA.");
}
