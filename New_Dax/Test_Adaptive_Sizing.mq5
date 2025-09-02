//+------------------------------------------------------------------+
//| Test_Adaptive_Sizing.mq5                                        |
//| Test script for adaptive position sizing features               |
//+------------------------------------------------------------------+
#property copyright "Admiral Markets"
#property version   "1.00"
#property script_show_inputs

#include "Include/AdmiralStrategy.mqh"

// Test inputs
input group "=== Test Parameters ==="
input double TestAccountBalance = 10000.0;     // Test account balance
input double TestCurrentEquity = 9500.0;      // Test current equity (for drawdown)
input int TestRecentTrades = 10;              // Number of recent trades to simulate

// Global variables
CAdmiralStrategy* g_strategy = NULL;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== ADAPTIVE POSITION SIZING TEST ===");
    
    // Initialize strategy for testing
    g_strategy = new CAdmiralStrategy(_Symbol, PERIOD_M30, PERIOD_H4);
    if(g_strategy == NULL)
    {
        Print("ERROR: Failed to create strategy");
        return;
    }
    
    if(!g_strategy.Initialize())
    {
        Print("ERROR: Failed to initialize strategy");
        delete g_strategy;
        return;
    }
    
    // Test scenarios
    TestDrawdownAdaptiveSizing();
    TestPerformanceAdaptiveSizing();
    TestCombinedAdaptiveSizing();
    TestSeasonalIntegration();
    
    // Cleanup
    delete g_strategy;
    g_strategy = NULL;
    
    Print("=== ADAPTIVE SIZING TEST COMPLETED ===");
}

//+------------------------------------------------------------------+
//| Test drawdown-adaptive sizing                                   |
//+------------------------------------------------------------------+
void TestDrawdownAdaptiveSizing()
{
    Print("\n--- DRAWDOWN ADAPTIVE SIZING TEST ---");
    
    double base_lot = 0.01;
    double peak_equity = TestAccountBalance;
    
    // Test different drawdown scenarios
    double drawdown_scenarios[] = {0.0, 2.5, 5.0, 7.5, 10.0, 15.0, 20.0};
    
    for(int i = 0; i < ArraySize(drawdown_scenarios); i++)
    {
        double drawdown = drawdown_scenarios[i];
        double current_equity = peak_equity * (1.0 - drawdown / 100.0);
        
        // Calculate drawdown multiplier
        double drawdown_multiplier = 1.0;
        if(drawdown > 5.0) // Threshold
        {
            double drawdown_factor = (drawdown - 5.0) / (20.0 - 5.0); // 20% max drawdown
            drawdown_factor = MathMin(drawdown_factor, 1.0);
            drawdown_multiplier = 1.0 - (drawdown_factor * (1.0 - 0.5)); // 50% max reduction
            drawdown_multiplier = MathMax(drawdown_multiplier, 0.5);
        }
        
        double adjusted_lot = base_lot * drawdown_multiplier;
        
        Print("Drawdown: ", drawdown, "% | Equity: ", current_equity, 
              " | Multiplier: ", drawdown_multiplier, " | Lot: ", adjusted_lot,
              " | Reduction: ", (1.0 - drawdown_multiplier) * 100, "%");
    }
}

//+------------------------------------------------------------------+
//| Test performance-adaptive sizing                                |
//+------------------------------------------------------------------+
void TestPerformanceAdaptiveSizing()
{
    Print("\n--- PERFORMANCE ADAPTIVE SIZING TEST ---");
    
    double base_lot = 0.01;
    
    // Simulate different performance scenarios
    struct PerformanceScenario
    {
        string name;
        double trades[];
    };
    
    PerformanceScenario scenarios[4];
    
    // Excellent performance
    scenarios[0].name = "Excellent Performance";
    ArrayResize(scenarios[0].trades, 10);
    for(int i = 0; i < 10; i++) scenarios[0].trades[i] = 50.0 + (i % 3) * 25.0; // Mostly wins
    
    // Good performance
    scenarios[1].name = "Good Performance";
    ArrayResize(scenarios[1].trades, 10);
    for(int i = 0; i < 10; i++) scenarios[1].trades[i] = (i % 3 == 0) ? -30.0 : 40.0; // 70% win rate
    
    // Poor performance
    scenarios[2].name = "Poor Performance";
    ArrayResize(scenarios[2].trades, 10);
    for(int i = 0; i < 10; i++) scenarios[2].trades[i] = (i % 3 == 0) ? 20.0 : -35.0; // 30% win rate
    
    // Mixed performance
    scenarios[3].name = "Mixed Performance";
    ArrayResize(scenarios[3].trades, 10);
    for(int i = 0; i < 10; i++) scenarios[3].trades[i] = (i % 2 == 0) ? 30.0 : -30.0; // 50% win rate
    
    for(int s = 0; s < ArraySize(scenarios); s++)
    {
        Print("\n", scenarios[s].name, ":");
        
        // Calculate performance metrics
        double total_pnl = 0.0;
        int wins = 0;
        int valid_trades = ArraySize(scenarios[s].trades);
        
        for(int i = 0; i < valid_trades; i++)
        {
            total_pnl += scenarios[s].trades[i];
            if(scenarios[s].trades[i] > 0) wins++;
        }
        
        double avg_pnl = total_pnl / valid_trades;
        double win_rate = (double)wins / valid_trades;
        
        // Calculate performance score
        double performance_score = (avg_pnl > 0 ? 1.0 : 0.5) + (win_rate - 0.5);
        
        // Convert to multiplier
        double performance_multiplier = 1.0;
        if(performance_score > 1.0)
        {
            performance_multiplier = 1.0 + (performance_score - 1.0) * (1.3 - 1.0); // Max 1.3x
        }
        else
        {
            performance_multiplier = 0.7 + (performance_score * (1.0 - 0.7)); // Min 0.7x
        }
        
        performance_multiplier = MathMax(performance_multiplier, 0.7);
        performance_multiplier = MathMin(performance_multiplier, 1.3);
        
        double adjusted_lot = base_lot * performance_multiplier;
        
        Print("Avg P&L: ", avg_pnl, " | Win Rate: ", win_rate * 100, "% | Score: ", performance_score);
        Print("Performance Multiplier: ", performance_multiplier, " | Adjusted Lot: ", adjusted_lot);
    }
}

