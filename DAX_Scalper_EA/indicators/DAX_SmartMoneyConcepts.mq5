//+------------------------------------------------------------------+
//|                                      DAX_SmartMoneyConcepts.mq5 |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

//--- Plot definitions
#property indicator_label1  "BOS Bullish"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2

#property indicator_label2  "BOS Bearish"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

#property indicator_label3  "CHoCH Bullish"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrBlue
#property indicator_width3  2

#property indicator_label4  "CHoCH Bearish"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrange
#property indicator_width4  2

#property indicator_label5  "Order Block Bullish"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrBlue
#property indicator_width5  2

#property indicator_label6  "Order Block Bearish"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrRed
#property indicator_width6  2

#property indicator_label7  "FVG Bullish"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrLightBlue
#property indicator_width7  4

#property indicator_label8  "FVG Bearish"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrLightPink
#property indicator_width8  4

//--- Input parameters
input int      StructureLookback = 15;        // Bars for struktur analyse (øget for mindre støj)
input double   OrderBlockThreshold = 1.0;     // Minimum størrelse for order block (øget)
input int      FVGMinSize = 10;               // Minimum FVG størrelse i points (øget)
input bool     ShowLiquiditySweeps = false;   // Deaktiver alerts for mindre støj
input color    BullishOBColor = clrBlue;      // Farve for bullish order blocks
input color    BearishOBColor = clrRed;       // Farve for bearish order blocks
input color    FVGBullishColor = clrLightBlue; // Farve for bullish FVG
input color    FVGBearishColor = clrLightPink; // Farve for bearish FVG
input int      MaxOrderBlocks = 3;            // Reduceret antal order blocks
input int      MaxFVGs = 2;                   // Reduceret antal FVGs
input int      SignalCooldown = 5;            // Minimum bars mellem signaler

//--- Indicator buffers
double BOSBullishBuffer[];
double BOSBearishBuffer[];
double CHoCHBullishBuffer[];
double CHoCHBearishBuffer[];
double OrderBlockBullishBuffer[];
double OrderBlockBearishBuffer[];
double FVGBullishBuffer[];
double FVGBearishBuffer[];

//--- Global variables
struct SwingPoint {
    int bar;
    double price;
    bool isHigh;
};

struct OrderBlock {
    int startBar;
    int endBar;
    double highPrice;
    double lowPrice;
    bool isBullish;
    bool isValid;
};

struct FairValueGap {
    int startBar;
    int endBar;
    double upperPrice;
    double lowerPrice;
    bool isBullish;
    bool isFilled;
};

SwingPoint swingPoints[];
OrderBlock orderBlocks[];
FairValueGap fairValueGaps[];

