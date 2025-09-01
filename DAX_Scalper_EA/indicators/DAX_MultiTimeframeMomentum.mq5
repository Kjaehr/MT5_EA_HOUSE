//+------------------------------------------------------------------+
//|                                  DAX_MultiTimeframeMomentum.mq5 |
//|                                  Copyright 2024, Tobias Kjaehr   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Tobias Kjaehr"
#property link      ""
#property version   "1.00"
#property description "DAX Multi-Timeframe Momentum Oscillator - Kombinerer momentum fra multiple timeframes"

//--- Indicator properties
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   7

//--- Plot properties
#property indicator_label1  "Weighted Momentum"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  3

#property indicator_label2  "M1 RSI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightGray
#property indicator_width2  1
#property indicator_style2  STYLE_DOT

#property indicator_label3  "M5 RSI"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_width3  1

#property indicator_label4  "M15 RSI"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_width4  2

#property indicator_label5  "H1 RSI"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrRed
#property indicator_width5  2

#property indicator_label6  "Bullish Confluence"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrLime
#property indicator_width6  3

#property indicator_label7  "Bearish Confluence"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrRed
#property indicator_width7  3

//--- Input parameters
input int      MTF_RSI_Period = 14;           // RSI periode for alle timeframes
input double   TF_Weight_M1 = 0.1;            // Vægt for M1 momentum
input double   TF_Weight_M5 = 0.3;            // Vægt for M5 momentum
input double   TF_Weight_M15 = 0.4;           // Vægt for M15 momentum
input double   TF_Weight_H1 = 0.2;            // Vægt for H1 momentum
input double   ConfluenceThreshold = 0.7;     // Minimum confluence for signal
input bool     ShowDivergences = true;        // Vis divergence alerts
input double   OverboughtLevel = 70.0;        // Overbought niveau
input double   OversoldLevel = 30.0;          // Oversold niveau
input bool     ShowDebugInfo = true;          // Vis debug information

//--- Indicator buffers
double WeightedMomentumBuffer[];
double M1_RSI_Buffer[];
double M5_RSI_Buffer[];
double M15_RSI_Buffer[];
double H1_RSI_Buffer[];
double BullishConfluenceBuffer[];
double BearishConfluenceBuffer[];
double AuxiliaryBuffer1[];
double AuxiliaryBuffer2[];
double AuxiliaryBuffer3[];

//--- Global variables
int m1_rsi_handle = INVALID_HANDLE;
int m5_rsi_handle = INVALID_HANDLE;
int m15_rsi_handle = INVALID_HANDLE;
int h1_rsi_handle = INVALID_HANDLE;

//--- Timeframe data structure
struct STimeframeData {
    double rsi_current;
    double rsi_previous;
    double momentum_score;
    bool is_trending;
    bool is_bullish;
    bool is_bearish;
};

STimeframeData g_tf_data[4]; // M1, M5, M15, H1

