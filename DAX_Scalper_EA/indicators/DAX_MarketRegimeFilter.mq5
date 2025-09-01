//+------------------------------------------------------------------+
//|                                       DAX_MarketRegimeFilter.mq5 |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   4

//--- Plot definitions
#property indicator_label1  "Trend Strength"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  2

#property indicator_label2  "Volatility Regime"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  2

#property indicator_label3  "Market Efficiency"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrPurple
#property indicator_width3  1

#property indicator_label4  "Regime Signal"
#property indicator_type4   DRAW_HISTOGRAM
#property indicator_color4  clrGreen
#property indicator_width4  3

//--- Input parameters
input int      RegimePeriod = 20;              // Periode for regime beregning
input double   TrendThreshold = 25;            // ADX threshold for trending
input double   VolatilityMultiplier = 1.5;    // ATR multiplier for volatilitet
input int      RangingBars = 15;               // Min bars for ranging detection
input bool     ShowRegimeBackground = true;   // Farv baggrund efter regime
input color    TrendingColor = clrLightGreen;  // Farve for trending regime
input color    RangingColor = clrLightBlue;    // Farve for ranging regime
input color    VolatileColor = clrLightPink;   // Farve for volatile regime
input double   EfficiencyThreshold = 0.6;     // Threshold for market efficiency

//--- Indicator buffers
double TrendStrengthBuffer[];
double VolatilityRegimeBuffer[];
double MarketEfficiencyBuffer[];
double RegimeSignalBuffer[];
double BackgroundBuffer[];
double AuxiliaryBuffer[];

//--- Global variables
int adx_handle;
int atr_handle;

//--- Market regime enumeration
enum ENUM_MARKET_REGIME {
    REGIME_TRENDING = 1,
    REGIME_RANGING = 0,
    REGIME_VOLATILE = -1
};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Indicator buffers mapping
    SetIndexBuffer(0, TrendStrengthBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, VolatilityRegimeBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, MarketEfficiencyBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, RegimeSignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, BackgroundBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(5, AuxiliaryBuffer, INDICATOR_CALCULATIONS);
    
    //--- Create indicator handles
    adx_handle = iADX(_Symbol, _Period, RegimePeriod);
    atr_handle = iATR(_Symbol, _Period, RegimePeriod);
    
    if(adx_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE) {
        Print("Error creating indicator handles");
        return(INIT_FAILED);
    }
    
    //--- Set indicator properties
    IndicatorSetString(INDICATOR_SHORTNAME, "DAX Market Regime Filter");
    IndicatorSetInteger(INDICATOR_DIGITS, 2);
    
    //--- Set plot labels
    PlotIndexSetString(0, PLOT_LABEL, "Trend Strength (ADX)");
    PlotIndexSetString(1, PLOT_LABEL, "Volatility Regime");
    PlotIndexSetString(2, PLOT_LABEL, "Market Efficiency");
    PlotIndexSetString(3, PLOT_LABEL, "Regime Signal");
    
    //--- Set colors from inputs
    PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrBlue);
    PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrOrange);
    PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrPurple);
    PlotIndexSetInteger(3, PLOT_LINE_COLOR, clrGreen);
    
    Print("DAX Market Regime Filter initialized successfully");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if(rates_total < RegimePeriod * 2) return(0);
    
    int start = MathMax(prev_calculated - 1, RegimePeriod);
    if(start < RegimePeriod) start = RegimePeriod;
    
    //--- Check if indicators are ready
    if(BarsCalculated(adx_handle) < rates_total || BarsCalculated(atr_handle) < rates_total) {
        return(prev_calculated);
    }

    //--- Get ADX and ATR values
    double adx_values[];
    double atr_values[];
    ArraySetAsSeries(adx_values, true);
    ArraySetAsSeries(atr_values, true);

    int bars_to_copy = rates_total - prev_calculated + 1;
    if(prev_calculated == 0) bars_to_copy = rates_total;

    int adx_copied = CopyBuffer(adx_handle, 0, 0, bars_to_copy, adx_values);
    int atr_copied = CopyBuffer(atr_handle, 0, 0, bars_to_copy, atr_values);

    if(adx_copied <= 0 || atr_copied <= 0) {
        return(prev_calculated);
    }
    
    //--- Main calculation loop
    for(int i = start; i < rates_total; i++) {
        int reverse_i = rates_total - 1 - i;
        
        //--- Calculate Trend Strength (ADX)
        TrendStrengthBuffer[i] = adx_values[reverse_i];
        
        //--- Calculate Volatility Regime (ATR normalized)
        double current_atr = atr_values[reverse_i];
        double avg_atr = CalculateAverageATR(atr_values, reverse_i, RegimePeriod);
        VolatilityRegimeBuffer[i] = (avg_atr > 0) ? (current_atr / avg_atr) * 100 : 100;
        
        //--- Calculate Market Efficiency
        MarketEfficiencyBuffer[i] = CalculateMarketEfficiency(i, close, high, low);
        
        //--- Determine Market Regime
        ENUM_MARKET_REGIME regime = DetermineMarketRegime(
            TrendStrengthBuffer[i], 
            VolatilityRegimeBuffer[i], 
            MarketEfficiencyBuffer[i],
            i, high, low
        );
        
        RegimeSignalBuffer[i] = (double)regime;
        
        //--- Set background color if enabled
        if(ShowRegimeBackground) {
            SetBackgroundColor(i, regime);
        }
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate average ATR over specified period                     |
//+------------------------------------------------------------------+
double CalculateAverageATR(const double &atr_values[], int start_index, int period)
{
    double sum = 0.0;
    int count = 0;
    
    for(int i = start_index; i < start_index + period && i < ArraySize(atr_values); i++) {
        sum += atr_values[i];
        count++;
    }
    
    return (count > 0) ? sum / count : 0.0;
}

//+------------------------------------------------------------------+
//| Calculate Market Efficiency                                     |
//+------------------------------------------------------------------+
double CalculateMarketEfficiency(int current_bar, const double &close[], 
                                const double &high[], const double &low[])
{
    if(current_bar < RegimePeriod) return 0.5;
    
    //--- Calculate net price movement
    double net_movement = MathAbs(close[current_bar] - close[current_bar - RegimePeriod]);
    
    //--- Calculate total price movement (sum of ranges)
    double total_movement = 0.0;
    for(int i = current_bar - RegimePeriod + 1; i <= current_bar; i++) {
        total_movement += (high[i] - low[i]);
    }
    
    //--- Calculate efficiency ratio
    double efficiency = (total_movement > 0) ? net_movement / total_movement : 0.0;
    
    return MathMin(efficiency, 1.0); // Cap at 1.0
}

//+------------------------------------------------------------------+
//| Determine Market Regime                                         |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME DetermineMarketRegime(double trend_strength, double volatility_regime,
                                        double market_efficiency, int current_bar,
                                        const double &high[], const double &low[])
{
    //--- Check for trending market
    if(trend_strength > TrendThreshold && market_efficiency > EfficiencyThreshold) {
        return REGIME_TRENDING;
    }
    
    //--- Check for volatile market
    if(volatility_regime > VolatilityMultiplier * 100) {
        return REGIME_VOLATILE;
    }
    
    //--- Check for ranging market
    if(IsRangingMarket(current_bar, high, low)) {
        return REGIME_RANGING;
    }
    
    //--- Default to ranging if no clear regime
    return REGIME_RANGING;
}

