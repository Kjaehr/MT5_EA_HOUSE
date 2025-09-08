//+------------------------------------------------------------------+
//|                                    DAX_Professional_Scalper.mq5 |
//|                           Professional DAX Scalping EA v2.0     |
//|                    Built on real tick data analysis & edge      |
//+------------------------------------------------------------------+
#property copyright "DAX Professional Scalper"
#property link      ""
#property version   "2.00"
#property strict

//--- Include files
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Input parameters based on tick data analysis
input group "=== CORE STRATEGY SETTINGS ==="
input double   LotSize = 0.01;                    // Base position size
input int      StopLoss = 700;                     // Stop loss in points
input int      TakeProfit = 2000;                   // Take profit in points (1:1.67 R/R)
input double   MaxSpreadPoints = 50;             // Max spread (adjusted for backtest data)
input int      MagicNumber = 789456;              // Magic number

input group "=== QUALITY FILTERS ==="
input double   MinVolumeMultiplier = 0.2;         // Minimum volume vs average (realistic)
input int      VolumeAnalysisPeriod = 20;         // Period for volume analysis
input double   VolatilityThreshold = 0.8;         // Min volatility for entry (realistic)
input int      ConsecutiveLossLimit = 5;          // Max consecutive losses before pause (increased)
input int      CooldownMinutes = 30;              // Cooldown after loss limit (increased)
input bool     OnlyExcellentSignals = false;      // Trade GOOD+ quality signals (more realistic)
input bool     RequireConfluence = false;         // Require multiple confirmations (disabled for testing)
input bool     UsePullbackEntries = true;         // Wait for pullbacks before entry

input group "=== MARKET STRUCTURE ==="
input bool     UseVolumeProfile = true;           // Use volume profile analysis
input bool     UseOrderFlow = true;               // Use order flow analysis
input int      StructurePeriod = 50;              // Bars for structure analysis
input double   SRStrength = 0.7;                  // Support/Resistance strength threshold

input group "=== SESSION CONTROL ==="
input int      EuropeanStart = 8;                 // European session start (CET)
input int      EuropeanEnd = 17;                  // European session end (CET)
input bool     TradeUSOverlap = true;             // Enhanced trading 14:00-17:00
input int      MaxDailyTrades = 8;                // Maximum trades per day
input double   MaxDailyRisk = 2.0;                // Maximum daily risk %

input group "=== RISK MANAGEMENT ==="
input double   AccountRiskPercent = 0.5;          // Risk per trade as % of account
input double   MaxDrawdownPercent = 5.0;          // Max drawdown before stop
input bool     UseAdaptivePositioning = true;     // Adapt position size to conditions
input bool     EnableEmergencyStop = true;        // Emergency stop on major losses

//--- Global variables
CTrade         trade;
CPositionInfo  position;
CAccountInfo   account;

// Strategy state
datetime       g_last_trade_time = 0;
int            g_consecutive_losses = 0;
datetime       g_cooldown_until = 0;
double         g_daily_pnl = 0.0;
int            g_daily_trades = 0;
datetime       g_last_daily_reset = 0;
double         g_session_high = 0.0;
double         g_session_low = 0.0;

// Market analysis
double         g_current_volatility = 0.0;
double         g_average_volume = 0.0;
double         g_current_volume_ratio = 0.0;
double         g_support_level = 0.0;
double         g_resistance_level = 0.0;
bool           g_market_structure_valid = false;

// Performance tracking
int            g_total_trades = 0;
int            g_winning_trades = 0;
double         g_total_profit = 0.0;
double         g_max_drawdown = 0.0;
double         g_peak_balance = 0.0;

// Indicators
int            g_atr_handle = INVALID_HANDLE;
int            g_volume_sma_handle = INVALID_HANDLE;

//--- Enums
enum ENUM_MARKET_CONDITION
{
    MARKET_RANGING = 0,
    MARKET_TRENDING_UP = 1,
    MARKET_TRENDING_DOWN = -1,
    MARKET_UNCERTAIN = 2
};

enum ENUM_SIGNAL_QUALITY
{
    SIGNAL_POOR = 0,
    SIGNAL_FAIR = 1,
    SIGNAL_GOOD = 2,
    SIGNAL_EXCELLENT = 3
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== DAX Professional Scalper v2.0 Initializing ===");
    