//--- Momentum regime enumeration
enum ENUM_MOMENTUM_REGIME {
    MOMENTUM_NEUTRAL = 0,
    MOMENTUM_BULLISH = 1,
    MOMENTUM_BEARISH = -1,
    MOMENTUM_DIVERGENT = 2
};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Indicator buffers mapping
    SetIndexBuffer(0, WeightedMomentumBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, M1_RSI_Buffer, INDICATOR_DATA);
    SetIndexBuffer(2, M5_RSI_Buffer, INDICATOR_DATA);
    SetIndexBuffer(3, M15_RSI_Buffer, INDICATOR_DATA);
    SetIndexBuffer(4, H1_RSI_Buffer, INDICATOR_DATA);
    SetIndexBuffer(5, BullishConfluenceBuffer, INDICATOR_DATA);
    SetIndexBuffer(6, BearishConfluenceBuffer, INDICATOR_DATA);
    SetIndexBuffer(7, AuxiliaryBuffer1, INDICATOR_CALCULATIONS);
    SetIndexBuffer(8, AuxiliaryBuffer2, INDICATOR_CALCULATIONS);
    SetIndexBuffer(9, AuxiliaryBuffer3, INDICATOR_CALCULATIONS);
    
    //--- Create RSI handles for different timeframes
    m1_rsi_handle = iRSI(_Symbol, PERIOD_M1, MTF_RSI_Period, PRICE_CLOSE);
    m5_rsi_handle = iRSI(_Symbol, PERIOD_M5, MTF_RSI_Period, PRICE_CLOSE);
    m15_rsi_handle = iRSI(_Symbol, PERIOD_M15, MTF_RSI_Period, PRICE_CLOSE);
    h1_rsi_handle = iRSI(_Symbol, PERIOD_H1, MTF_RSI_Period, PRICE_CLOSE);
    
    //--- Check handles
    if(m1_rsi_handle == INVALID_HANDLE || m5_rsi_handle == INVALID_HANDLE ||
       m15_rsi_handle == INVALID_HANDLE || h1_rsi_handle == INVALID_HANDLE) {
        Print("Failed to create RSI handles for multi-timeframe analysis");
        return(INIT_FAILED);
    }
    
    //--- Set indicator properties
    IndicatorSetString(INDICATOR_SHORTNAME, "DAX Multi-TF Momentum");
    IndicatorSetInteger(INDICATOR_DIGITS, 2);
    
    //--- Initialize buffers with proper values
    ArrayInitialize(WeightedMomentumBuffer, 50.0);
    ArrayInitialize(M1_RSI_Buffer, 50.0);
    ArrayInitialize(M5_RSI_Buffer, 50.0);
    ArrayInitialize(M15_RSI_Buffer, 50.0);
    ArrayInitialize(H1_RSI_Buffer, 50.0);
    ArrayInitialize(BullishConfluenceBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishConfluenceBuffer, EMPTY_VALUE);

    //--- Set arrays as series (most recent data at index 0)
    ArraySetAsSeries(WeightedMomentumBuffer, true);
    ArraySetAsSeries(M1_RSI_Buffer, true);
    ArraySetAsSeries(M5_RSI_Buffer, true);
    ArraySetAsSeries(M15_RSI_Buffer, true);
    ArraySetAsSeries(H1_RSI_Buffer, true);
    ArraySetAsSeries(BullishConfluenceBuffer, true);
    ArraySetAsSeries(BearishConfluenceBuffer, true);
    
    //--- Set empty values
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    
    //--- Set arrow codes for confluence signals
    PlotIndexSetInteger(5, PLOT_ARROW, 233);
    PlotIndexSetInteger(6, PLOT_ARROW, 234);
    
    //--- Add horizontal lines for reference
    IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, OverboughtLevel);
    IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, 50.0);
    IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, OversoldLevel);
    IndicatorSetInteger(INDICATOR_LEVELS, 3);
    
    Print("DAX Multi-Timeframe Momentum Oscillator initialized successfully");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Release indicator handles
    if(m1_rsi_handle != INVALID_HANDLE) IndicatorRelease(m1_rsi_handle);
    if(m5_rsi_handle != INVALID_HANDLE) IndicatorRelease(m5_rsi_handle);
    if(m15_rsi_handle != INVALID_HANDLE) IndicatorRelease(m15_rsi_handle);
    if(h1_rsi_handle != INVALID_HANDLE) IndicatorRelease(h1_rsi_handle);
    
    Print("DAX Multi-Timeframe Momentum Oscillator deinitialized");
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
    if(rates_total < MTF_RSI_Period + 10)
        return(0);

    //--- Wait for essential timeframe data to be ready
    if(!IsMultiTimeframeDataReady()) {
        static datetime last_wait_message = 0;
        static int wait_count = 0;

        // Only show message for first 3 attempts and then every 20th attempt
        if(ShowDebugInfo && (wait_count < 3 || wait_count % 20 == 0) &&
           (prev_calculated == 0 || TimeCurrent() - last_wait_message > 60)) {
            Print("Multi-timeframe data not ready yet, waiting... (attempt ", wait_count+1, ")");
            last_wait_message = TimeCurrent();
        }
        wait_count++;

        // Don't set timer too frequently - causes performance issues
        static datetime last_timer_set = 0;
        if(TimeCurrent() - last_timer_set > 5) {
            EventSetTimer(5); // Retry in 5 seconds instead of 3
            last_timer_set = TimeCurrent();
        }
        return(prev_calculated);
    }

    //--- Determine calculation start
    int start = prev_calculated;
    if(start == 0) {
        start = MTF_RSI_Period + 10;
    }

    //--- Calculate from the last few bars to ensure fresh data, but limit recalculation
    if(start > 0) {
        start = MathMax(start - 2, MTF_RSI_Period + 10);
    }

    //--- Limit the number of bars to process in one go to avoid timeout
    int bars_to_process = rates_total - start;
    if(bars_to_process > 1000) {
        start = rates_total - 1000;
        bars_to_process = 1000;
    }

    //--- Initialize buffers on first run
    if(prev_calculated == 0) {
        ArrayInitialize(WeightedMomentumBuffer, EMPTY_VALUE);
        ArrayInitialize(M1_RSI_Buffer, EMPTY_VALUE);
        ArrayInitialize(M5_RSI_Buffer, EMPTY_VALUE);
        ArrayInitialize(M15_RSI_Buffer, EMPTY_VALUE);
        ArrayInitialize(H1_RSI_Buffer, EMPTY_VALUE);
        ArrayInitialize(BullishConfluenceBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishConfluenceBuffer, EMPTY_VALUE);
    }

    //--- Main calculation loop - process new bars
    int processed_bars = 0;
    for(int i = MathMax(prev_calculated, start); i < rates_total; i++) {
        //--- Get buffer index for series arrays (most recent = 0)
        int buffer_index = rates_total - 1 - i;

        //--- Get RSI data from all timeframes for this specific bar
        if(!GetMultiTimeframeRSI(i)) {
            //--- Use previous bar values as fallback if available
            if(buffer_index < rates_total - 1) {
                WeightedMomentumBuffer[buffer_index] = WeightedMomentumBuffer[buffer_index + 1];
                M1_RSI_Buffer[buffer_index] = M1_RSI_Buffer[buffer_index + 1];
                M5_RSI_Buffer[buffer_index] = M5_RSI_Buffer[buffer_index + 1];
                M15_RSI_Buffer[buffer_index] = M15_RSI_Buffer[buffer_index + 1];
                H1_RSI_Buffer[buffer_index] = H1_RSI_Buffer[buffer_index + 1];
            } else {
                //--- Set neutral values if no previous data available
                WeightedMomentumBuffer[buffer_index] = 50.0;
                M1_RSI_Buffer[buffer_index] = 50.0;
                M5_RSI_Buffer[buffer_index] = 50.0;
                M15_RSI_Buffer[buffer_index] = 50.0;
                H1_RSI_Buffer[buffer_index] = 50.0;
            }
            BullishConfluenceBuffer[buffer_index] = EMPTY_VALUE;
            BearishConfluenceBuffer[buffer_index] = EMPTY_VALUE;
            continue;
        }

        processed_bars++;

        //--- Calculate individual timeframe momentum scores
        CalculateTimeframeMomentum();

        //--- Calculate weighted momentum
        double weighted_momentum = CalculateWeightedMomentum();

        //--- Store values in buffers
        WeightedMomentumBuffer[buffer_index] = weighted_momentum;
        M1_RSI_Buffer[buffer_index] = g_tf_data[0].rsi_current;
        M5_RSI_Buffer[buffer_index] = g_tf_data[1].rsi_current;
        M15_RSI_Buffer[buffer_index] = g_tf_data[2].rsi_current;
        H1_RSI_Buffer[buffer_index] = g_tf_data[3].rsi_current;

        //--- Detect confluence zones and update signals
        ENUM_MOMENTUM_REGIME regime = DetectMomentumRegime();
        UpdateConfluenceSignals(buffer_index, regime);

        //--- Debug output for recent bars only
        if(ShowDebugInfo && i >= rates_total - 3) {
            Print("Bar ", i, " (idx ", buffer_index, "): Weighted=", DoubleToString(weighted_momentum, 2),
                  " M1=", DoubleToString(g_tf_data[0].rsi_current, 1),
                  " M5=", DoubleToString(g_tf_data[1].rsi_current, 1),
                  " M15=", DoubleToString(g_tf_data[2].rsi_current, 1),
                  " H1=", DoubleToString(g_tf_data[3].rsi_current, 1),
                  " Regime=", EnumToString(regime));
        }
    }

    //--- Performance tracking
    static datetime last_performance_log = 0;
    if(ShowDebugInfo && processed_bars > 0 && TimeCurrent() - last_performance_log > 60) {
        Print("MTF Momentum: Processed ", processed_bars, " bars, Total bars: ", rates_total,
              " Prev calculated: ", prev_calculated);
        last_performance_log = TimeCurrent();
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
    //--- Check if data is ready and trigger recalculation if needed
    static int timer_attempts = 0;
    timer_attempts++;

    if(IsMultiTimeframeDataReady()) {
        EventKillTimer();
        timer_attempts = 0;
        // Force indicator recalculation by invalidating previous calculation
        ChartRedraw();
        if(ShowDebugInfo) Print("Multi-timeframe data ready, recalculating indicator");
    } else if(timer_attempts > 20) {
        // Stop trying after 20 attempts (60 seconds)
        EventKillTimer();
        timer_attempts = 0;
        if(ShowDebugInfo) Print("Timeout waiting for multi-timeframe data, stopping timer");
    }
}