//+------------------------------------------------------------------+
//| Check if market is in ranging mode                             |
//+------------------------------------------------------------------+
bool IsRangingMarket(int current_bar, const double &high[], const double &low[])
{
    if(current_bar < RangingBars) return false;
    
    //--- Find highest high and lowest low in the period
    double highest = high[current_bar];
    double lowest = low[current_bar];
    
    for(int i = current_bar - RangingBars + 1; i <= current_bar; i++) {
        if(high[i] > highest) highest = high[i];
        if(low[i] < lowest) lowest = low[i];
    }
    
    //--- Calculate range
    double range = highest - lowest;
    
    //--- Calculate average range for comparison
    double avg_range = 0.0;
    for(int i = current_bar - RangingBars + 1; i <= current_bar; i++) {
        avg_range += (high[i] - low[i]);
    }
    avg_range /= RangingBars;
    
    //--- Range market if total range is not much larger than average daily ranges
    return (range < avg_range * 2.0);
}

//+------------------------------------------------------------------+
//| Set background color based on regime                           |
//+------------------------------------------------------------------+
void SetBackgroundColor(int bar_index, ENUM_MARKET_REGIME regime)
{
    // Store regime info in auxiliary buffer for external access
    BackgroundBuffer[bar_index] = (double)regime;
}

//+------------------------------------------------------------------+
//| Get current market regime (for EA integration)                 |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME GetCurrentMarketRegime()
{
    if(ArraySize(RegimeSignalBuffer) > 0) {
        int last_index = ArraySize(RegimeSignalBuffer) - 1;
        return (ENUM_MARKET_REGIME)RegimeSignalBuffer[last_index];
    }
    return REGIME_RANGING;
}

