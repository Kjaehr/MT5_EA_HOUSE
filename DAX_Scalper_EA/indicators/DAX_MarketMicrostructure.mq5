//+------------------------------------------------------------------+
//|                                      DAX_MarketMicrostructure.mq5 |
//|                                  Copyright 2024, Tobias Kjaehr   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Tobias Kjaehr"
#property link      ""
#property version   "1.00"
#property description "DAX Market Microstructure Indicator - Analyserer tick-by-tick data for markedsmikrostruktur mønstre"

//--- Indicator properties
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   6

//--- Plot properties
#property indicator_label1  "Tick Direction"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

#property indicator_label2  "Price Impact"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  2

#property indicator_label3  "Spread Dynamics"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_width3  1

#property indicator_label4  "Tick Velocity"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrMagenta
#property indicator_width4  1

#property indicator_label5  "Buy Pressure"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrLime
#property indicator_width5  3

#property indicator_label6  "Sell Pressure"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrRed
#property indicator_width6  3

//--- Input parameters
input int      TickAnalysisPeriod = 100;      // Antal ticks at analysere
input double   AggressiveThreshold = 0.6;     // Threshold for aggressive moves
input int      SpreadSmoothPeriod = 20;       // Smoothing for spread analysis
input bool     ShowPressureSignals = true;    // Vis pressure change alerts
input color    BuyPressureColor = clrLime;     // Farve for buying pressure
input color    SellPressureColor = clrRed;     // Farve for selling pressure
input double   PriceImpactThreshold = 2.0;    // Minimum price impact for signal
input int      VelocityPeriod = 50;            // Period for velocity calculation
input bool     ShowDebugInfo = false;         // Vis debug information

//--- Indicator buffers
double TickDirectionBuffer[];
double PriceImpactBuffer[];
double SpreadDynamicsBuffer[];
double TickVelocityBuffer[];
double BuyPressureBuffer[];
double SellPressureBuffer[];
double AuxiliaryBuffer1[];
double AuxiliaryBuffer2[];

//--- Global variables
struct STickData {
    datetime time;
    double price;
    double volume;
    int direction;  // 1 = buy, -1 = sell, 0 = neutral
    double spread;
    double impact;
};

STickData g_tick_history[];
int g_tick_count = 0;
double g_last_price = 0.0;
datetime g_last_time = 0;
double g_cumulative_buy_pressure = 0.0;
double g_cumulative_sell_pressure = 0.0;