//+------------------------------------------------------------------+
//| Check if all multi-timeframe data is ready                      |
//+------------------------------------------------------------------+
bool IsMultiTimeframeDataReady()
{
    //--- Check M1 data (required)
    int m1_bars = BarsCalculated(m1_rsi_handle);
    if(m1_bars < 0) {
        // Handle invalid, reinitialize only once per session
        static bool m1_reinit_attempted = false;
        if(!m1_reinit_attempted) {
            if(ShowDebugInfo) Print("M1 RSI handle invalid, reinitializing...");
            if(m1_rsi_handle != INVALID_HANDLE) IndicatorRelease(m1_rsi_handle);
            m1_rsi_handle = iRSI(_Symbol, PERIOD_M1, MTF_RSI_Period, PRICE_CLOSE);
            m1_reinit_attempted = true;
        }
        return false;
    }
    if(m1_bars < MTF_RSI_Period + 2) {
        return false; // More lenient requirement
    }

    //--- Check M5 data (required)
    int m5_bars = BarsCalculated(m5_rsi_handle);
    if(m5_bars < 0) {
        // Handle invalid, reinitialize only once per session
        static bool m5_reinit_attempted = false;
        if(!m5_reinit_attempted) {
            if(ShowDebugInfo) Print("M5 RSI handle invalid, reinitializing...");
            if(m5_rsi_handle != INVALID_HANDLE) IndicatorRelease(m5_rsi_handle);
            m5_rsi_handle = iRSI(_Symbol, PERIOD_M5, MTF_RSI_Period, PRICE_CLOSE);
            m5_reinit_attempted = true;
        }
        return false;
    }
    if(m5_bars < MTF_RSI_Period + 2) {
        return false; // More lenient requirement
    }

    //--- Check M15 data (required)
    int m15_bars = BarsCalculated(m15_rsi_handle);
    if(m15_bars < 0) {
        // Handle invalid, reinitialize only once per session
        static bool m15_reinit_attempted = false;
        if(!m15_reinit_attempted) {
            if(ShowDebugInfo) Print("M15 RSI handle invalid, reinitializing...");
            if(m15_rsi_handle != INVALID_HANDLE) IndicatorRelease(m15_rsi_handle);
            m15_rsi_handle = iRSI(_Symbol, PERIOD_M15, MTF_RSI_Period, PRICE_CLOSE);
            m15_reinit_attempted = true;
        }
        return false;
    }
    if(m15_bars < MTF_RSI_Period + 2) {
        return false; // More lenient requirement
    }

    //--- Check H1 data (optional - can work without it)
    int h1_bars = BarsCalculated(h1_rsi_handle);
    if(h1_bars < 0) {
        // Handle invalid, reinitialize only once per session
        static bool h1_reinit_attempted = false;
        if(!h1_reinit_attempted) {
            if(ShowDebugInfo) Print("H1 RSI handle invalid, reinitializing...");
            if(h1_rsi_handle != INVALID_HANDLE) IndicatorRelease(h1_rsi_handle);
            h1_rsi_handle = iRSI(_Symbol, PERIOD_H1, MTF_RSI_Period, PRICE_CLOSE);
            h1_reinit_attempted = true;
        }
        // Don't return false - H1 is optional
    }

    return true;
}