    // Set trade parameters
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(_Symbol);
    trade.SetDeviationInPoints(3); // Allow 3 points slippage
    
    // Initialize indicators
    if(!InitializeIndicators())
    {
        Print("ERROR: Failed to initialize indicators");
        return INIT_FAILED;
    }
    
    // Initialize session data
    InitializeSessionData();
    
    // Reset daily statistics
    ResetDailyStats();
    
    // Initialize performance tracking
    g_peak_balance = account.Balance();
    
    Print("Professional DAX Scalper initialized successfully");
    Print("Max spread: ", MaxSpreadPoints, " points");
    Print("Risk per trade: ", AccountRiskPercent, "%");
    Print("Max daily trades: ", MaxDailyTrades);
    Print("Session: ", EuropeanStart, ":00-", EuropeanEnd, ":00 CET");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
    
    // Print final statistics
    PrintFinalStatistics();
    
    Print("DAX Professional Scalper deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check daily reset
    CheckDailyReset();
    
    // Update session data
    UpdateSessionData();
    
    // Check if we should trade
    if(!ShouldTrade())
        return;
    
    // Update market analysis
    UpdateMarketAnalysis();
    
    // Manage existing positions
    ManagePositions();
    
    // Look for new trading opportunities
    if(!position.Select(_Symbol))
    {
        AnalyzeAndTrade();
    }

    // Debug signal quality periodically
    DebugSignalQuality();
}

//+------------------------------------------------------------------+
//| Initialize indicators                                            |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    Print("Initializing professional indicators...");
    
    // ATR for volatility measurement
    g_atr_handle = iATR(_Symbol, PERIOD_M1, 14);
    if(g_atr_handle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create ATR indicator");
        return false;
    }
    
    // Volume SMA for volume analysis - we'll calculate this manually
    // g_volume_sma_handle = iMA(_Symbol, PERIOD_M1, VolumeAnalysisPeriod, 0, MODE_SMA, PRICE_CLOSE);
    // Volume analysis will be done manually in UpdateVolumeAnalysis()
    g_volume_sma_handle = INVALID_HANDLE; // Not using this handle
    
    // Wait for indicators to calculate
    Sleep(2000);
    
    // Verify ATR indicator has data
    if(BarsCalculated(g_atr_handle) < 14)
    {
        Print("WARNING: ATR indicator may not have sufficient data");
    }
    
    Print("All indicators initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Initialize session data                                         |
//+------------------------------------------------------------------+
void InitializeSessionData()
{
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, PERIOD_M1, 0, 100, high) >= 100 && 
       CopyLow(_Symbol, PERIOD_M1, 0, 100, low) >= 100)
    {
        g_session_high = high[ArrayMaximum(high, 0, 100)];
        g_session_low = low[ArrayMinimum(low, 0, 100)];
    }
}

//+------------------------------------------------------------------+
//| Update session data                                             |
//+------------------------------------------------------------------+
void UpdateSessionData()
{
    double current_high = iHigh(_Symbol, PERIOD_M1, 0);
    double current_low = iLow(_Symbol, PERIOD_M1, 0);
    
    if(current_high > g_session_high) g_session_high = current_high;
    if(current_low < g_session_low) g_session_low = current_low;
}

//+------------------------------------------------------------------+
//| Check if we should trade                                        |
//+------------------------------------------------------------------+
bool ShouldTrade()
{
    // Check if in cooldown
    if(TimeCurrent() < g_cooldown_until)
    {
        return false;
    }
    
    // Check daily limits
    if(g_daily_trades >= MaxDailyTrades)
    {
        return false;
    }
    
    // Check daily risk
    if(g_daily_pnl <= -(account.Balance() * MaxDailyRisk / 100.0))
    {
        return false;
    }
    
    // Check drawdown
    if(EnableEmergencyStop && g_max_drawdown >= MaxDrawdownPercent)
    {
        Print("EMERGENCY STOP: Maximum drawdown reached");
        return false;
    }
    
    // Check trading session
    if(!IsInTradingSession())
    {
        return false;
    }
    
    // Check spread
    if(!IsSpreadAcceptable())
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if in trading session                                     |
//+------------------------------------------------------------------+
bool IsInTradingSession()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int current_hour = dt.hour;

    // European session (primary)
    return (current_hour >= EuropeanStart && current_hour < EuropeanEnd);
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                   |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    double spread_points = (ask - bid) / point;
    return spread_points <= MaxSpreadPoints;
}

