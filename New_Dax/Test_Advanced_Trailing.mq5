//+------------------------------------------------------------------+
//|                                        Test_Advanced_Trailing.mq5 |
//|                                    Test Advanced Trailing Stops   |
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
    Print("=== Testing Advanced Trailing Stops ===");
    
    // Initialize strategy for 30M timeframe
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
    
    Print("SUCCESS: Strategy initialized for advanced trailing stop testing");
    
    // Test trailing stop scenarios
    TestTrailingStopScenarios();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== Advanced Trailing Stop Test Deinitialization ===");
    
    if(g_strategy != NULL)
    {
        delete g_strategy;
        g_strategy = NULL;
    }
    
    Print("Test completed. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Test trailing stop scenarios                                    |
//+------------------------------------------------------------------+
void TestTrailingStopScenarios()
{
    if(g_strategy == NULL || g_strategy.GetRegimeManager() == NULL)
    {
        Print("ERROR: Strategy or regime manager not available");
        return;
    }
    
    CTradingRegimeManager* regime_mgr = g_strategy.GetRegimeManager();
    
    Print("\n=== ADVANCED TRAILING STOPS TEST ===");
    
    // Test different regime scenarios
    TestRegimeTrailingScenario(REGIME_TRENDING, "TRENDING MARKET");
    TestRegimeTrailingScenario(REGIME_RANGING, "RANGING MARKET");
    TestRegimeTrailingScenario(REGIME_VOLATILE, "VOLATILE MARKET");
    TestRegimeTrailingScenario(REGIME_QUIET, "QUIET MARKET");
    
    // Test profit-based adjustments
    TestProfitBasedTrailing();
    
    // Test seasonal adjustments
    TestSeasonalTrailing();
    
    Print("\n=== CURRENT TRAILING STATUS ===");
    Print(regime_mgr.GetTrailingStopDescription());
}

//+------------------------------------------------------------------+
//| Test regime-specific trailing scenarios                         |
//+------------------------------------------------------------------+
void TestRegimeTrailingScenario(ENUM_TRADING_REGIME regime, string regime_name)
{
    Print("\n--- ", regime_name, " TRAILING SCENARIO ---");
    
    if(g_strategy.GetRegimeManager() == NULL)
        return;
    
    CTradingRegimeManager* regime_mgr = g_strategy.GetRegimeManager();
    
    // Test different profit levels
    double profit_levels[] = {0.5, 1.0, 1.5, 2.0, 3.0, 5.0};
    
    for(int i = 0; i < ArraySize(profit_levels); i++)
    {
        double profit_r = profit_levels[i];
        double trail_distance = regime_mgr.GetTrailingStopDistance(regime, profit_r);
        double breakeven_threshold = regime_mgr.GetBreakevenThreshold(regime);
        bool should_trail = regime_mgr.ShouldActivateTrailing(regime, profit_r);
        
        Print("Profit: ", profit_r, "R | Trail Distance: ", trail_distance, "R | Should Trail: ", 
              should_trail ? "YES" : "NO", " | Breakeven Threshold: ", breakeven_threshold, "R");
    }
}

//+------------------------------------------------------------------+
//| Test profit-based trailing adjustments                          |
//+------------------------------------------------------------------+
void TestProfitBasedTrailing()
{
    Print("\n=== PROFIT-BASED TRAILING ADJUSTMENTS ===");
    
    if(g_strategy.GetRegimeManager() == NULL)
        return;
    
    CTradingRegimeManager* regime_mgr = g_strategy.GetRegimeManager();
    ENUM_TRADING_REGIME current_regime = regime_mgr.GetCurrentRegime();
    
    Print("Current Regime: ", EnumToString(current_regime));
    
    // Simulate position progression
    double entry_price = 18000.0;
    double sl_distance = 10.0; // 10 points
    
    Print("\n--- LONG POSITION PROGRESSION ---");
    Print("Entry: ", entry_price, " | SL Distance: ", sl_distance, " points");
    
    double price_levels[] = {18005.0, 18010.0, 18015.0, 18020.0, 18030.0, 18050.0};
    
    for(int i = 0; i < ArraySize(price_levels); i++)
    {
        double current_price = price_levels[i];
        double profit_r = (current_price - entry_price) / sl_distance;
        double trail_distance = regime_mgr.GetTrailingStopDistance(current_regime, profit_r);
        double new_sl = current_price - (trail_distance * sl_distance);
        
        // Ensure SL doesn't go below entry
        new_sl = MathMax(new_sl, entry_price);
        
        bool should_trail = regime_mgr.ShouldActivateTrailing(current_regime, profit_r);
        
        Print("Price: ", current_price, " | Profit: ", profit_r, "R | Trail Distance: ", 
              trail_distance, "R | New SL: ", new_sl, " | Active: ", should_trail ? "YES" : "NO");
    }
}

//+------------------------------------------------------------------+
//| Test seasonal trailing adjustments                              |
//+------------------------------------------------------------------+
void TestSeasonalTrailing()
{
    Print("\n=== SEASONAL TRAILING ADJUSTMENTS ===");
    
    if(g_strategy.GetRegimeManager() == NULL)
        return;
    
    CTradingRegimeManager* regime_mgr = g_strategy.GetRegimeManager();
    
    // Get current month info
    MqlDateTime dt;
    datetime current_time = ::TimeCurrent();
    ::TimeToStruct(current_time, dt);
    int current_month = dt.mon;
    
    Print("Current Month: ", current_month);
    
    // Test different months
    string month_names[] = {"JAN", "FEB", "MAR", "APR", "MAY", "JUN", 
                           "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"};
    
    for(int month = 1; month <= 12; month++)
    {
        // Simulate month by temporarily changing system time (conceptually)
        string month_name = month_names[month-1];
        
        // Calculate expected adjustments for this month
        double seasonal_trail_mult = 1.0;
        if(month == 7 || month == 8 || month == 9)
            seasonal_trail_mult = 0.8; // Tighter in good months
        else if(month == 3 || month == 4)
            seasonal_trail_mult = 1.3; // Wider in bad months
        else if(month == 10 || month == 11)
            seasonal_trail_mult = 1.2; // Wider in drawdown months
        
        Print(month_name, " (", month, "): Trailing Multiplier = ", seasonal_trail_mult, 
              " | Strategy: ", seasonal_trail_mult < 1.0 ? "AGGRESSIVE" : 
                              seasonal_trail_mult > 1.1 ? "CONSERVATIVE" : "NORMAL");
    }
    
    Print("\nCurrent month (", month_names[current_month-1], ") strategy: ");
    if(current_month == 7 || current_month == 8 || current_month == 9)
        Print("AGGRESSIVE TRAILING - Maximize profits in good months");
    else if(current_month == 3 || current_month == 4)
        Print("CONSERVATIVE TRAILING - Preserve capital in bad months");
    else if(current_month == 10 || current_month == 11)
        Print("CONSERVATIVE TRAILING - Reduce risk in drawdown months");
    else
        Print("NORMAL TRAILING - Standard approach");
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
        Print("=== First Tick - Real-time Trailing Monitoring ===");
        first_tick = false;
    }
    
    tick_count++;
    
    // Monitor trailing every 100 ticks
    if(tick_count % 100 == 0 && g_strategy != NULL && g_strategy.GetRegimeManager() != NULL)
    {
        Print("=== Tick ", tick_count, " - Trailing Status Update ===");
        Print(g_strategy.GetRegimeManager().GetTrailingStopDescription());
        
        // If there's a position, show trailing analysis
        if(PositionSelect(_Symbol))
        {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            bool is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
            double current_price = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            Print("POSITION ANALYSIS:");
            Print("Ticket: ", ticket, " | Entry: ", entry_price, " | Current: ", current_price);
            
            if(g_strategy.ShouldMoveToBreakeven(ticket, entry_price, current_price))
                Print("BREAKEVEN: Position should move to breakeven");
            else
                Print("BREAKEVEN: Not yet ready for breakeven");
        }
        
        // Stop after 500 ticks
        if(tick_count >= 500)
        {
            Print("=== Advanced Trailing Test completed after 500 ticks ===");
            ExpertRemove();
        }
    }
}