//--- Market pressure enumeration
enum ENUM_MARKET_PRESSURE {
    PRESSURE_NEUTRAL = 0,
    PRESSURE_BUYING = 1,
    PRESSURE_SELLING = -1
};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Indicator buffers mapping
    SetIndexBuffer(0, TickDirectionBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, PriceImpactBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, SpreadDynamicsBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, TickVelocityBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, BuyPressureBuffer, INDICATOR_DATA);
    SetIndexBuffer(5, SellPressureBuffer, INDICATOR_DATA);
    SetIndexBuffer(6, AuxiliaryBuffer1, INDICATOR_CALCULATIONS);
    SetIndexBuffer(7, AuxiliaryBuffer2, INDICATOR_CALCULATIONS);
    
    //--- Set indicator properties
    IndicatorSetString(INDICATOR_SHORTNAME, "DAX Market Microstructure");
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    
    //--- Initialize tick history array
    ArrayResize(g_tick_history, TickAnalysisPeriod * 2);
    
    //--- Initialize buffers
    ArrayInitialize(TickDirectionBuffer, EMPTY_VALUE);
    ArrayInitialize(PriceImpactBuffer, EMPTY_VALUE);
    ArrayInitialize(SpreadDynamicsBuffer, EMPTY_VALUE);
    ArrayInitialize(TickVelocityBuffer, EMPTY_VALUE);
    ArrayInitialize(BuyPressureBuffer, EMPTY_VALUE);
    ArrayInitialize(SellPressureBuffer, EMPTY_VALUE);
    
    //--- Set empty values
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    
    //--- Set arrow codes for pressure signals
    PlotIndexSetInteger(4, PLOT_ARROW, 233);
    PlotIndexSetInteger(5, PLOT_ARROW, 234);
    
    Print("DAX Market Microstructure Indicator initialized successfully");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ArrayFree(g_tick_history);
    Print("DAX Market Microstructure Indicator deinitialized");
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
    //--- Check for minimum data
    if(rates_total < TickAnalysisPeriod)
        return(0);
    
    //--- Determine calculation start
    int start = prev_calculated;
    if(start == 0)
        start = TickAnalysisPeriod;
    
    //--- Main calculation loop
    for(int i = start; i < rates_total; i++) {
        //--- Process tick data
        ProcessTickData(i, time, close, tick_volume, spread);
        
        //--- Calculate tick direction analysis
        TickDirectionBuffer[i] = CalculateTickDirection(i);
        
        //--- Calculate price impact
        PriceImpactBuffer[i] = CalculatePriceImpact(i, close, tick_volume);
        
        //--- Calculate spread dynamics
        SpreadDynamicsBuffer[i] = CalculateSpreadDynamics(i, spread);
        
        //--- Calculate tick velocity
        TickVelocityBuffer[i] = CalculateTickVelocity(i, time, close);
        
        //--- Calculate market pressure and signals
        ENUM_MARKET_PRESSURE pressure = CalculateMarketPressure(i);
        UpdatePressureSignals(i, pressure, close);
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Process tick data for analysis                                  |
//+------------------------------------------------------------------+
void ProcessTickData(int bar_index, const datetime &time[], const double &close[], 
                    const long &tick_volume[], const int &spread[])
{
    //--- Store current tick data
    STickData current_tick;
    current_tick.time = time[bar_index];
    current_tick.price = close[bar_index];
    current_tick.volume = (double)tick_volume[bar_index];
    current_tick.spread = (double)spread[bar_index] * _Point;
    
    //--- Determine tick direction
    if(g_last_price > 0) {
        if(current_tick.price > g_last_price)
            current_tick.direction = 1;  // Buy tick
        else if(current_tick.price < g_last_price)
            current_tick.direction = -1; // Sell tick
        else
            current_tick.direction = 0;  // Neutral tick
    } else {
        current_tick.direction = 0;
    }
    
    //--- Calculate price impact
    current_tick.impact = MathAbs(current_tick.price - g_last_price) * current_tick.volume;
    
    //--- Add to history
    if(g_tick_count < ArraySize(g_tick_history)) {
        g_tick_history[g_tick_count] = current_tick;
        g_tick_count++;
    } else {
        //--- Shift array and add new tick
        for(int i = 0; i < ArraySize(g_tick_history) - 1; i++) {
            g_tick_history[i] = g_tick_history[i + 1];
        }
        g_tick_history[ArraySize(g_tick_history) - 1] = current_tick;
    }
    
    //--- Update last values
    g_last_price = current_tick.price;
    g_last_time = current_tick.time;
}

//+------------------------------------------------------------------+
//| Calculate tick direction analysis                                |
//+------------------------------------------------------------------+
double CalculateTickDirection(int bar_index)
{
    if(g_tick_count < TickAnalysisPeriod / 2)
        return 0.0;
    
    int buy_ticks = 0;
    int sell_ticks = 0;
    int analysis_period = MathMin(TickAnalysisPeriod, g_tick_count);
    
    //--- Count buy/sell ticks in recent history
    for(int i = g_tick_count - analysis_period; i < g_tick_count; i++) {
        if(i >= 0 && i < ArraySize(g_tick_history)) {
            if(g_tick_history[i].direction == 1)
                buy_ticks++;
            else if(g_tick_history[i].direction == -1)
                sell_ticks++;
        }
    }
    
    //--- Calculate direction ratio (-100 to +100)
    int total_directional_ticks = buy_ticks + sell_ticks;
    if(total_directional_ticks == 0)
        return 0.0;
    
    return ((double)(buy_ticks - sell_ticks) / (double)total_directional_ticks) * 100.0;
}

//+------------------------------------------------------------------+
//| Calculate price impact measurement                               |
//+------------------------------------------------------------------+
double CalculatePriceImpact(int bar_index, const double &close[], const long &tick_volume[])
{
    if(bar_index < VelocityPeriod)
        return 0.0;

    double total_impact = 0.0;
    double total_volume = 0.0;

    //--- Calculate weighted price impact over period
    for(int i = bar_index - VelocityPeriod + 1; i <= bar_index; i++) {
        if(i > 0) {
            double price_change = MathAbs(close[i] - close[i-1]);
            double volume_weight = (double)tick_volume[i];
            total_impact += price_change * volume_weight;
            total_volume += volume_weight;
        }
    }

    return (total_volume > 0) ? (total_impact / total_volume) / _Point : 0.0;
}

//+------------------------------------------------------------------+
//| Calculate spread dynamics                                        |
//+------------------------------------------------------------------+
double CalculateSpreadDynamics(int bar_index, const int &spread[])
{
    if(bar_index < SpreadSmoothPeriod)
        return 0.0;

    double spread_sum = 0.0;

    //--- Calculate smoothed spread
    for(int i = bar_index - SpreadSmoothPeriod + 1; i <= bar_index; i++) {
        spread_sum += (double)spread[i] * _Point;
    }

    double avg_spread = spread_sum / (double)SpreadSmoothPeriod;

    //--- Return spread in points for better visualization
    return avg_spread / _Point;
}

//+------------------------------------------------------------------+
//| Calculate tick velocity                                          |
//+------------------------------------------------------------------+
double CalculateTickVelocity(int bar_index, const datetime &time[], const double &close[])
{
    if(bar_index < VelocityPeriod)
        return 0.0;

    double total_price_change = 0.0;
    int time_span = 0;

    //--- Calculate price velocity over time
    for(int i = bar_index - VelocityPeriod + 1; i <= bar_index; i++) {
        if(i > 0) {
            total_price_change += MathAbs(close[i] - close[i-1]);
            time_span += (int)(time[i] - time[i-1]);
        }
    }

    //--- Return velocity as points per minute
    if(time_span > 0) {
        double velocity = (total_price_change / _Point) / ((double)time_span / 60.0);
        return velocity;
    }

    return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate market pressure                                        |
//+------------------------------------------------------------------+
ENUM_MARKET_PRESSURE CalculateMarketPressure(int bar_index)
{
    if(g_tick_count < TickAnalysisPeriod / 2)
        return PRESSURE_NEUTRAL;

    double buy_volume = 0.0;
    double sell_volume = 0.0;
    double buy_impact = 0.0;
    double sell_impact = 0.0;
    int analysis_period = MathMin(TickAnalysisPeriod, g_tick_count);

    //--- Analyze recent tick data for pressure
    for(int i = g_tick_count - analysis_period; i < g_tick_count; i++) {
        if(i >= 0 && i < ArraySize(g_tick_history)) {
            if(g_tick_history[i].direction == 1) {
                buy_volume += g_tick_history[i].volume;
                buy_impact += g_tick_history[i].impact;
            } else if(g_tick_history[i].direction == -1) {
                sell_volume += g_tick_history[i].volume;
                sell_impact += g_tick_history[i].impact;
            }
        }
    }

    //--- Calculate pressure ratio
    double total_volume = buy_volume + sell_volume;
    double total_impact = buy_impact + sell_impact;

    if(total_volume == 0 || total_impact == 0)
        return PRESSURE_NEUTRAL;

    double volume_ratio = (buy_volume - sell_volume) / total_volume;
    double impact_ratio = (buy_impact - sell_impact) / total_impact;

    //--- Combine volume and impact for pressure determination
    double pressure_score = (volume_ratio + impact_ratio) / 2.0;

    if(pressure_score > AggressiveThreshold)
        return PRESSURE_BUYING;
    else if(pressure_score < -AggressiveThreshold)
        return PRESSURE_SELLING;
    else
        return PRESSURE_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Update pressure signals                                          |
//+------------------------------------------------------------------+
void UpdatePressureSignals(int bar_index, ENUM_MARKET_PRESSURE pressure, const double &close[])
{
    //--- Clear previous signals
    BuyPressureBuffer[bar_index] = EMPTY_VALUE;
    SellPressureBuffer[bar_index] = EMPTY_VALUE;

    if(!ShowPressureSignals)
        return;

    //--- Update cumulative pressure
    switch(pressure) {
        case PRESSURE_BUYING:
            g_cumulative_buy_pressure += 1.0;
            g_cumulative_sell_pressure = MathMax(0, g_cumulative_sell_pressure - 0.5);
            break;

        case PRESSURE_SELLING:
            g_cumulative_sell_pressure += 1.0;
            g_cumulative_buy_pressure = MathMax(0, g_cumulative_buy_pressure - 0.5);
            break;

        case PRESSURE_NEUTRAL:
            g_cumulative_buy_pressure = MathMax(0, g_cumulative_buy_pressure - 0.1);
            g_cumulative_sell_pressure = MathMax(0, g_cumulative_sell_pressure - 0.1);
            break;
    }

    //--- Show signals when pressure builds up (lowered thresholds for more signals)
    if(g_cumulative_buy_pressure > 1.5 && pressure == PRESSURE_BUYING) {
        BuyPressureBuffer[bar_index] = 50.0;  // Fixed position in indicator window

        if(ShowDebugInfo) {
            Print("Strong buying pressure detected at ", TimeToString(TimeCurrent()),
                  " Cumulative: ", g_cumulative_buy_pressure);
        }
    }

    if(g_cumulative_sell_pressure > 1.5 && pressure == PRESSURE_SELLING) {
        SellPressureBuffer[bar_index] = -50.0;  // Fixed position in indicator window

        if(ShowDebugInfo) {
            Print("Strong selling pressure detected at ", TimeToString(TimeCurrent()),
                  " Cumulative: ", g_cumulative_sell_pressure);
        }
    }

    //--- Debug: Show current pressure levels every 10 bars (enable ShowDebugInfo to see)
    static int debug_counter = 0;
    if(ShowDebugInfo && ++debug_counter % 10 == 0) {
        Print("Pressure Debug - Buy: ", DoubleToString(g_cumulative_buy_pressure, 2),
              " Sell: ", DoubleToString(g_cumulative_sell_pressure, 2),
              " Current: ", EnumToString(pressure),
              " Tick Direction: ", DoubleToString(TickDirectionBuffer[bar_index], 1));
    }
}

//+------------------------------------------------------------------+
//| Get current tick direction ratio                                 |
//+------------------------------------------------------------------+
double GetCurrentTickDirection()
{
    if(ArraySize(TickDirectionBuffer) == 0)
        return 0.0;

    return TickDirectionBuffer[ArraySize(TickDirectionBuffer) - 1];
}

//+------------------------------------------------------------------+
//| Get current price impact                                         |
//+------------------------------------------------------------------+
double GetCurrentPriceImpact()
{
    if(ArraySize(PriceImpactBuffer) == 0)
        return 0.0;

    return PriceImpactBuffer[ArraySize(PriceImpactBuffer) - 1];
}

//+------------------------------------------------------------------+
//| Get current spread dynamics                                      |
//+------------------------------------------------------------------+
double GetCurrentSpreadDynamics()
{
    if(ArraySize(SpreadDynamicsBuffer) == 0)
        return 0.0;

    return SpreadDynamicsBuffer[ArraySize(SpreadDynamicsBuffer) - 1];
}

//+------------------------------------------------------------------+
//| Get current tick velocity                                        |
//+------------------------------------------------------------------+
double GetCurrentTickVelocity()
{
    if(ArraySize(TickVelocityBuffer) == 0)
        return 0.0;

    return TickVelocityBuffer[ArraySize(TickVelocityBuffer) - 1];
}

//+------------------------------------------------------------------+
//| Check if market shows aggressive buying                          |
//+------------------------------------------------------------------+
bool IsAggressiveBuying()
{
    double tick_direction = GetCurrentTickDirection();
    double price_impact = GetCurrentPriceImpact();

    return (tick_direction > AggressiveThreshold * 100 &&
            price_impact > PriceImpactThreshold &&
            g_cumulative_buy_pressure > 2.0);
}

//+------------------------------------------------------------------+
//| Check if market shows aggressive selling                         |
//+------------------------------------------------------------------+
bool IsAggressiveSelling()
{
    double tick_direction = GetCurrentTickDirection();
    double price_impact = GetCurrentPriceImpact();

    return (tick_direction < -AggressiveThreshold * 100 &&
            price_impact > PriceImpactThreshold &&
            g_cumulative_sell_pressure > 2.0);
}

//+------------------------------------------------------------------+
//| Get market microstructure quality score                         |
//+------------------------------------------------------------------+
double GetMarketQualityScore()
{
    double tick_direction = MathAbs(GetCurrentTickDirection());
    double price_impact = GetCurrentPriceImpact();
    double tick_velocity = GetCurrentTickVelocity();
    double spread = GetCurrentSpreadDynamics();

    //--- Calculate quality based on activity and consistency
    double activity_score = MathMin(100.0, (price_impact + tick_velocity) / 2.0);
    double consistency_score = MathMin(100.0, tick_direction);
    double spread_penalty = MathMin(50.0, spread / 2.0);

    double quality = (activity_score + consistency_score - spread_penalty) / 2.0;
    return MathMax(0.0, MathMin(100.0, quality));
}

//+------------------------------------------------------------------+
//| Check if market is suitable for scalping                        |
//+------------------------------------------------------------------+
bool IsSuitableForScalping()
{
    double quality = GetMarketQualityScore();
    double spread = GetCurrentSpreadDynamics();
    double velocity = GetCurrentTickVelocity();

    return (quality > 60.0 && spread < 3.0 && velocity > 5.0);
}

//+------------------------------------------------------------------+
//| Get optimal entry timing score                                   |
//+------------------------------------------------------------------+
double GetEntryTimingScore(bool is_long_signal)
{
    double tick_direction = GetCurrentTickDirection();
    double price_impact = GetCurrentPriceImpact();
    double velocity = GetCurrentTickVelocity();

    if(is_long_signal) {
        //--- For long entries, prefer buying pressure with good momentum
        if(tick_direction > 0 && price_impact > PriceImpactThreshold) {
            return MathMin(100.0, (tick_direction + price_impact + velocity) / 3.0);
        }
    } else {
        //--- For short entries, prefer selling pressure with good momentum
        if(tick_direction < 0 && price_impact > PriceImpactThreshold) {
            return MathMin(100.0, (MathAbs(tick_direction) + price_impact + velocity) / 3.0);
        }
    }

    return 0.0;
}

//+------------------------------------------------------------------+
//| Get microstructure status string                                |
//+------------------------------------------------------------------+
string GetMicrostructureStatus()
{
    double tick_direction = GetCurrentTickDirection();
    double price_impact = GetCurrentPriceImpact();
    double velocity = GetCurrentTickVelocity();
    double spread = GetCurrentSpreadDynamics();
    double quality = GetMarketQualityScore();

    string direction_str = "Neutral";
    if(tick_direction > 30) direction_str = "Bullish";
    else if(tick_direction < -30) direction_str = "Bearish";

    string activity_str = "Low";
    if(velocity > 10) activity_str = "High";
    else if(velocity > 5) activity_str = "Medium";

    return StringFormat("Dir:%s, Impact:%.1f, Vel:%.1f, Spread:%.1f, Quality:%.0f%%, Act:%s",
                       direction_str, price_impact, velocity, spread, quality, activity_str);
}
