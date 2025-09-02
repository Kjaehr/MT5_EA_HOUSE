//+------------------------------------------------------------------+
//|                                            Debug_Indicators.mq5 |
//|                                Debug script for indicators only |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"
#property script_show_inputs

//--- Input parameters
input ENUM_TIMEFRAMES TestTimeframe = PERIOD_M15;

//+------------------------------------------------------------------+
//| Script program start function                                   |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== Debug Indicators Test ===");
    
    // Test basic MT5 indicators directly
    TestMACDDirect();
    TestStochasticDirect();
    TestMADirect();
    
    Print("=== Debug Test Completed ===");
}

//+------------------------------------------------------------------+
//| Test MACD directly                                            |
//+------------------------------------------------------------------+
void TestMACDDirect()
{
    Print("--- Testing MACD Direct ---");
    
    int macd_handle = iMACD(_Symbol, TestTimeframe, 12, 26, 1, PRICE_CLOSE);
    
    if(macd_handle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create MACD handle");
        return;
    }
    
    Sleep(100); // Wait for calculation
    
    double macd_main[];
    double macd_signal[];
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    
    if(CopyBuffer(macd_handle, 0, 0, 3, macd_main) >= 3 &&
       CopyBuffer(macd_handle, 1, 0, 3, macd_signal) >= 3)
    {
        double histogram = macd_main[0] - macd_signal[0];
        Print("✓ MACD OK: Main=", macd_main[0], " Signal=", macd_signal[0], " Histogram=", histogram);
        Print("MACD Signal: ", (histogram > 0) ? "BULLISH" : "BEARISH");
    }
    else
    {
        Print("✗ Failed to get MACD data");
    }
    
    IndicatorRelease(macd_handle);
}

//+------------------------------------------------------------------+
//| Test Stochastic directly                                      |
//+------------------------------------------------------------------+
void TestStochasticDirect()
{
    Print("--- Testing Stochastic Direct ---");
    
    int stoch_handle = iStochastic(_Symbol, TestTimeframe, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
    
    if(stoch_handle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create Stochastic handle");
        return;
    }
    
    Sleep(100); // Wait for calculation
    
    double stoch_main[];
    double stoch_signal[];
    ArraySetAsSeries(stoch_main, true);
    ArraySetAsSeries(stoch_signal, true);
    
    if(CopyBuffer(stoch_handle, 0, 0, 3, stoch_main) >= 3 &&
       CopyBuffer(stoch_handle, 1, 0, 3, stoch_signal) >= 3)
    {
        Print("✓ Stochastic OK: Main=", stoch_main[0], " Signal=", stoch_signal[0]);
        Print("Stochastic Signal: ", (stoch_main[0] > 50) ? "BULLISH" : "BEARISH");
    }
    else
    {
        Print("✗ Failed to get Stochastic data");
    }
    
    IndicatorRelease(stoch_handle);
}

//+------------------------------------------------------------------+
//| Test Moving Averages directly                                 |
//+------------------------------------------------------------------+
void TestMADirect()
{
    Print("--- Testing Moving Averages Direct ---");
    
    int ema_handle = iMA(_Symbol, TestTimeframe, 4, 0, MODE_EMA, PRICE_CLOSE);
    int smma_handle = iMA(_Symbol, TestTimeframe, 6, 0, MODE_SMMA, PRICE_TYPICAL);
    
    if(ema_handle == INVALID_HANDLE || smma_handle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create MA handles");
        return;
    }
    
    Sleep(100); // Wait for calculation
    
    double ema[];
    double smma[];
    ArraySetAsSeries(ema, true);
    ArraySetAsSeries(smma, true);
    
    if(CopyBuffer(ema_handle, 0, 0, 3, ema) >= 3 &&
       CopyBuffer(smma_handle, 0, 0, 3, smma) >= 3)
    {
        Print("✓ MA OK: EMA=", ema[0], " SMMA=", smma[0]);
        Print("MA Signal: ", (ema[0] > smma[0]) ? "BULLISH" : "BEARISH");
    }
    else
    {
        Print("✗ Failed to get MA data");
    }
    
    IndicatorRelease(ema_handle);
    IndicatorRelease(smma_handle);
}

//+------------------------------------------------------------------+
//| Test current market conditions                                |
//+------------------------------------------------------------------+
void TestMarketConditions()
{
    Print("--- Current Market Conditions ---");
    
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double spread = ask - bid;
    
    Print("Current Bid: ", bid);
    Print("Current Ask: ", ask);
    Print("Spread: ", spread);
    
    // Check if market is open
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    Print("Current time: ", dt.hour, ":", dt.min);
    Print("Day of week: ", dt.day_of_week);
    
    // Check symbol info
    Print("Symbol: ", _Symbol);
    Print("Point: ", SymbolInfoDouble(_Symbol, SYMBOL_POINT));
    Print("Digits: ", SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}
