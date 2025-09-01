//+------------------------------------------------------------------+
//|                                            DAX_VolumeProfile.mq5 |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

//--- Plot definitions
#property indicator_label1  "POC"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrYellow
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Value Area High"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLime
#property indicator_style2  STYLE_DASH
#property indicator_width2  1

#property indicator_label3  "Value Area Low"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLime
#property indicator_style3  STYLE_DASH
#property indicator_width3  1

#property indicator_label4  "Volume Nodes High"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrAqua
#property indicator_width4  1

#property indicator_label5  "Volume Nodes Low"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrOrange
#property indicator_width5  1

//--- Input parameters
input int      ProfilePeriod = 20;        // Antal bars for profil beregning
input int      PriceLevels = 30;          // Antal pris levels i profilen (reduceret for klarhed)
input double   ValueAreaPercent = 70.0;   // Procent for value area
input bool     ShowSessionProfiles = true; // Vis session-baserede profiler
input color    POCColor = clrYellow;       // Farve for POC linje
input color    ValueAreaColor = clrLime;   // Farve for value area
input color    VolumeNodeColor = clrAqua;  // Farve for volume nodes
input double   NodeThreshold = 2.0;       // Multiplier for volume node detection (øget for færre nodes)
input bool     ShowHistogram = true;      // Vis volume histogram
input int      HistogramWidth = 100;      // Bredde af histogram i pixels
input int      UpdateFrequency = 5;       // Opdater kun hver X bars (performance)

//--- Indicator buffers
double POCBuffer[];
double ValueAreaHighBuffer[];
double ValueAreaLowBuffer[];
double VolumeNodesHighBuffer[];
double VolumeNodesLowBuffer[];

//--- Global variables
struct SVolumeLevel
{
    double price;
    double volume;
};

SVolumeLevel g_volume_levels[];
double g_poc_price = 0.0;
double g_value_area_high = 0.0;
double g_value_area_low = 0.0;
double g_total_volume = 0.0;
int g_session_start_bar = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Set indicator buffers
    SetIndexBuffer(0, POCBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, ValueAreaHighBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, ValueAreaLowBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, VolumeNodesHighBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, VolumeNodesLowBuffer, INDICATOR_DATA);
    
    //--- Set arrow codes for volume nodes
    PlotIndexSetInteger(3, PLOT_ARROW, 159); // Right arrow
    PlotIndexSetInteger(4, PLOT_ARROW, 158); // Left arrow
    
    //--- Set colors from inputs
    PlotIndexSetInteger(0, PLOT_LINE_COLOR, POCColor);
    PlotIndexSetInteger(1, PLOT_LINE_COLOR, ValueAreaColor);
    PlotIndexSetInteger(2, PLOT_LINE_COLOR, ValueAreaColor);
    PlotIndexSetInteger(3, PLOT_LINE_COLOR, VolumeNodeColor);
    PlotIndexSetInteger(4, PLOT_LINE_COLOR, VolumeNodeColor);
    
    //--- Initialize arrays
    ArrayResize(g_volume_levels, PriceLevels);
    
    //--- Set indicator name
    IndicatorSetString(INDICATOR_SHORTNAME, "DAX Volume Profile");
    
    //--- Set precision
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    
    Print("DAX Volume Profile Indicator initialized successfully");
    return INIT_SUCCEEDED;
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
    //--- Check for minimum bars
    if(rates_total < ProfilePeriod)
        return 0;
    
    //--- Determine calculation range
    int start_pos = MathMax(prev_calculated - 1, ProfilePeriod);
    
    //--- Main calculation loop
    for(int i = start_pos; i < rates_total; i++)
    {
        //--- Clear buffers
        POCBuffer[i] = EMPTY_VALUE;
        ValueAreaHighBuffer[i] = EMPTY_VALUE;
        ValueAreaLowBuffer[i] = EMPTY_VALUE;
        VolumeNodesHighBuffer[i] = EMPTY_VALUE;
        VolumeNodesLowBuffer[i] = EMPTY_VALUE;

        //--- Calculate volume profile for current position (with update frequency control)
        if(i >= ProfilePeriod && (i % UpdateFrequency == 0 || i == rates_total - 1))
        {
            CalculateVolumeProfile(i, high, low, close, tick_volume);

            //--- Set buffer values only for significant levels
            if(g_poc_price > 0)
            {
                // Show POC for recent bars only (last 50 bars)
                if(i >= rates_total - 50)
                    POCBuffer[i] = g_poc_price;
            }

            if(g_value_area_high > 0 && g_value_area_low > 0)
            {
                // Show Value Area for recent bars only
                if(i >= rates_total - 50)
                {
                    ValueAreaHighBuffer[i] = g_value_area_high;
                    ValueAreaLowBuffer[i] = g_value_area_low;
                }
            }

            //--- Mark volume nodes (reduced frequency)
            if(i % (UpdateFrequency * 2) == 0 || i == rates_total - 1)
                MarkVolumeNodes(i);
        }
        else if(i > ProfilePeriod)
        {
            //--- Copy previous values for continuity
            if(i >= rates_total - 50)
            {
                POCBuffer[i] = POCBuffer[i-1];
                ValueAreaHighBuffer[i] = ValueAreaHighBuffer[i-1];
                ValueAreaLowBuffer[i] = ValueAreaLowBuffer[i-1];
            }
        }
    }
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Calculate Volume Profile                                         |
//+------------------------------------------------------------------+
void CalculateVolumeProfile(int current_bar, 
                           const double &high[], 
                           const double &low[], 
                           const double &close[], 
                           const long &tick_volume[])
{
    //--- Initialize variables
    double min_price = DBL_MAX;
    double max_price = -DBL_MAX;
    g_total_volume = 0.0;
    
    //--- Find price range for the period
    int start_bar = current_bar - ProfilePeriod + 1;
    for(int i = start_bar; i <= current_bar; i++)
    {
        if(high[i] > max_price) max_price = high[i];
        if(low[i] < min_price) min_price = low[i];
        g_total_volume += (double)tick_volume[i];
    }
    
    //--- Calculate price step
    double price_step = (max_price - min_price) / PriceLevels;
    if(price_step <= 0) return;
    
    //--- Initialize volume levels
    for(int i = 0; i < PriceLevels; i++)
    {
        g_volume_levels[i].price = min_price + (i * price_step);
        g_volume_levels[i].volume = 0.0;
    }
    
    //--- Distribute volume across price levels
    for(int bar = start_bar; bar <= current_bar; bar++)
    {
        double bar_range = high[bar] - low[bar];
        if(bar_range <= 0) continue;
        
        //--- Find which price levels this bar covers
        int start_level = (int)((low[bar] - min_price) / price_step);
        int end_level = (int)((high[bar] - min_price) / price_step);
        
        start_level = MathMax(0, MathMin(start_level, PriceLevels - 1));
        end_level = MathMax(0, MathMin(end_level, PriceLevels - 1));
        
        //--- Distribute volume proportionally
        double volume_per_level = (double)tick_volume[bar] / (double)(end_level - start_level + 1);
        for(int level = start_level; level <= end_level; level++)
        {
            g_volume_levels[level].volume += volume_per_level;
        }
    }
    
    //--- Find POC (Point of Control)
    FindPOC();
    
    //--- Calculate Value Area
    CalculateValueArea();
}