int currentTrend = 0; // 1 = bullish, -1 = bearish, 0 = neutral
int lastBullishBOSBar = -1; // Last bar where Bullish BOS was detected
int lastBearishBOSBar = -1; // Last bar where Bearish BOS was detected
int lastCHoCHBar = -1; // Last bar where CHoCH was detected

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Indicator buffers mapping
    SetIndexBuffer(0, BOSBullishBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, BOSBearishBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, CHoCHBullishBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, CHoCHBearishBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, OrderBlockBullishBuffer, INDICATOR_DATA);
    SetIndexBuffer(5, OrderBlockBearishBuffer, INDICATOR_DATA);
    SetIndexBuffer(6, FVGBullishBuffer, INDICATOR_DATA);
    SetIndexBuffer(7, FVGBearishBuffer, INDICATOR_DATA);
    
    //--- Set arrow codes
    PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up arrow for BOS Bullish
    PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down arrow for BOS Bearish
    PlotIndexSetInteger(2, PLOT_ARROW, 159); // Circle for CHoCH Bullish
    PlotIndexSetInteger(3, PLOT_ARROW, 159); // Circle for CHoCH Bearish
    PlotIndexSetInteger(4, PLOT_ARROW, 110); // Square for Order Block Bullish
    PlotIndexSetInteger(5, PLOT_ARROW, 110); // Square for Order Block Bearish
    PlotIndexSetInteger(6, PLOT_ARROW, 117); // Large Diamond for FVG Bullish
    PlotIndexSetInteger(7, PLOT_ARROW, 117); // Large Diamond for FVG Bearish
    
    //--- Set colors from inputs
    PlotIndexSetInteger(4, PLOT_LINE_COLOR, BullishOBColor);
    PlotIndexSetInteger(5, PLOT_LINE_COLOR, BearishOBColor);
    PlotIndexSetInteger(6, PLOT_LINE_COLOR, FVGBullishColor);
    PlotIndexSetInteger(7, PLOT_LINE_COLOR, FVGBearishColor);
    
    //--- Initialize arrays
    ArrayResize(swingPoints, 0);
    ArrayResize(orderBlocks, MaxOrderBlocks);
    ArrayResize(fairValueGaps, MaxFVGs);
    
    //--- Clear order blocks and FVGs
    for(int i = 0; i < MaxOrderBlocks; i++) {
        orderBlocks[i].isValid = false;
    }
    for(int i = 0; i < MaxFVGs; i++) {
        fairValueGaps[i].isFilled = true;
    }
    
    //--- Set indicator name
    IndicatorSetString(INDICATOR_SHORTNAME, "DAX Smart Money Concepts");
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    
    Print("DAX Smart Money Concepts Indicator initialized successfully");
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
    if(rates_total < StructureLookback * 2) return(0);
    
    int start = MathMax(prev_calculated - 1, StructureLookback);
    if(start < StructureLookback) start = StructureLookback;
    
    //--- Clear buffers
    for(int i = start; i < rates_total; i++) {
        BOSBullishBuffer[i] = EMPTY_VALUE;
        BOSBearishBuffer[i] = EMPTY_VALUE;
        CHoCHBullishBuffer[i] = EMPTY_VALUE;
        CHoCHBearishBuffer[i] = EMPTY_VALUE;
        OrderBlockBullishBuffer[i] = EMPTY_VALUE;
        OrderBlockBearishBuffer[i] = EMPTY_VALUE;
        FVGBullishBuffer[i] = EMPTY_VALUE;
        FVGBearishBuffer[i] = EMPTY_VALUE;
    }
    
    //--- Main calculation loop
    for(int i = start; i < rates_total - 1; i++) {
        //--- Identify swing points
        IdentifySwingPoints(i, high, low, StructureLookback);
        
        //--- Detect Break of Structure (BOS)
        DetectBOS(i, high, low, close);
        
        //--- Detect Change of Character (CHoCH)
        DetectCHoCH(i, high, low, close);
        
        //--- Identify Order Blocks
        IdentifyOrderBlocks(i, open, high, low, close, volume);
        
        //--- Identify Fair Value Gaps
        IdentifyFairValueGaps(i, high, low);
        
        //--- Update liquidity sweeps if enabled
        if(ShowLiquiditySweeps) {
            DetectLiquiditySweeps(i, high, low);
        }
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Identify swing points (highs and lows)                          |
//+------------------------------------------------------------------+
void IdentifySwingPoints(int currentBar, const double &high[], const double &low[], int lookback)
{
    if(currentBar < lookback || currentBar >= ArraySize(high) - lookback) return;
    
    bool isSwingHigh = true;
    bool isSwingLow = true;
    
    //--- Check for swing high
    for(int i = currentBar - lookback; i <= currentBar + lookback; i++) {
        if(i == currentBar) continue;
        if(high[i] >= high[currentBar]) {
            isSwingHigh = false;
            break;
        }
    }
    
    //--- Check for swing low
    for(int i = currentBar - lookback; i <= currentBar + lookback; i++) {
        if(i == currentBar) continue;
        if(low[i] <= low[currentBar]) {
            isSwingLow = false;
            break;
        }
    }
    
    //--- Add swing points to array
    if(isSwingHigh) {
        SwingPoint newPoint;
        newPoint.bar = currentBar;
        newPoint.price = high[currentBar];
        newPoint.isHigh = true;
        AddSwingPoint(newPoint);
    }
    
    if(isSwingLow) {
        SwingPoint newPoint;
        newPoint.bar = currentBar;
        newPoint.price = low[currentBar];
        newPoint.isHigh = false;
        AddSwingPoint(newPoint);
    }
}

//+------------------------------------------------------------------+
//| Add swing point to array                                        |
//+------------------------------------------------------------------+
void AddSwingPoint(SwingPoint &point)
{
    int size = ArraySize(swingPoints);
    ArrayResize(swingPoints, size + 1);
    swingPoints[size] = point;

    //--- Keep only recent swing points (last 50)
    if(size > 50) {
        for(int i = 0; i < size - 1; i++) {
            swingPoints[i] = swingPoints[i + 1];
        }
        ArrayResize(swingPoints, 50);
    }
}

//+------------------------------------------------------------------+
//| Detect Break of Structure (BOS)                                 |
//+------------------------------------------------------------------+
void DetectBOS(int currentBar, const double &high[], const double &low[], const double &close[])
{
    if(ArraySize(swingPoints) < 2) return;

    //--- Find last significant swing high and low
    double lastSwingHigh = 0;
    double lastSwingLow = 999999.0;
    int lastHighBar = -1;
    int lastLowBar = -1;

    for(int i = ArraySize(swingPoints) - 1; i >= 0; i--) {
        if(swingPoints[i].isHigh && lastSwingHigh == 0) {
            lastSwingHigh = swingPoints[i].price;
            lastHighBar = swingPoints[i].bar;
        }
        if(!swingPoints[i].isHigh && lastSwingLow == 999999.0) {
            lastSwingLow = swingPoints[i].price;
            lastLowBar = swingPoints[i].bar;
        }
        if(lastSwingHigh > 0 && lastSwingLow < 999999.0) break;
    }

    //--- Check for bullish BOS (break above last swing high) with strict cooldown
    if(lastSwingHigh > 0 && close[currentBar] > lastSwingHigh && currentTrend != 1 &&
       (lastBullishBOSBar == -1 || currentBar - lastBullishBOSBar >= SignalCooldown) &&
       (lastBearishBOSBar == -1 || currentBar - lastBearishBOSBar >= SignalCooldown)) {
        BOSBullishBuffer[currentBar] = low[currentBar] - 10 * _Point;
        currentTrend = 1;
        lastBullishBOSBar = currentBar;
        if(ShowLiquiditySweeps) {
            Alert("DAX SMC: Bullish Break of Structure detected at ", close[currentBar]);
        }
    }
    //--- Check for bearish BOS (break below last swing low) with strict cooldown
    else if(lastSwingLow < 999999.0 && close[currentBar] < lastSwingLow && currentTrend != -1 &&
       (lastBearishBOSBar == -1 || currentBar - lastBearishBOSBar >= SignalCooldown) &&
       (lastBullishBOSBar == -1 || currentBar - lastBullishBOSBar >= SignalCooldown)) {
        BOSBearishBuffer[currentBar] = high[currentBar] + 10 * _Point;
        currentTrend = -1;
        lastBearishBOSBar = currentBar;
        if(ShowLiquiditySweeps) {
            Alert("DAX SMC: Bearish Break of Structure detected at ", close[currentBar]);
        }
    }
}

//+------------------------------------------------------------------+
//| Detect Change of Character (CHoCH)                              |
//+------------------------------------------------------------------+
void DetectCHoCH(int currentBar, const double &high[], const double &low[], const double &close[])
{
    if(ArraySize(swingPoints) < 3) return;

    //--- Look for internal structure breaks that indicate momentum shift
    for(int i = ArraySize(swingPoints) - 1; i >= 2; i--) {
        if(swingPoints[i].bar > currentBar - StructureLookback) continue;

        //--- Check for bullish CHoCH (internal high broken in downtrend) with cooldown
        if(currentTrend == -1 && swingPoints[i].isHigh &&
           (lastCHoCHBar == -1 || currentBar - lastCHoCHBar >= SignalCooldown)) {
            if(close[currentBar] > swingPoints[i].price) {
                CHoCHBullishBuffer[currentBar] = low[currentBar] - 5 * _Point;
                lastCHoCHBar = currentBar;
                break;
            }
        }

        //--- Check for bearish CHoCH (internal low broken in uptrend) with cooldown
        if(currentTrend == 1 && !swingPoints[i].isHigh &&
           (lastCHoCHBar == -1 || currentBar - lastCHoCHBar >= SignalCooldown)) {
            if(close[currentBar] < swingPoints[i].price) {
                CHoCHBearishBuffer[currentBar] = high[currentBar] + 5 * _Point;
                lastCHoCHBar = currentBar;
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Identify Order Blocks                                           |
//+------------------------------------------------------------------+
void IdentifyOrderBlocks(int currentBar, const double &open[], const double &high[],
                        const double &low[], const double &close[], const long &volume[])
{
    if(currentBar < 3) return;

    //--- Look for strong moves that create order blocks
    double currentRange = high[currentBar] - low[currentBar];
    double avgRange = 0;

    //--- Calculate average range for comparison
    for(int i = currentBar - 5; i < currentBar; i++) {
        if(i >= 0) avgRange += (high[i] - low[i]);
    }
    avgRange /= 5;

    //--- Check if current bar has significant range
    if(currentRange < avgRange * (1 + OrderBlockThreshold)) return;

    //--- Bullish order block (strong up move)
    if(close[currentBar] > open[currentBar] &&
       (close[currentBar] - open[currentBar]) > currentRange * 0.7) {

        //--- Find available slot for new order block
        for(int i = 0; i < MaxOrderBlocks; i++) {
            if(!orderBlocks[i].isValid) {
                orderBlocks[i].startBar = currentBar;
                orderBlocks[i].endBar = currentBar + 20; // Valid for 20 bars
                orderBlocks[i].highPrice = high[currentBar];
                orderBlocks[i].lowPrice = low[currentBar];
                orderBlocks[i].isBullish = true;
                orderBlocks[i].isValid = true;
                OrderBlockBullishBuffer[currentBar] = low[currentBar];
                break;
            }
        }
    }

    //--- Bearish order block (strong down move)
    if(close[currentBar] < open[currentBar] &&
       (open[currentBar] - close[currentBar]) > currentRange * 0.7) {

        //--- Find available slot for new order block
        for(int i = 0; i < MaxOrderBlocks; i++) {
            if(!orderBlocks[i].isValid) {
                orderBlocks[i].startBar = currentBar;
                orderBlocks[i].endBar = currentBar + 20; // Valid for 20 bars
                orderBlocks[i].highPrice = high[currentBar];
                orderBlocks[i].lowPrice = low[currentBar];
                orderBlocks[i].isBullish = false;
                orderBlocks[i].isValid = true;
                OrderBlockBearishBuffer[currentBar] = high[currentBar];
                break;
            }
        }
    }

    //--- Update order block validity
    for(int i = 0; i < MaxOrderBlocks; i++) {
        if(orderBlocks[i].isValid && currentBar > orderBlocks[i].endBar) {
            orderBlocks[i].isValid = false; // Expire old order blocks
        }
    }
}

//+------------------------------------------------------------------+
//| Identify Fair Value Gaps (FVG)                                  |
//+------------------------------------------------------------------+
void IdentifyFairValueGaps(int currentBar, const double &high[], const double &low[])
{
    if(currentBar < 2) return;

    //--- Check for bullish FVG (gap between bar[i-1] high and bar[i+1] low)
    if(currentBar >= 2) {
        double gap = low[currentBar] - high[currentBar - 2];
        if(gap >= FVGMinSize * _Point) {
            //--- Find available slot for new FVG
            for(int i = 0; i < MaxFVGs; i++) {
                if(fairValueGaps[i].isFilled) {
                    fairValueGaps[i].startBar = currentBar - 1;
                    fairValueGaps[i].endBar = currentBar + 50; // Valid for 50 bars
                    fairValueGaps[i].upperPrice = low[currentBar];
                    fairValueGaps[i].lowerPrice = high[currentBar - 2];
                    fairValueGaps[i].isBullish = true;
                    fairValueGaps[i].isFilled = false;
                    FVGBullishBuffer[currentBar] = fairValueGaps[i].upperPrice;
                    break;
                }
            }
        }
    }

    //--- Check for bearish FVG (gap between bar[i-1] low and bar[i+1] high)
    if(currentBar >= 2) {
        double gap = low[currentBar - 2] - high[currentBar];
        if(gap >= FVGMinSize * _Point) {
            //--- Find available slot for new FVG
            for(int i = 0; i < MaxFVGs; i++) {
                if(fairValueGaps[i].isFilled) {
                    fairValueGaps[i].startBar = currentBar - 1;
                    fairValueGaps[i].endBar = currentBar + 50; // Valid for 50 bars
                    fairValueGaps[i].upperPrice = low[currentBar - 2];
                    fairValueGaps[i].lowerPrice = high[currentBar];
                    fairValueGaps[i].isBullish = false;
                    fairValueGaps[i].isFilled = false;
                    FVGBearishBuffer[currentBar] = fairValueGaps[i].lowerPrice;
                    break;
                }
            }
        }
    }

    //--- Update FVG validity and check if filled
    for(int i = 0; i < MaxFVGs; i++) {
        if(!fairValueGaps[i].isFilled && currentBar <= fairValueGaps[i].endBar) {
            //--- Check if FVG is filled
            if(fairValueGaps[i].isBullish) {
                if(low[currentBar] <= fairValueGaps[i].lowerPrice) {
                    fairValueGaps[i].isFilled = true; // Bullish FVG filled
                }
            } else {
                if(high[currentBar] >= fairValueGaps[i].upperPrice) {
                    fairValueGaps[i].isFilled = true; // Bearish FVG filled
                }
            }
        } else if(!fairValueGaps[i].isFilled && currentBar > fairValueGaps[i].endBar) {
            fairValueGaps[i].isFilled = true; // Expire old FVGs
        }
    }
}

//+------------------------------------------------------------------+
//| Detect Liquidity Sweeps                                         |
//+------------------------------------------------------------------+
void DetectLiquiditySweeps(int currentBar, const double &high[], const double &low[])
{
    if(ArraySize(swingPoints) < 2 || currentBar < StructureLookback) return;

    //--- Look for recent swing points that might have liquidity
    for(int i = ArraySize(swingPoints) - 1; i >= 0; i--) {
        if(swingPoints[i].bar < currentBar - StructureLookback * 2) break;

        //--- Check for liquidity sweep above swing high
        if(swingPoints[i].isHigh) {
            if(high[currentBar] > swingPoints[i].price &&
               high[currentBar - 1] <= swingPoints[i].price) {
                Alert("DAX SMC: Liquidity Sweep above ", swingPoints[i].price, " - Potential reversal");
            }
        }

        //--- Check for liquidity sweep below swing low
        if(!swingPoints[i].isHigh) {
            if(low[currentBar] < swingPoints[i].price &&
               low[currentBar - 1] >= swingPoints[i].price) {
                Alert("DAX SMC: Liquidity Sweep below ", swingPoints[i].price, " - Potential reversal");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get current market structure trend                              |
//+------------------------------------------------------------------+
int GetMarketStructureTrend()
{
    return currentTrend;
}

//+------------------------------------------------------------------+
//| Check if price is in order block zone                          |
//+------------------------------------------------------------------+
bool IsInOrderBlockZone(double price, bool checkBullish = true)
{
    for(int i = 0; i < MaxOrderBlocks; i++) {
        if(orderBlocks[i].isValid && orderBlocks[i].isBullish == checkBullish) {
            if(price >= orderBlocks[i].lowPrice && price <= orderBlocks[i].highPrice) {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if there's an unfilled FVG                               |
//+------------------------------------------------------------------+
bool HasUnfilledFVG(bool checkBullish = true)
{
    for(int i = 0; i < MaxFVGs; i++) {
        if(!fairValueGaps[i].isFilled && fairValueGaps[i].isBullish == checkBullish) {
            return true;
        }
    }
    return false;
}
