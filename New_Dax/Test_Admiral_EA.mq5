//+------------------------------------------------------------------+
//|                                              Test_Admiral_EA.mq5 |
//|                                    Test script for Admiral EA    |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"
#property script_show_inputs

#include "Include/AdmiralStrategy.mqh"

//--- Input parameters
input ENUM_TIMEFRAMES TestTimeframe = PERIOD_M15;
input ENUM_TIMEFRAMES TestPivotTimeframe = PERIOD_H1;
input bool TestVerbose = true;

//+------------------------------------------------------------------+
//| Script program start function                                   |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== Admiral EA Component Test ===");
    
    // Test 1: Admiral Pivot Points
    TestPivotPoints();
    
    // Test 2: MACD Signal
    TestMACDSignal();
    
    // Test 3: Stochastic Signal
    TestStochasticSignal();
    
    // Test 4: Moving Average Signal
    TestMovingAverageSignal();
    
    // Test 5: Swing Point Detector
    TestSwingPointDetector();
    
    // Test 6: Complete Strategy
    TestCompleteStrategy();
    
    Print("=== Test Completed ===");
}

//+------------------------------------------------------------------+
//| Test Admiral Pivot Points                                      |
//+------------------------------------------------------------------+
void TestPivotPoints()
{
    Print("--- Testing Admiral Pivot Points ---");
    
    CAdmiralPivotPoints* pivot = new CAdmiralPivotPoints(_Symbol, TestPivotTimeframe);
    
    if(pivot.Initialize())
    {
        Print("✓ Pivot Points initialized successfully");
        Print(pivot.GetPivotLevelsString());
        
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double next_resistance = pivot.GetNextResistanceLevel(current_price);
        double next_support = pivot.GetNextSupportLevel(current_price);
        
        Print("Current price: ", current_price);
        Print("Next resistance: ", next_resistance);
        Print("Next support: ", next_support);
    }
    else
    {
        Print("✗ Failed to initialize Pivot Points");
    }
    
    delete pivot;
}

//+------------------------------------------------------------------+
//| Test MACD Signal                                              |
//+------------------------------------------------------------------+
void TestMACDSignal()
{
    Print("--- Testing MACD Signal ---");
    
    CMACDSignal* macd = new CMACDSignal(_Symbol, TestTimeframe, 12, 26, 1);
    
    if(macd.Initialize())
    {
        Print("✓ MACD Signal initialized successfully");
        
        if(macd.UpdateSignals())
        {
            Print(macd.GetSignalDescription());
            Print("MACD Bullish: ", macd.IsBullishSignal());
            Print("MACD Bearish: ", macd.IsBearishSignal());
        }
        else
        {
            Print("✗ Failed to update MACD signals");
        }
    }
    else
    {
        Print("✗ Failed to initialize MACD Signal");
    }
    
    delete macd;
}

//+------------------------------------------------------------------+
//| Test Stochastic Signal                                        |
//+------------------------------------------------------------------+
void TestStochasticSignal()
{
    Print("--- Testing Stochastic Signal ---");
    
    CStochasticSignal* stoch = new CStochasticSignal(_Symbol, TestTimeframe, 14, 3, 3);
    
    if(stoch.Initialize())
    {
        Print("✓ Stochastic Signal initialized successfully");
        
        if(stoch.UpdateSignals())
        {
            Print(stoch.GetSignalDescription());
            Print("Stoch Bullish: ", stoch.IsBullishSignal());
            Print("Stoch Bearish: ", stoch.IsBearishSignal());
        }
        else
        {
            Print("✗ Failed to update Stochastic signals");
        }
    }
    else
    {
        Print("✗ Failed to initialize Stochastic Signal");
    }
    
    delete stoch;
}

//+------------------------------------------------------------------+
//| Test Moving Average Signal                                    |
//+------------------------------------------------------------------+
void TestMovingAverageSignal()
{
    Print("--- Testing Moving Average Signal ---");
    
    CMovingAverageSignal* ma = new CMovingAverageSignal(_Symbol, TestTimeframe, 4, 6);
    
    if(ma.Initialize())
    {
        Print("✓ Moving Average Signal initialized successfully");
        
        if(ma.UpdateSignals())
        {
            Print(ma.GetSignalDescription());
            Print("MA Bullish: ", ma.IsBullishSignal());
            Print("MA Bearish: ", ma.IsBearishSignal());
        }
        else
        {
            Print("✗ Failed to update MA signals");
        }
    }
    else
    {
        Print("✗ Failed to initialize Moving Average Signal");
    }
    
    delete ma;
}

//+------------------------------------------------------------------+
//| Test Swing Point Detector                                     |
//+------------------------------------------------------------------+
void TestSwingPointDetector()
{
    Print("--- Testing Swing Point Detector ---");
    
    CSwingPointDetector* swing = new CSwingPointDetector(_Symbol, TestTimeframe, 5, 50);
    
    if(swing.Initialize())
    {
        Print("✓ Swing Point Detector initialized successfully");
        Print(swing.GetSwingPointsInfo());
        
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double bull_sl = swing.GetBullishStopLoss(current_price, 7);
        double bear_sl = swing.GetBearishStopLoss(current_price, 7);
        
        Print("Bullish SL: ", bull_sl);
        Print("Bearish SL: ", bear_sl);
    }
    else
    {
        Print("✗ Failed to initialize Swing Point Detector");
    }
    
    delete swing;
}

//+------------------------------------------------------------------+
//| Test Complete Strategy                                        |
//+------------------------------------------------------------------+
void TestCompleteStrategy()
{
    Print("--- Testing Complete Admiral Strategy ---");
    
    CAdmiralStrategy* strategy = new CAdmiralStrategy(_Symbol, TestTimeframe, TestPivotTimeframe);
    
    if(strategy.Initialize())
    {
        Print("✓ Admiral Strategy initialized successfully");
        Print(strategy.GetStrategyStatus());
        
        // Test signal detection
        SAdmiralSignal signal = strategy.CheckEntrySignal();
        
        if(signal.is_valid)
        {
            Print("=== SIGNAL DETECTED ===");
            Print("Direction: ", signal.is_long ? "LONG" : "SHORT");
            Print("Entry: ", signal.entry_price);
            Print("Stop Loss: ", signal.stop_loss);
            Print("Take Profit: ", signal.take_profit);
            Print("Strength: ", signal.signal_strength);
            Print("Description: ", signal.signal_description);
        }
        else
        {
            Print("No valid signal at current time");
        }
        
        if(TestVerbose)
        {
            Print("=== DETAILED SIGNAL INFO ===");
            Print(strategy.GetDetailedSignalInfo());
        }
    }
    else
    {
        Print("✗ Failed to initialize Admiral Strategy");
    }
    
    delete strategy;
}

//+------------------------------------------------------------------+
//| Performance test function                                      |
//+------------------------------------------------------------------+
void TestPerformance()
{
    Print("--- Performance Test ---");
    
    uint start_time = GetTickCount();
    
    CAdmiralStrategy* strategy = new CAdmiralStrategy(_Symbol, TestTimeframe, TestPivotTimeframe);
    
    if(strategy.Initialize())
    {
        // Test multiple signal checks
        for(int i = 0; i < 100; i++)
        {
            SAdmiralSignal signal = strategy.CheckEntrySignal();
            // Just checking, not using the signal
        }
        
        uint end_time = GetTickCount();
        uint elapsed = end_time - start_time;
        
        Print("Performance test completed");
        Print("100 signal checks took: ", elapsed, " ms");
        Print("Average per check: ", (double)elapsed / 100.0, " ms");
    }
    
    delete strategy;
}