//+------------------------------------------------------------------+
//| Get RSI data from all timeframes for specific bar              |
//+------------------------------------------------------------------+
bool GetMultiTimeframeRSI(int bar_index)
{
    double m1_rsi[2], m5_rsi[2], m15_rsi[2], h1_rsi[2];

    //--- For M1 timeframe, use direct bar index since we're on M1 chart
    int m1_copied = CopyBuffer(m1_rsi_handle, 0, bar_index, 2, m1_rsi);

    //--- For higher timeframes, we need to find the corresponding bar
    //--- Use the time-based approach recommended in MQL5 guide
    datetime bar_time = iTime(_Symbol, PERIOD_M1, bar_index);
    if(bar_time == 0) {
        if(ShowDebugInfo) Print("Cannot get bar time for index ", bar_index);
        return false;
    }

    //--- Find corresponding bars using iBarShift with exact=false for nearest bar
    int m5_shift = iBarShift(_Symbol, PERIOD_M5, bar_time, false);
    int m15_shift = iBarShift(_Symbol, PERIOD_M15, bar_time, false);
    int h1_shift = iBarShift(_Symbol, PERIOD_H1, bar_time, false);

    //--- Copy RSI data from different timeframes
    int m5_copied = (m5_shift >= 0) ? CopyBuffer(m5_rsi_handle, 0, m5_shift, 2, m5_rsi) : -1;
    int m15_copied = (m15_shift >= 0) ? CopyBuffer(m15_rsi_handle, 0, m15_shift, 2, m15_rsi) : -1;
    int h1_copied = (h1_shift >= 0) ? CopyBuffer(h1_rsi_handle, 0, h1_shift, 2, h1_rsi) : -1;

    //--- Check if we have minimum required data for each timeframe
    bool m1_ok = (m1_copied >= 1);
    bool m5_ok = (m5_copied >= 1);
    bool m15_ok = (m15_copied >= 1);
    bool h1_ok = (h1_copied >= 1);

    //--- We need at least M1, M5, and M15 data to work
    if(!m1_ok || !m5_ok || !m15_ok) {
        // For the current bar (bar_index 0), try alternative approach
        if(bar_index == 0) {
            // Try to get data from shift 1 (previous bar) as fallback
            m1_copied = CopyBuffer(m1_rsi_handle, 0, 1, 1, m1_rsi);
            m5_copied = CopyBuffer(m5_rsi_handle, 0, 1, 1, m5_rsi);
            m15_copied = CopyBuffer(m15_rsi_handle, 0, 1, 1, m15_rsi);

            if(m1_copied >= 1 && m5_copied >= 1 && m15_copied >= 1) {
                // Use previous bar data for current bar as fallback
                m1_ok = m5_ok = m15_ok = true;
            }
        }

        // If still no data, return false silently to avoid spam
        if(!m1_ok || !m5_ok || !m15_ok) {
            static datetime last_error_time = 0;
            static int last_error_bar = -1;
            static int error_count = 0;

            // Only log first 5 errors and then every 100th error to reduce spam
            if(ShowDebugInfo && (error_count < 5 || error_count % 100 == 0) &&
               (bar_index != last_error_bar || TimeCurrent() - last_error_time > 300)) {
                Print("Insufficient RSI data for bar ", bar_index, " (time: ", TimeToString(bar_time),
                      ") - M1:", m1_copied, " M5:", m5_copied, " M15:", m15_copied, " H1:", h1_copied,
                      " Shifts: M5=", m5_shift, " M15=", m15_shift, " H1=", h1_shift, " (Error #", error_count+1, ")");
                last_error_time = TimeCurrent();
                last_error_bar = bar_index;
            }
            error_count++;
            return false;
        }
    }

    //--- Store data in global structure
    //--- CopyBuffer returns data in chronological order: [0] = requested bar, [1] = previous bar
    g_tf_data[0].rsi_current = m1_rsi[0];
    g_tf_data[0].rsi_previous = (m1_copied > 1) ? m1_rsi[1] : m1_rsi[0];

    g_tf_data[1].rsi_current = m5_rsi[0];
    g_tf_data[1].rsi_previous = (m5_copied > 1) ? m5_rsi[1] : m5_rsi[0];

    g_tf_data[2].rsi_current = m15_rsi[0];
    g_tf_data[2].rsi_previous = (m15_copied > 1) ? m15_rsi[1] : m15_rsi[0];

    //--- Handle H1 data separately (might not always be available)
    if(h1_ok) {
        g_tf_data[3].rsi_current = h1_rsi[0];
        g_tf_data[3].rsi_previous = (h1_copied > 1) ? h1_rsi[1] : h1_rsi[0];
    } else {
        // Use M15 data as fallback for H1
        g_tf_data[3].rsi_current = g_tf_data[2].rsi_current;
        g_tf_data[3].rsi_previous = g_tf_data[2].rsi_previous;
    }

    //--- Validate RSI values are in reasonable range
    for(int tf = 0; tf < 4; tf++) {
        if(g_tf_data[tf].rsi_current < 0 || g_tf_data[tf].rsi_current > 100) {
            g_tf_data[tf].rsi_current = 50.0; // Set to neutral if invalid
        }
        if(g_tf_data[tf].rsi_previous < 0 || g_tf_data[tf].rsi_previous > 100) {
            g_tf_data[tf].rsi_previous = g_tf_data[tf].rsi_current; // Use current if previous invalid
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Calculate momentum scores for each timeframe                    |
//+------------------------------------------------------------------+
void CalculateTimeframeMomentum()
{
    for(int tf = 0; tf < 4; tf++) {
        double rsi_current = g_tf_data[tf].rsi_current;
        double rsi_previous = g_tf_data[tf].rsi_previous;

        //--- Calculate momentum score (-100 to +100)
        double momentum_change = rsi_current - rsi_previous;
        double position_score = (rsi_current - 50.0) * 2.0; // -100 to +100

        //--- Combine change and position for momentum score
        g_tf_data[tf].momentum_score = (momentum_change * 10.0 + position_score) / 2.0;
        g_tf_data[tf].momentum_score = MathMax(-100.0, MathMin(100.0, g_tf_data[tf].momentum_score));

        //--- Determine regime for this timeframe
        g_tf_data[tf].is_trending = (MathAbs(rsi_current - 50.0) > 15.0);
        g_tf_data[tf].is_bullish = (rsi_current > 50.0 && momentum_change > 0);
        g_tf_data[tf].is_bearish = (rsi_current < 50.0 && momentum_change < 0);
    }
}

//+------------------------------------------------------------------+
//| Calculate weighted momentum from all timeframes                 |
//+------------------------------------------------------------------+
double CalculateWeightedMomentum()
{
    double weighted_momentum = 0.0;
    double total_weight = TF_Weight_M1 + TF_Weight_M5 + TF_Weight_M15 + TF_Weight_H1;

    if(total_weight == 0.0) return 50.0; // Neutral if no weights

    //--- Calculate weighted average
    weighted_momentum += g_tf_data[0].momentum_score * TF_Weight_M1;  // M1
    weighted_momentum += g_tf_data[1].momentum_score * TF_Weight_M5;  // M5
    weighted_momentum += g_tf_data[2].momentum_score * TF_Weight_M15; // M15
    weighted_momentum += g_tf_data[3].momentum_score * TF_Weight_H1;  // H1

    weighted_momentum /= total_weight;

    //--- Convert back to RSI-like scale (0-100)
    return 50.0 + (weighted_momentum / 2.0);
}

//+------------------------------------------------------------------+
//| Detect momentum regime across timeframes                        |
//+------------------------------------------------------------------+
ENUM_MOMENTUM_REGIME DetectMomentumRegime()
{
    int bullish_count = 0;
    int bearish_count = 0;
    int trending_count = 0;

    double weighted_score = 0.0;
    double weights[] = {TF_Weight_M1, TF_Weight_M5, TF_Weight_M15, TF_Weight_H1};
    double total_weight = TF_Weight_M1 + TF_Weight_M5 + TF_Weight_M15 + TF_Weight_H1;

    //--- Analyze each timeframe
    for(int tf = 0; tf < 4; tf++) {
        if(g_tf_data[tf].is_trending) trending_count++;
        if(g_tf_data[tf].is_bullish) bullish_count++;
        if(g_tf_data[tf].is_bearish) bearish_count++;

        //--- Add weighted contribution
        if(g_tf_data[tf].is_bullish) {
            weighted_score += weights[tf];
        } else if(g_tf_data[tf].is_bearish) {
            weighted_score -= weights[tf];
        }
    }

    //--- Normalize weighted score
    if(total_weight > 0) {
        weighted_score /= total_weight;
    }

    //--- Determine regime based on confluence
    if(weighted_score > ConfluenceThreshold && bullish_count >= 2) {
        return MOMENTUM_BULLISH;
    } else if(weighted_score < -ConfluenceThreshold && bearish_count >= 2) {
        return MOMENTUM_BEARISH;
    } else if(bullish_count > 0 && bearish_count > 0 && trending_count >= 2) {
        return MOMENTUM_DIVERGENT;
    }

    return MOMENTUM_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Update confluence signals                                        |
//+------------------------------------------------------------------+
void UpdateConfluenceSignals(int bar_index, ENUM_MOMENTUM_REGIME regime)
{
    //--- Clear previous signals
    BullishConfluenceBuffer[bar_index] = EMPTY_VALUE;
    BearishConfluenceBuffer[bar_index] = EMPTY_VALUE;

    //--- Show confluence signals
    static ENUM_MOMENTUM_REGIME last_regime = MOMENTUM_NEUTRAL;
    static datetime last_signal_time = 0;

    switch(regime) {
        case MOMENTUM_BULLISH:
            BullishConfluenceBuffer[bar_index] = 20.0; // Bottom of indicator window
            // Only show debug for most recent bar (index 0)
            if(ShowDebugInfo && bar_index == 0 && (regime != last_regime || TimeCurrent() - last_signal_time > 60)) {
                Print("Bullish confluence detected at ", TimeToString(TimeCurrent()));
                last_signal_time = TimeCurrent();
            }
            break;

        case MOMENTUM_BEARISH:
            BearishConfluenceBuffer[bar_index] = 80.0; // Top of indicator window
            // Only show debug for most recent bar (index 0)
            if(ShowDebugInfo && bar_index == 0 && (regime != last_regime || TimeCurrent() - last_signal_time > 60)) {
                Print("Bearish confluence detected at ", TimeToString(TimeCurrent()));
                last_signal_time = TimeCurrent();
            }
            break;

        case MOMENTUM_DIVERGENT:
            // Only show debug for most recent bar (index 0)
            if(ShowDebugInfo && bar_index == 0 && (regime != last_regime || TimeCurrent() - last_signal_time > 60)) {
                Print("Momentum divergence detected at ", TimeToString(TimeCurrent()));
                last_signal_time = TimeCurrent();
            }
            break;
    }

    // Only update last_regime for most recent bar
    if(bar_index == 0) {
        last_regime = regime;
    }
}

//+------------------------------------------------------------------+
//| Detect divergences between timeframes                           |
//+------------------------------------------------------------------+
void DetectDivergences(int bar_index, const double &close[])
{
    if(bar_index < 20) return;

    //--- Look for divergences between price and momentum
    // Note: close[] array follows standard indexing (not series)
    bool price_higher_high = (close[bar_index] > close[bar_index - 10]);
    bool price_lower_low = (close[bar_index] < close[bar_index - 10]);

    // WeightedMomentumBuffer is series, so we need to convert indices
    double current_momentum = WeightedMomentumBuffer[bar_index];
    double previous_momentum = WeightedMomentumBuffer[bar_index + 10]; // +10 because series indexing

    bool momentum_lower_high = (current_momentum < previous_momentum && price_higher_high);
    bool momentum_higher_low = (current_momentum > previous_momentum && price_lower_low);

    //--- Bearish divergence: Price makes higher high, momentum makes lower high
    if(momentum_lower_high && current_momentum > 60.0) {
        if(ShowDebugInfo) {
            Print("Bearish divergence detected at ", TimeToString(TimeCurrent()),
                  " Price: ", DoubleToString(close[bar_index], _Digits),
                  " Momentum: ", DoubleToString(current_momentum, 2));
        }
    }

    //--- Bullish divergence: Price makes lower low, momentum makes higher low
    if(momentum_higher_low && current_momentum < 40.0) {
        if(ShowDebugInfo) {
            Print("Bullish divergence detected at ", TimeToString(TimeCurrent()),
                  " Price: ", DoubleToString(close[bar_index], _Digits),
                  " Momentum: ", DoubleToString(current_momentum, 2));
        }
    }
}

//+------------------------------------------------------------------+
//| Get current weighted momentum                                    |
//+------------------------------------------------------------------+
double GetCurrentWeightedMomentum()
{
    if(ArraySize(WeightedMomentumBuffer) == 0)
        return 50.0;

    // Since arrays are set as series, index 0 is the most recent value
    return WeightedMomentumBuffer[0];
}

//+------------------------------------------------------------------+
//| Get momentum for specific timeframe                             |
//+------------------------------------------------------------------+
double GetTimeframeMomentum(ENUM_TIMEFRAMES timeframe)
{
    switch(timeframe) {
        case PERIOD_M1:  return g_tf_data[0].momentum_score;
        case PERIOD_M5:  return g_tf_data[1].momentum_score;
        case PERIOD_M15: return g_tf_data[2].momentum_score;
        case PERIOD_H1:  return g_tf_data[3].momentum_score;
        default: return 0.0;
    }
}

//+------------------------------------------------------------------+
//| Check if momentum is aligned across timeframes                  |
//+------------------------------------------------------------------+
bool IsMomentumAligned(bool bullish_bias)
{
    int aligned_count = 0;
    int total_trending = 0;

    for(int tf = 0; tf < 4; tf++) {
        if(g_tf_data[tf].is_trending) {
            total_trending++;
            if(bullish_bias && g_tf_data[tf].is_bullish) aligned_count++;
            else if(!bullish_bias && g_tf_data[tf].is_bearish) aligned_count++;
        }
    }

    //--- Require at least 2 timeframes aligned
    return (aligned_count >= 2 && total_trending >= 2);
}

//+------------------------------------------------------------------+
//| Get confluence strength (0.0 to 1.0)                           |
//+------------------------------------------------------------------+
double GetConfluenceStrength()
{
    double bullish_weight = 0.0;
    double bearish_weight = 0.0;
    double weights[] = {TF_Weight_M1, TF_Weight_M5, TF_Weight_M15, TF_Weight_H1};
    double total_weight = TF_Weight_M1 + TF_Weight_M5 + TF_Weight_M15 + TF_Weight_H1;

    for(int tf = 0; tf < 4; tf++) {
        if(g_tf_data[tf].is_bullish) {
            bullish_weight += weights[tf];
        } else if(g_tf_data[tf].is_bearish) {
            bearish_weight += weights[tf];
        }
    }

    if(total_weight == 0.0) return 0.0;

    return MathMax(bullish_weight, bearish_weight) / total_weight;
}

//+------------------------------------------------------------------+
//| Check if suitable for entry based on momentum                   |
//+------------------------------------------------------------------+
bool IsSuitableForEntry(bool is_long_signal)
{
    double confluence = GetConfluenceStrength();
    bool momentum_aligned = IsMomentumAligned(is_long_signal);
    double weighted_momentum = GetCurrentWeightedMomentum();

    if(is_long_signal) {
        return (confluence > ConfluenceThreshold &&
                momentum_aligned &&
                weighted_momentum > 45.0 &&
                weighted_momentum < 75.0); // Not too overbought
    } else {
        return (confluence > ConfluenceThreshold &&
                momentum_aligned &&
                weighted_momentum < 55.0 &&
                weighted_momentum > 25.0); // Not too oversold
    }
}

//+------------------------------------------------------------------+
//| Check if should exit based on momentum divergence               |
//+------------------------------------------------------------------+
bool ShouldExitOnMomentumDivergence(bool is_long_position)
{
    ENUM_MOMENTUM_REGIME regime = DetectMomentumRegime();
    double weighted_momentum = GetCurrentWeightedMomentum();

    if(is_long_position) {
        //--- Exit long if momentum turns bearish or extremely overbought
        return (regime == MOMENTUM_BEARISH ||
                regime == MOMENTUM_DIVERGENT ||
                weighted_momentum > 80.0);
    } else {
        //--- Exit short if momentum turns bullish or extremely oversold
        return (regime == MOMENTUM_BULLISH ||
                regime == MOMENTUM_DIVERGENT ||
                weighted_momentum < 20.0);
    }
}

//+------------------------------------------------------------------+
//| Get recommended position size multiplier                        |
//+------------------------------------------------------------------+
double GetPositionSizeMultiplier()
{
    double confluence = GetConfluenceStrength();
    ENUM_MOMENTUM_REGIME regime = DetectMomentumRegime();

    //--- Base multiplier on confluence strength
    double multiplier = 0.5 + (confluence * 1.0); // 0.5 to 1.5

    //--- Adjust based on regime
    switch(regime) {
        case MOMENTUM_BULLISH:
        case MOMENTUM_BEARISH:
            multiplier *= 1.2; // Increase for strong directional momentum
            break;

        case MOMENTUM_DIVERGENT:
            multiplier *= 0.6; // Reduce for divergent signals
            break;

        case MOMENTUM_NEUTRAL:
            multiplier *= 0.8; // Slightly reduce for neutral momentum
            break;
    }

    return MathMax(0.3, MathMin(2.0, multiplier));
}

//+------------------------------------------------------------------+
//| Get multi-timeframe status string                               |
//+------------------------------------------------------------------+
string GetMultiTimeframeStatus()
{
    double weighted_momentum = GetCurrentWeightedMomentum();
    double confluence = GetConfluenceStrength();
    ENUM_MOMENTUM_REGIME regime = DetectMomentumRegime();

    string regime_str = "Neutral";
    switch(regime) {
        case MOMENTUM_BULLISH: regime_str = "Bullish"; break;
        case MOMENTUM_BEARISH: regime_str = "Bearish"; break;
        case MOMENTUM_DIVERGENT: regime_str = "Divergent"; break;
    }

    int trending_count = 0;
    for(int tf = 0; tf < 4; tf++) {
        if(g_tf_data[tf].is_trending) trending_count++;
    }

    return StringFormat("MTF: %s, Momentum:%.1f, Confluence:%.2f, Trending:%d/4",
                       regime_str, weighted_momentum, confluence, trending_count);
}