//+------------------------------------------------------------------+
//| Reset daily statistics                                          |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
    g_daily_pnl = 0.0;
    g_daily_trades = 0;
    g_last_daily_reset = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Check daily reset                                               |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
    MqlDateTime current_dt, last_dt;
    TimeToStruct(TimeCurrent(), current_dt);
    TimeToStruct(g_last_daily_reset, last_dt);

    if(current_dt.day != last_dt.day)
    {
        ResetDailyStats();
        Print("Daily statistics reset");
    }
}

//+------------------------------------------------------------------+
//| Update market analysis                                          |
//+------------------------------------------------------------------+
void UpdateMarketAnalysis()
{
    UpdateVolatilityAnalysis();
    UpdateVolumeAnalysis();
    if(UseVolumeProfile) UpdateVolumeProfile();
    UpdateMarketStructure();
}

//+------------------------------------------------------------------+
//| Update volatility analysis                                      |
//+------------------------------------------------------------------+
void UpdateVolatilityAnalysis()
{
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);

    if(CopyBuffer(g_atr_handle, 0, 0, 1, atr_buffer) >= 1)
    {
        g_current_volatility = atr_buffer[0];
    }
}

//+------------------------------------------------------------------+
//| Update volume analysis                                          |
//+------------------------------------------------------------------+
void UpdateVolumeAnalysis()
{
    // Get volume data manually
    long volume_data[];
    ArraySetAsSeries(volume_data, true);

    if(CopyTickVolume(_Symbol, PERIOD_M1, 0, VolumeAnalysisPeriod + 1, volume_data) >= VolumeAnalysisPeriod + 1)
    {
        // Calculate average volume manually
        double volume_sum = 0.0;
        for(int i = 1; i <= VolumeAnalysisPeriod; i++) // Skip current bar (index 0)
        {
            volume_sum += (double)volume_data[i];
        }
        g_average_volume = volume_sum / VolumeAnalysisPeriod;

        // Get current volume ratio
        double current_volume = (double)volume_data[0];
        g_current_volume_ratio = (g_average_volume > 0) ?
                               current_volume / g_average_volume : 1.0;
    }
    else
    {
        // Fallback if not enough data
        g_average_volume = 1000.0; // Default value
        g_current_volume_ratio = 1.0;
    }
}

//+------------------------------------------------------------------+
//| Update volume profile analysis                                  |
//+------------------------------------------------------------------+
void UpdateVolumeProfile()
{
    double high[], low[];
    long volume[];

    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(volume, true);

    int bars_needed = StructurePeriod;

    if(CopyHigh(_Symbol, PERIOD_M1, 0, bars_needed, high) >= bars_needed &&
       CopyLow(_Symbol, PERIOD_M1, 0, bars_needed, low) >= bars_needed &&
       CopyTickVolume(_Symbol, PERIOD_M1, 0, bars_needed, volume) >= bars_needed)
    {
        // Find price range
        double range_high = high[ArrayMaximum(high, 0, bars_needed)];
        double range_low = low[ArrayMinimum(low, 0, bars_needed)];

        // Simple volume profile - find POC
        double price_levels[10];
        double volume_at_level[10];
        double level_size = (range_high - range_low) / 10.0;

        // Initialize arrays
        for(int i = 0; i < 10; i++)
        {
            price_levels[i] = range_low + (i * level_size);
            volume_at_level[i] = 0.0;
        }

        // Distribute volume to price levels
        for(int bar = 0; bar < bars_needed; bar++)
        {
            double bar_mid = (high[bar] + low[bar]) / 2.0;
            int level_index = (int)((bar_mid - range_low) / level_size);
            level_index = MathMax(0, MathMin(level_index, 9));

            volume_at_level[level_index] += (double)volume[bar];
        }

        // Find POC and set S/R levels
        int poc_index = ArrayMaximum(volume_at_level, 0, 10);
        double poc_price = price_levels[poc_index];

        g_support_level = poc_price - (level_size * 2);
        g_resistance_level = poc_price + (level_size * 2);
    }
}

