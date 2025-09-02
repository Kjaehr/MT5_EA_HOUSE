//+------------------------------------------------------------------+
//|                                      Test_Volatility_Adaptive.mq5 |
//|                                    Test Volatility-Adaptive Sizing |
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
    Print("=== Testing Volatility-Adaptive Sizing ===");
    
    // Initialize strategy for 30M timeframe (optimal for volatility adaptation)
    g_strategy = new CAdmiralStrategy(_Symbol, PERIOD_M30);
    
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
    
    Print("SUCCESS: Strategy initialized successfully for 30M timeframe");
    
    // Test volatility-adaptive sizing
    TestVolatilityAdaptiveSizing();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== Volatility-Adaptive Test Deinitialization ===");
    
    if(g_strategy != NULL)
    {
        delete g_strategy;
        g_strategy = NULL;
    }
    
    Print("Test completed. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Test volatility-adaptive sizing                                 |
//+------------------------------------------------------------------+
void TestVolatilityAdaptiveSizing()
{
    if(g_strategy == NULL || g_strategy.GetRegimeManager() == NULL)
    {
        Print("ERROR: Strategy or regime manager not available");
        return;
    }
    
    CTradingRegimeManager* regime_mgr = g_strategy.GetRegimeManager();
    
    Print("\n=== VOLATILITY-ADAPTIVE SIZING TEST ===");
    
    // Get current volatility metrics
    double current_atr = regime_mgr.GetCurrentATR();
    double vol_multiplier = regime_mgr.GetVolatilityMultiplier();
    double seasonal_mult = regime_mgr.GetSeasonalRiskMultiplier();
    double combined_mult = regime_mgr.GetCombinedRiskMultiplier();
    
    Print("Current ATR: ", current_atr, " points");
    Print("Volatility Multiplier: ", vol_multiplier);
    Print("Seasonal Multiplier: ", seasonal_mult);
    Print("Combined Multiplier: ", combined_mult);
    
    Print("\n=== VOLATILITY SCENARIOS ===");
    
    // Test different volatility scenarios
    TestVolatilityScenario("LOW VOLATILITY (High ATR)", 40.0, 0.01);
    TestVolatilityScenario("NORMAL VOLATILITY (Medium ATR)", 25.0, 0.01);
    TestVolatilityScenario("HIGH VOLATILITY (Low ATR)", 15.0, 0.01);
    TestVolatilityScenario("EXTREME VOLATILITY (Very Low ATR)", 8.0, 0.01);
    
    Print("\n=== CURRENT STATUS ===");
    Print(regime_mgr.GetVolatilityDescription());
    Print(regime_mgr.GetSeasonalDescription());
    
    // Test position sizing impact
    TestPositionSizingImpact();
}

//+------------------------------------------------------------------+
//| Test specific volatility scenario                               |
//+------------------------------------------------------------------+
void TestVolatilityScenario(string scenario_name, double test_atr, double base_lot)
{
    Print("\n--- ", scenario_name, " ---");
    
    // Calculate volatility multiplier for test ATR
    double baseline_atr = 25.0; // 30M baseline
    double vol_ratio = baseline_atr / test_atr;
    double vol_mult = MathMax(0.5, MathMin(2.0, vol_ratio));
    vol_mult = 1.0 + (vol_mult - 1.0) * 0.7; // 70% smoothing
    
    // Get current seasonal multiplier
    double seasonal_mult = 1.0;
    if(g_strategy.GetRegimeManager() != NULL)
        seasonal_mult = g_strategy.GetRegimeManager().GetSeasonalRiskMultiplier();
    
    double combined_mult = seasonal_mult * vol_mult;
    combined_mult = MathMax(0.3, MathMin(3.0, combined_mult));
    
    double adjusted_lot = base_lot * combined_mult;
    
    Print("Test ATR: ", test_atr, " | Vol Mult: ", vol_mult, 
          " | Seasonal: ", seasonal_mult, " | Combined: ", combined_mult);
    Print("Base Lot: ", base_lot, " | Adjusted Lot: ", adjusted_lot, 
          " | Change: ", (adjusted_lot/base_lot - 1.0) * 100, "%");
}

//+------------------------------------------------------------------+
//| Test position sizing impact                                      |
//+------------------------------------------------------------------+
void TestPositionSizingImpact()
{
    Print("\n=== POSITION SIZING IMPACT ===");
    
    if(g_strategy.GetRegimeManager() == NULL)
        return;
    
    CTradingRegimeManager* regime_mgr = g_strategy.GetRegimeManager();
    
    double base_lot = 0.01;
    double base_risk_percent = 1.0;
    
    double vol_mult = regime_mgr.GetVolatilityMultiplier();
    double seasonal_mult = regime_mgr.GetSeasonalRiskMultiplier();
    double combined_mult = regime_mgr.GetCombinedRiskMultiplier();
    
    Print("=== FIXED LOT SIZING ===");
    Print("Base lot size: ", base_lot);
    Print("Volatility adjustment: ", base_lot * vol_mult);
    Print("Seasonal adjustment: ", base_lot * seasonal_mult);
    Print("Combined adjustment: ", base_lot * combined_mult);
    
    Print("\n=== RISK-BASED SIZING ===");
    double account_balance = 10000.0; // Example balance
    double base_risk = account_balance * (base_risk_percent / 100.0);
    
    Print("Account balance: ", account_balance);
    Print("Base risk amount: ", base_risk);
    Print("Volatility adjusted risk: ", base_risk * vol_mult);
    Print("Seasonal adjusted risk: ", base_risk * seasonal_mult);
    Print("Combined adjusted risk: ", base_risk * combined_mult);
    
    // Calculate expected performance impact
    Print("\n=== EXPECTED PERFORMANCE IMPACT ===");
    
    MqlDateTime dt;
    datetime current_time = ::TimeCurrent();
    ::TimeToStruct(current_time, dt);
    int month = dt.mon;
    
    if(month == 7 || month == 8 || month == 9)
    {
        Print("HIGH PERFORMANCE MONTH: Maximizing position size");
        Print("Expected profit increase: +", (combined_mult - 1.0) * 100, "%");
    }
    else if(month == 3 || month == 4)
    {
        Print("LOW PERFORMANCE MONTH: Reducing position size for capital preservation");
        Print("Expected drawdown reduction: ", (1.0 - combined_mult) * 100, "%");
    }
    else if(month == 10 || month == 11)
    {
        Print("DRAWDOWN RISK MONTH: Conservative sizing");
        Print("Expected risk reduction: ", (1.0 - combined_mult) * 100, "%");
    }
    
    if(vol_mult > 1.2)
    {
        Print("LOW VOLATILITY: Increasing position size for better returns");
    }
    else if(vol_mult < 0.8)
    {
        Print("HIGH VOLATILITY: Reducing position size for risk management");
    }
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
        Print("=== First Tick - Real-time Volatility Monitoring ===");
        first_tick = false;
    }
    
    tick_count++;
    
    // Monitor volatility every 50 ticks
    if(tick_count % 50 == 0 && g_strategy != NULL && g_strategy.GetRegimeManager() != NULL)
    {
        Print("=== Tick ", tick_count, " - Volatility Update ===");
        Print(g_strategy.GetRegimeManager().GetVolatilityDescription());
        
        // Stop after 200 ticks to avoid spam
        if(tick_count >= 200)
        {
            Print("=== Volatility-Adaptive Test completed after 200 ticks ===");
            ExpertRemove();
        }
    }
}