//+------------------------------------------------------------------+
//| Get trend strength value (for EA integration)                  |
//+------------------------------------------------------------------+
double GetCurrentTrendStrength()
{
    if(ArraySize(TrendStrengthBuffer) > 0) {
        int last_index = ArraySize(TrendStrengthBuffer) - 1;
        return TrendStrengthBuffer[last_index];
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| Get volatility regime value (for EA integration)              |
//+------------------------------------------------------------------+
double GetCurrentVolatilityRegime()
{
    if(ArraySize(VolatilityRegimeBuffer) > 0) {
        int last_index = ArraySize(VolatilityRegimeBuffer) - 1;
        return VolatilityRegimeBuffer[last_index];
    }
    return 100.0;
}

//+------------------------------------------------------------------+
//| Get market efficiency value (for EA integration)              |
//+------------------------------------------------------------------+
double GetCurrentMarketEfficiency()
{
    if(ArraySize(MarketEfficiencyBuffer) > 0) {
        int last_index = ArraySize(MarketEfficiencyBuffer) - 1;
        return MarketEfficiencyBuffer[last_index];
    }
    return 0.5;
}

//+------------------------------------------------------------------+
//| Check if market is suitable for breakout strategy             |
//+------------------------------------------------------------------+
bool IsSuitableForBreakout()
{
    ENUM_MARKET_REGIME regime = GetCurrentMarketRegime();
    double trend_strength = GetCurrentTrendStrength();
    double efficiency = GetCurrentMarketEfficiency();

    return (regime == REGIME_TRENDING ||
            (trend_strength > TrendThreshold * 0.8 && efficiency > EfficiencyThreshold * 0.8));
}

//+------------------------------------------------------------------+
//| Check if market is suitable for mean reversion strategy       |
//+------------------------------------------------------------------+
bool IsSuitableForMeanReversion()
{
    ENUM_MARKET_REGIME regime = GetCurrentMarketRegime();
    double trend_strength = GetCurrentTrendStrength();

    return (regime == REGIME_RANGING && trend_strength < TrendThreshold * 0.7);
}

//+------------------------------------------------------------------+
//| Get recommended position size multiplier based on regime      |
//+------------------------------------------------------------------+
double GetPositionSizeMultiplier()
{
    ENUM_MARKET_REGIME regime = GetCurrentMarketRegime();
    double efficiency = GetCurrentMarketEfficiency();

    switch(regime) {
        case REGIME_TRENDING:
            return 1.0 + (efficiency * 0.5); // Up to 1.5x in highly efficient trending markets

        case REGIME_RANGING:
            return 0.8; // Reduce size in ranging markets

        case REGIME_VOLATILE:
            return 0.6; // Significantly reduce size in volatile markets

        default:
            return 1.0;
    }
}

//+------------------------------------------------------------------+
//| Get recommended stop loss multiplier based on regime          |
//+------------------------------------------------------------------+
double GetStopLossMultiplier()
{
    ENUM_MARKET_REGIME regime = GetCurrentMarketRegime();
    double volatility = GetCurrentVolatilityRegime();

    switch(regime) {
        case REGIME_TRENDING:
            return 1.0; // Normal stops in trending markets

        case REGIME_RANGING:
            return 0.8; // Tighter stops in ranging markets

        case REGIME_VOLATILE:
            return 1.0 + (volatility / 200.0); // Wider stops in volatile markets

        default:
            return 1.0;
    }
}

//+------------------------------------------------------------------+
//| Get regime description string                                  |
//+------------------------------------------------------------------+
string GetRegimeDescription()
{
    ENUM_MARKET_REGIME regime = GetCurrentMarketRegime();
    double trend_strength = GetCurrentTrendStrength();
    double volatility = GetCurrentVolatilityRegime();
    double efficiency = GetCurrentMarketEfficiency();

    string description = "";

    switch(regime) {
        case REGIME_TRENDING:
            description = "TRENDING";
            break;
        case REGIME_RANGING:
            description = "RANGING";
            break;
        case REGIME_VOLATILE:
            description = "VOLATILE";
            break;
        default:
            description = "UNKNOWN";
    }

    return StringFormat("%s (ADX:%.1f, Vol:%.1f%%, Eff:%.2f)",
                       description, trend_strength, volatility, efficiency);
}

//+------------------------------------------------------------------+
//| Check if current market conditions favor trading              |
//+------------------------------------------------------------------+
bool IsMarketTradeable()
{
    double efficiency = GetCurrentMarketEfficiency();
    double volatility = GetCurrentVolatilityRegime();

    // Avoid trading in very inefficient or extremely volatile markets
    return (efficiency > 0.3 && volatility < 300.0);
}