//+------------------------------------------------------------------+
//| Find Point of Control (POC)                                     |
//+------------------------------------------------------------------+
void FindPOC()
{
    double max_volume = 0.0;
    int poc_index = 0;
    
    for(int i = 0; i < PriceLevels; i++)
    {
        if(g_volume_levels[i].volume > max_volume)
        {
            max_volume = g_volume_levels[i].volume;
            poc_index = i;
        }
    }
    
    g_poc_price = g_volume_levels[poc_index].price;
}

//+------------------------------------------------------------------+
//| Calculate Value Area (70% of volume)                            |
//+------------------------------------------------------------------+
void CalculateValueArea()
{
    double target_volume = g_total_volume * (ValueAreaPercent / 100.0);
    double accumulated_volume = 0.0;
    
    //--- Start from POC and expand up and down
    int poc_index = 0;
    for(int i = 0; i < PriceLevels; i++)
    {
        if(g_volume_levels[i].price == g_poc_price)
        {
            poc_index = i;
            break;
        }
    }
    
    //--- Add POC volume
    accumulated_volume = g_volume_levels[poc_index].volume;
    int upper_index = poc_index;
    int lower_index = poc_index;
    
    //--- Expand value area
    while(accumulated_volume < target_volume && (upper_index < PriceLevels - 1 || lower_index > 0))
    {
        double upper_volume = (upper_index < PriceLevels - 1) ? g_volume_levels[upper_index + 1].volume : 0;
        double lower_volume = (lower_index > 0) ? g_volume_levels[lower_index - 1].volume : 0;
        
        if(upper_volume >= lower_volume && upper_index < PriceLevels - 1)
        {
            upper_index++;
            accumulated_volume += g_volume_levels[upper_index].volume;
        }
        else if(lower_index > 0)
        {
            lower_index--;
            accumulated_volume += g_volume_levels[lower_index].volume;
        }
        else
        {
            break;
        }
    }
    
    g_value_area_high = g_volume_levels[upper_index].price;
    g_value_area_low = g_volume_levels[lower_index].price;
}

//+------------------------------------------------------------------+
//| Mark Volume Nodes (High volume areas)                           |
//+------------------------------------------------------------------+
void MarkVolumeNodes(int current_bar)
{
    if(g_total_volume <= 0) return;

    double avg_volume = g_total_volume / PriceLevels;
    double node_threshold = avg_volume * NodeThreshold;

    //--- Find only the most significant volume nodes
    double highest_volume_above_poc = 0;
    double highest_volume_below_poc = 0;
    double best_node_above = 0;
    double best_node_below = 0;

    for(int i = 0; i < PriceLevels; i++)
    {
        if(g_volume_levels[i].volume > node_threshold)
        {
            //--- Find best volume node above POC
            if(g_volume_levels[i].price > g_poc_price && g_volume_levels[i].volume > highest_volume_above_poc)
            {
                highest_volume_above_poc = g_volume_levels[i].volume;
                best_node_above = g_volume_levels[i].price;
            }
            //--- Find best volume node below POC
            else if(g_volume_levels[i].price < g_poc_price && g_volume_levels[i].volume > highest_volume_below_poc)
            {
                highest_volume_below_poc = g_volume_levels[i].volume;
                best_node_below = g_volume_levels[i].price;
            }
        }
    }

    //--- Mark only the best nodes
    if(best_node_above > 0)
        VolumeNodesHighBuffer[current_bar] = best_node_above;
    if(best_node_below > 0)
        VolumeNodesLowBuffer[current_bar] = best_node_below;
}