//+------------------------------------------------------------------+
//| Test combined adaptive sizing                                   |
//+------------------------------------------------------------------+
void TestCombinedAdaptiveSizing()
{
    Print("\n--- COMBINED ADAPTIVE SIZING TEST ---");
    
    double base_lot = 0.01;
    
    // Get seasonal and volatility multipliers from strategy
    double seasonal_mult = 1.0;
    double volatility_mult = 1.0;
    
    if(g_strategy.GetRegimeManager() != NULL)
    {
        seasonal_mult = g_strategy.GetRegimeManager().GetSeasonalRiskMultiplier();
        volatility_mult = g_strategy.GetRegimeManager().GetVolatilityMultiplier();
    }
    
    // Test different combinations
    struct CombinedScenario
    {
        string name;
        double drawdown_mult;
        double performance_mult;
    };
    
    CombinedScenario scenarios[4];
    scenarios[0].name = "Optimal Conditions";
    scenarios[0].drawdown_mult = 1.0;    // No drawdown
    scenarios[0].performance_mult = 1.3; // Excellent performance
    
    scenarios[1].name = "Good Conditions";
    scenarios[1].drawdown_mult = 0.9;    // Small drawdown
    scenarios[1].performance_mult = 1.1; // Good performance
    
    scenarios[2].name = "Challenging Conditions";
    scenarios[2].drawdown_mult = 0.7;    // Moderate drawdown
    scenarios[2].performance_mult = 0.8; // Poor performance
    
    scenarios[3].name = "Crisis Conditions";
    scenarios[3].drawdown_mult = 0.5;    // High drawdown
    scenarios[3].performance_mult = 0.7; // Very poor performance
    
    for(int i = 0; i < ArraySize(scenarios); i++)
    {
        double total_multiplier = seasonal_mult * volatility_mult * 
                                 scenarios[i].drawdown_mult * scenarios[i].performance_mult;
        
        // Apply safety limits
        total_multiplier = MathMax(0.2, MathMin(3.0, total_multiplier));
        
        double final_lot = base_lot * total_multiplier;
        
        Print(scenarios[i].name, ":");
        Print("  Seasonal: ", seasonal_mult, " | Volatility: ", volatility_mult);
        Print("  Drawdown: ", scenarios[i].drawdown_mult, " | Performance: ", scenarios[i].performance_mult);
        Print("  Total Multiplier: ", total_multiplier, " | Final Lot: ", final_lot);
        Print("  Size Change: ", (total_multiplier - 1.0) * 100, "%");
    }
}

//+------------------------------------------------------------------+
//| Test seasonal integration                                       |
//+------------------------------------------------------------------+
void TestSeasonalIntegration()
{
    Print("\n--- SEASONAL INTEGRATION TEST ---");
    
    if(g_strategy.GetRegimeManager() == NULL)
    {
        Print("ERROR: Regime manager not available");
        return;
    }
    
    CTradingRegimeManager* regime_mgr = g_strategy.GetRegimeManager();
    
    double base_lot = 0.01;
    double seasonal_mult = regime_mgr.GetSeasonalRiskMultiplier();
    double volatility_mult = regime_mgr.GetVolatilityMultiplier();
    double combined_mult = regime_mgr.GetCombinedRiskMultiplier();
    
    Print("Current seasonal multiplier: ", seasonal_mult);
    Print("Current volatility multiplier: ", volatility_mult);
    Print("Combined multiplier: ", combined_mult);
    
    int current_month = TimeMonth(TimeCurrent());
    string seasonal_description = regime_mgr.GetSeasonalDescription();
    string volatility_description = regime_mgr.GetVolatilityDescription();
    
    Print("Current month: ", current_month);
    Print("Seasonal description: ", seasonal_description);
    Print("Volatility description: ", volatility_description);
    
    // Show impact on position sizing
    double base_risk_amount = TestAccountBalance * 0.01; // 1% risk
    double adjusted_risk = base_risk_amount * combined_mult;
    double adjusted_lot = base_lot * combined_mult;
    
    Print("Base risk amount: ", base_risk_amount);
    Print("Adjusted risk amount: ", adjusted_risk);
    Print("Base lot size: ", base_lot);
    Print("Adjusted lot size: ", adjusted_lot);
    Print("Risk adjustment: ", (combined_mult - 1.0) * 100, "%");
}