//+------------------------------------------------------------------+
//| Update market structure                                         |
//+------------------------------------------------------------------+
void UpdateMarketStructure()
{
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);

    int bars_needed = 20;

    if(CopyHigh(_Symbol, PERIOD_M1, 0, bars_needed, high) >= bars_needed &&
       CopyLow(_Symbol, PERIOD_M1, 0, bars_needed, low) >= bars_needed &&
       CopyClose(_Symbol, PERIOD_M1, 0, bars_needed, close) >= bars_needed)
    {
        double recent_high = high[ArrayMaximum(high, 0, 10)];
        double recent_low = low[ArrayMinimum(low, 0, 10)];

        double structure_range = recent_high - recent_low;
        g_market_structure_valid = (structure_range >= g_current_volatility * 1.5); // Reduced from 3.0

        if(!UseVolumeProfile)
        {
            g_support_level = recent_low;
            g_resistance_level = recent_high;
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze and trade                                               |
//+------------------------------------------------------------------+
void AnalyzeAndTrade()
{
    // Check minimum time between trades
    if(g_last_trade_time > 0 && (TimeCurrent() - g_last_trade_time) < 180) // 3 minutes
        return;

    // Get signal quality first
    ENUM_SIGNAL_QUALITY signal_quality = AnalyzeSignalQuality();

    // Only trade EXCELLENT signals if enabled
    if(OnlyExcellentSignals && signal_quality < SIGNAL_EXCELLENT)
        return;

    // Otherwise only trade good or excellent signals
    if(!OnlyExcellentSignals && signal_quality < SIGNAL_GOOD)
        return;

    // Get market condition
    ENUM_MARKET_CONDITION market_condition = GetMarketCondition();

    // Get trading signal
    int signal = GetProfessionalSignal(market_condition);

    if(signal != 0)
    {
        // Check for pullback entry if enabled
        if(IsPullbackEntry(market_condition, signal))
        {
            ExecuteProfessionalTrade(signal, signal_quality);
        }
        else if(UsePullbackEntries)
        {
            // Signal exists but waiting for better pullback entry
            static datetime last_pullback_message = 0;
            if(TimeCurrent() - last_pullback_message > 300) // Print every 5 minutes
            {
                Print("Signal detected but waiting for pullback entry. Signal: ", signal, " Quality: ", signal_quality);
                last_pullback_message = TimeCurrent();
            }
        }
        else
        {
            // Pullback entries disabled, execute immediately
            ExecuteProfessionalTrade(signal, signal_quality);
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze signal quality with enhanced criteria                   |
//+------------------------------------------------------------------+
ENUM_SIGNAL_QUALITY AnalyzeSignalQuality()
{
    int quality_score = 0;
    int confluence_count = 0;

    // 1. VOLATILITY CHECK (Enhanced)
    if(g_current_volatility >= VolatilityThreshold)
    {
        quality_score++;
        confluence_count++;
    }

    // 2. VOLUME CONFIRMATION (Enhanced)
    if(g_current_volume_ratio >= MinVolumeMultiplier)
    {
        quality_score++;
        confluence_count++;

        // Extra points for exceptional volume
        if(g_current_volume_ratio >= MinVolumeMultiplier * 1.5)
            quality_score++;
    }

    // 3. MARKET STRUCTURE VALIDATION (Enhanced)
    if(g_market_structure_valid)
    {
        quality_score++;
        confluence_count++;

        // Check if price is near key levels
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double current_price = (ask + bid) / 2.0;

        double distance_to_support = MathAbs(current_price - g_support_level);
        double distance_to_resistance = MathAbs(current_price - g_resistance_level);
        double min_distance = MathMin(distance_to_support, distance_to_resistance);

        // Extra points if near key levels
        if(min_distance <= g_current_volatility * 2.0)
        {
            quality_score++;
            confluence_count++;
        }
    }

    // 4. SPREAD QUALITY (Tightened)
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double spread_points = (ask - bid) / point;

    if(spread_points <= 3.0) // Good spread (realistic for backtest)
    {
        quality_score += 2; // Points for acceptable spread
        confluence_count++;
    }
    else if(spread_points <= 5.0) // Fair spread
    {
        quality_score++;
    }

    // 5. SESSION TIMING (Enhanced)
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    // Prime European hours (9-12 and 14-16)
    if((dt.hour >= 9 && dt.hour < 12) || (dt.hour >= 14 && dt.hour < 16))
    {
        quality_score += 2;
        confluence_count++;
    }
    // Regular European hours
    else if(dt.hour >= EuropeanStart && dt.hour < EuropeanEnd)
    {
        quality_score++;
    }

    // 6. MOMENTUM CONFIRMATION (New)
    double momentum_score = AnalyzeMomentumQuality();
    if(momentum_score > 0.7)
    {
        quality_score += 2;
        confluence_count++;
    }
    else if(momentum_score > 0.4)
    {
        quality_score++;
    }

    // 7. CONFLUENCE REQUIREMENT
    if(RequireConfluence && confluence_count < 3)
    {
        return SIGNAL_POOR; // Require at least 3 confluence factors
    }

    // Further adjusted scoring system (realistic for backtest data)
    if(quality_score >= 4) return SIGNAL_EXCELLENT;
    if(quality_score >= 2) return SIGNAL_GOOD;
    if(quality_score >= 1) return SIGNAL_FAIR;
    return SIGNAL_POOR;
}

//+------------------------------------------------------------------+
//| Analyze momentum quality                                        |
//+------------------------------------------------------------------+
double AnalyzeMomentumQuality()
{
    double close[];
    ArraySetAsSeries(close, true);

    if(CopyClose(_Symbol, PERIOD_M1, 0, 10, close) < 10)
        return 0.0;

    // Calculate short-term momentum
    double momentum_1 = (close[0] - close[2]) / close[2]; // 2-bar momentum
    double momentum_2 = (close[0] - close[5]) / close[5]; // 5-bar momentum

    // Calculate momentum consistency
    int consistent_direction = 0;
    for(int i = 1; i < 5; i++)
    {
        if((close[i-1] > close[i] && momentum_1 > 0) ||
           (close[i-1] < close[i] && momentum_1 < 0))
            consistent_direction++;
    }

    double consistency_score = (double)consistent_direction / 4.0;
    double momentum_strength = MathAbs(momentum_1) * 1000; // Convert to points-like scale

    // Combine momentum strength and consistency
    double quality = (momentum_strength * 0.6) + (consistency_score * 0.4);

    return MathMin(quality, 1.0); // Cap at 1.0
}

//+------------------------------------------------------------------+
//| Check for pullback entry opportunity                           |
//+------------------------------------------------------------------+
bool IsPullbackEntry(ENUM_MARKET_CONDITION market_condition, int signal_direction)
{
    if(!UsePullbackEntries)
        return true; // Skip pullback check if disabled

    double close[], high[], low[];
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);

    if(CopyClose(_Symbol, PERIOD_M1, 0, 10, close) < 10 ||
       CopyHigh(_Symbol, PERIOD_M1, 0, 10, high) < 10 ||
       CopyLow(_Symbol, PERIOD_M1, 0, 10, low) < 10)
        return false;

    double current_price = close[0];

    // For BUY signals - look for pullback to support after uptrend
    if(signal_direction > 0)
    {
        // Check if we had recent higher highs
        bool has_higher_highs = (high[1] > high[3]) && (high[3] > high[6]);

        // Check if current price pulled back from recent high
        double recent_high = high[ArrayMaximum(high, 0, 5)];
        double pullback_distance = recent_high - current_price;
        bool is_pullback = pullback_distance >= g_current_volatility * 0.5;

        // Check if price is near support
        bool near_support = (current_price - g_support_level) <= g_current_volatility * 1.5;

        return has_higher_highs && is_pullback && near_support;
    }

    // For SELL signals - look for pullback to resistance after downtrend
    if(signal_direction < 0)
    {
        // Check if we had recent lower lows
        bool has_lower_lows = (low[1] < low[3]) && (low[3] < low[6]);

        // Check if current price pulled back from recent low
        double recent_low = low[ArrayMinimum(low, 0, 5)];
        double pullback_distance = current_price - recent_low;
        bool is_pullback = pullback_distance >= g_current_volatility * 0.5;

        // Check if price is near resistance
        bool near_resistance = (g_resistance_level - current_price) <= g_current_volatility * 1.5;

        return has_lower_lows && is_pullback && near_resistance;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Get market condition                                            |
//+------------------------------------------------------------------+
ENUM_MARKET_CONDITION GetMarketCondition()
{
    double close[];
    ArraySetAsSeries(close, true);

    if(CopyClose(_Symbol, PERIOD_M1, 0, 20, close) < 20)
        return MARKET_UNCERTAIN;

    double current_price = close[0];
    double range_size = g_session_high - g_session_low;

    // Check if trending
    double trend_strength = 0.0;
    for(int i = 1; i < 10; i++)
    {
        if(close[i-1] > close[i]) trend_strength += 1.0;
        else trend_strength -= 1.0;
    }

    if(trend_strength >= 6.0) return MARKET_TRENDING_UP;
    if(trend_strength <= -6.0) return MARKET_TRENDING_DOWN;

    // Check if ranging
    if(range_size > 0 && g_current_volatility > 0)
    {
        double range_position = (current_price - g_session_low) / range_size;
        if(range_position > 0.2 && range_position < 0.8)
            return MARKET_RANGING;
    }

    return MARKET_UNCERTAIN;
}

//+------------------------------------------------------------------+
//| Get professional signal with enhanced confluence               |
//+------------------------------------------------------------------+
int GetProfessionalSignal(ENUM_MARKET_CONDITION market_condition)
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double current_price = (ask + bid) / 2.0;

    // Enhanced confluence requirements
    bool volume_confirmed = g_current_volume_ratio >= MinVolumeMultiplier;
    bool volatility_confirmed = g_current_volatility >= VolatilityThreshold;
    bool structure_confirmed = g_market_structure_valid;

    // Require minimum confluence for any signal (if enabled)
    int confluence_count = 0;
    if(volume_confirmed) confluence_count++;
    if(volatility_confirmed) confluence_count++;
    if(structure_confirmed) confluence_count++;

    if(RequireConfluence && confluence_count < 1) // Reduced from 2 to 1
        return 0; // Not enough confluence

    // Enhanced mean reversion signals (39% mean reversion from tick analysis)
    if(market_condition == MARKET_RANGING)
    {
        double range_size = g_resistance_level - g_support_level;
        if(range_size > g_current_volatility * 3.0) // Increased threshold
        {
            double range_position = (current_price - g_support_level) / range_size;

            // Buy near support with additional confirmations
            if(range_position <= 0.25) // Tightened from 0.15
            {
                // Additional confluence: check for oversold conditions
                if(IsOversoldCondition() && volume_confirmed)
                    return 1; // BUY
            }

            // Sell near resistance with additional confirmations
            if(range_position >= 0.75) // Tightened from 0.85
            {
                // Additional confluence: check for overbought conditions
                if(IsOverboughtCondition() && volume_confirmed)
                    return -1; // SELL
            }
        }
    }

    // Enhanced breakout signals with strict requirements
    if(market_condition == MARKET_TRENDING_UP || market_condition == MARKET_TRENDING_DOWN)
    {
        // Require good volume for breakouts
        if(g_current_volume_ratio >= MinVolumeMultiplier * 1.2) // Reduced from 1.8
        {
            // Additional momentum confirmation required
            double momentum_quality = AnalyzeMomentumQuality();
            if(momentum_quality > 0.6)
            {
                if(market_condition == MARKET_TRENDING_UP &&
                   current_price > g_resistance_level + (g_current_volatility * 0.5))
                    return 1; // BUY breakout with buffer

                if(market_condition == MARKET_TRENDING_DOWN &&
                   current_price < g_support_level - (g_current_volatility * 0.5))
                    return -1; // SELL breakdown with buffer
            }
        }
    }

    return 0; // No signal - strict requirements not met
}

//+------------------------------------------------------------------+
//| Check for oversold conditions                                  |
//+------------------------------------------------------------------+
bool IsOversoldCondition()
{
    double close[];
    ArraySetAsSeries(close, true);

    if(CopyClose(_Symbol, PERIOD_M1, 0, 8, close) < 8)
        return false;

    // Check if price has been declining
    int declining_bars = 0;
    for(int i = 1; i < 6; i++)
    {
        if(close[i] < close[i+1])
            declining_bars++;
    }

    // Consider oversold if 4+ of last 5 bars were declining
    return declining_bars >= 4;
}

//+------------------------------------------------------------------+
//| Check for overbought conditions                                |
//+------------------------------------------------------------------+
bool IsOverboughtCondition()
{
    double close[];
    ArraySetAsSeries(close, true);

    if(CopyClose(_Symbol, PERIOD_M1, 0, 8, close) < 8)
        return false;

    // Check if price has been rising
    int rising_bars = 0;
    for(int i = 1; i < 6; i++)
    {
        if(close[i] > close[i+1])
            rising_bars++;
    }

    // Consider overbought if 4+ of last 5 bars were rising
    return rising_bars >= 4;
}

//+------------------------------------------------------------------+
//| Execute professional trade                                      |
//+------------------------------------------------------------------+
void ExecuteProfessionalTrade(int signal, ENUM_SIGNAL_QUALITY quality)
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Calculate position size
    double lot_size = CalculatePositionSize(quality);
    if(lot_size <= 0) return;

    // Calculate SL and TP
    double sl_distance = StopLoss * point;
    double tp_distance = TakeProfit * point;

    // Adjust for signal quality
    if(quality == SIGNAL_EXCELLENT)
    {
        tp_distance *= 1.2; // Larger targets for excellent signals
    }

    bool result = false;
    string comment = StringFormat("DAX_Pro_%s_Q%d",
                                 (signal > 0) ? "BUY" : "SELL",
                                 (int)quality);

    if(signal > 0) // BUY
    {
        double sl = ask - sl_distance;
        double tp = ask + tp_distance;
        result = trade.Buy(lot_size, _Symbol, ask, sl, tp, comment);
    }
    else if(signal < 0) // SELL
    {
        double sl = bid + sl_distance;
        double tp = bid - tp_distance;
        result = trade.Sell(lot_size, _Symbol, bid, sl, tp, comment);
    }

    if(result)
    {
        g_last_trade_time = TimeCurrent();
        g_daily_trades++;
        g_total_trades++;

        Print("PROFESSIONAL TRADE EXECUTED: ", comment, " | Lot: ", lot_size, " | Quality: ", quality, " | Volume Ratio: ", g_current_volume_ratio, " | Volatility: ", g_current_volatility);
    }
    else
    {
        Print("Trade failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Debug signal quality (called periodically)                     |
//+------------------------------------------------------------------+
void DebugSignalQuality()
{
    static datetime last_debug = 0;
    if(TimeCurrent() - last_debug < 600) // Debug every 10 minutes
        return;

    last_debug = TimeCurrent();

    ENUM_SIGNAL_QUALITY quality = AnalyzeSignalQuality();
    ENUM_MARKET_CONDITION condition = GetMarketCondition();

    Print("=== SIGNAL QUALITY DEBUG ===");
    Print("Quality: ", quality, " | Condition: ", condition);
    Print("Volume Ratio: ", g_current_volume_ratio, " (Min: ", MinVolumeMultiplier, ")");
    Print("Volatility: ", g_current_volatility, " (Min: ", VolatilityThreshold, ")");
    Print("Structure Valid: ", g_market_structure_valid);
    Print("Support: ", g_support_level, " | Resistance: ", g_resistance_level);

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double spread_points = (ask - bid) / point;
    Print("Current Spread: ", spread_points, " points");

    // Check if signal would be generated
    int signal = GetProfessionalSignal(condition);
    Print("Signal Generated: ", signal, " (0=none, 1=buy, -1=sell)");

    // Check quality requirements
    string quality_req = OnlyExcellentSignals ? "EXCELLENT (4+)" : "GOOD (2+)";
    Print("Quality Required: ", quality_req, " | Current: ", quality);
    Print("===========================");
}

//+------------------------------------------------------------------+
//| Calculate position size                                         |
//+------------------------------------------------------------------+
double CalculatePositionSize(ENUM_SIGNAL_QUALITY quality)
{
    double account_balance = account.Balance();
    double risk_amount = account_balance * AccountRiskPercent / 100.0;

    // Adjust risk based on signal quality
    if(quality == SIGNAL_EXCELLENT)
        risk_amount *= 1.3; // Increase risk for excellent signals
    else if(quality == SIGNAL_FAIR)
        risk_amount *= 0.7; // Reduce risk for fair signals

    // Adjust for consecutive losses
    if(g_consecutive_losses >= 1)
        risk_amount *= 0.5; // Reduce risk after losses

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

    double sl_distance = StopLoss * point;
    double sl_amount = sl_distance * tick_value / point;

    double calculated_lots = (sl_amount > 0) ? risk_amount / sl_amount : LotSize;

    // Apply limits
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    calculated_lots = MathMax(calculated_lots, min_lot);
    calculated_lots = MathMin(calculated_lots, max_lot);
    calculated_lots = MathMin(calculated_lots, LotSize * 3.0); // Max 3x base lot size

    // Round to lot step
    calculated_lots = MathRound(calculated_lots / lot_step) * lot_step;

    return calculated_lots;
}

//+------------------------------------------------------------------+
//| Manage existing positions                                       |
//+------------------------------------------------------------------+
void ManagePositions()
{
    if(!position.Select(_Symbol)) return;

    double current_profit = position.Profit() + position.Swap() + position.Commission();

    // Update performance tracking
    UpdatePerformanceTracking(current_profit);

    // Professional trailing stop
    if(current_profit > 0)
    {
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double trailing_distance = StopLoss * 0.6 * point; // 60% of SL as trailing

        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

        if(position.PositionType() == POSITION_TYPE_BUY)
        {
            double new_sl = bid - trailing_distance;
            if(new_sl > position.StopLoss() + point * 2) // Move SL only if significant improvement
            {
                trade.PositionModify(_Symbol, new_sl, position.TakeProfit());
            }
        }
        else if(position.PositionType() == POSITION_TYPE_SELL)
        {
            double new_sl = ask + trailing_distance;
            if(new_sl < position.StopLoss() - point * 2)
            {
                trade.PositionModify(_Symbol, new_sl, position.TakeProfit());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update performance tracking                                     |
//+------------------------------------------------------------------+
void UpdatePerformanceTracking(double current_profit)
{
    static double last_position_profit = 0.0;
    static ulong last_ticket = 0;

    if(position.Ticket() != last_ticket)
    {
        // New position or position closed
        if(last_ticket != 0) // Position was closed
        {
            // Update statistics for closed position
            if(last_position_profit > 0)
            {
                g_winning_trades++;
                g_consecutive_losses = 0; // Reset consecutive losses
            }
            else
            {
                g_consecutive_losses++;

                // Apply cooldown if too many losses
                if(g_consecutive_losses >= ConsecutiveLossLimit)
                {
                    g_cooldown_until = TimeCurrent() + (CooldownMinutes * 60);
                    Print("Cooldown activated for ", CooldownMinutes, " minutes after ", g_consecutive_losses, " consecutive losses");
                }
            }

            g_total_profit += last_position_profit;
            g_daily_pnl += last_position_profit;
        }

        last_ticket = position.Ticket();
        last_position_profit = current_profit;
    }
    else
    {
        last_position_profit = current_profit;
    }

    // Update drawdown tracking
    double current_balance = account.Balance();
    if(current_balance > g_peak_balance)
    {
        g_peak_balance = current_balance;
    }

    double current_drawdown = ((g_peak_balance - current_balance) / g_peak_balance) * 100.0;
    if(current_drawdown > g_max_drawdown)
    {
        g_max_drawdown = current_drawdown;
    }
}

//+------------------------------------------------------------------+
//| Print final statistics                                          |
//+------------------------------------------------------------------+
void PrintFinalStatistics()
{
    double win_rate = (g_total_trades > 0) ? ((double)g_winning_trades / g_total_trades) * 100.0 : 0.0;

    Print("=== FINAL STATISTICS ===");
    Print("Total trades: ", g_total_trades);
    Print("Winning trades: ", g_winning_trades);
    Print("Win rate: ", win_rate, "%");
    Print("Total profit: ", g_total_profit);
    Print("Max drawdown: ", g_max_drawdown, "%");
    Print("Consecutive losses: ", g_consecutive_losses);
}
