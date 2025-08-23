//+------------------------------------------------------------------+
//|                                                     GOLD_ORB.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "GOLD ORB (Opening Range Breakout) Strategy EA"

#include <Trade/Trade.mqh>

//--- Input parameters
input group "=== STRATEGY SETTINGS ==="
input int Inp_Magic = 55221001;                    // Magic Number (ORB)
input string Inp_EA_Tag = "XAU_ORB";              // EA Tag
input double Inp_RiskPct = 1.0;                   // Risk % per trade
input bool Inp_LogVerbose = true;                 // Verbose logging
input bool Inp_WriteCSV = true;                   // Write CSV files

input group "=== ORB PARAMETERS ==="
input int Inp_ORB_RangeMin = 10;                  // Min range bars
input double Inp_ORB_BufferATR = 0.12;            // Buffer ATR multiplier
input double Inp_ORB_SL_ATR = 1.00;               // Stop Loss ATR multiplier
input double Inp_ORB_TP1_ATR = 0.60;              // Take Profit 1 ATR multiplier
input double Inp_ORB_TP2_ATR = 1.60;              // Take Profit 2 ATR multiplier (for runner)
input double Inp_ORB_PartialPct = 0.70;           // Partial close % at TP1
input double Inp_ORB_BE_OffsetPts = 5;            // Break-Even offset points
input double Inp_ORB_Trail_ATR = 0.60;            // ATR trailing multiplier for runner
input int Inp_ORB_ADX_Min = 10;                   // ADX Minimum
input int Inp_ORB_ADX_Max = 55;                   // ADX Maximum
input int Inp_ORB_RecalcMin = 3;                  // Recalc minutes
input int Inp_ORB_ExpireMin = 90;                 // Expire minutes
input bool Inp_ORB_CancelOutOfSession = true;     // Cancel out of session
input double Inp_ORB_RangeATR_Min = 0.30;         // Range ATR Min ratio
input double Inp_ORB_RangeATR_Max = 1.20;         // Range ATR Max ratio
input int Inp_ORB_MinGapFromEntryPts = 20;        // Min gap from current price to entry
input double Inp_ORB_EfficiencyMin = 0.35;        // ChopGuard: Min range efficiency
input int Inp_ORB_TimeStopMin = 30;               // Time stop in minutes

input group "=== FILTERS ==="
input int Inp_MaxSpreadPts = 35;                  // Max spread in points for arming
input bool Inp_UseVWAP = true;                    // Use VWAP filter
input double Inp_ORB_VWAP_SD = 1.0;               // VWAP Standard Deviation multiplier
input int Inp_VWAP_SlopeBars = 10;                // VWAP slope calculation bars
input int Inp_VWAP_MinBars = 10;                  // Minimum bars before VWAP filter active
input bool Inp_VWAP_RequireSlope = true;          // Require VWAP slope for filtering

input group "=== BIAS FILTER ==="
input bool Inp_ORB_UseBias = true;                // Use directional bias filter
input ENUM_TIMEFRAMES Inp_Bias_TF = PERIOD_H1;    // Bias timeframe for SMA
input int Inp_Bias_SMA = 200;                     // SMA period for bias
input ENUM_TIMEFRAMES Inp_Bias_EMA_TF = PERIOD_M5; // EMA timeframe
input int Inp_Bias_EMA_Period = 55;               // EMA period
input int Inp_Bias_EMA_SlopeBars = 5;             // EMA slope calculation bars

input group "=== SESSION SUBWINDOWS ==="
input int Inp_LO_MinFromOpen = 0;                 // London min minutes from open
input int Inp_LO_MaxFromOpen = 90;                // London max minutes from open
input int Inp_NY_MinFromOpen = 0;                 // NY min minutes from open
input int Inp_NY_MaxFromOpen = 60;                // NY max minutes from open

input group "=== SESSION TIMES ==="
input int Inp_LondonOpen_H = 8;                   // London Open Hour
input int Inp_LondonOpen_M = 0;                   // London Open Minute
input int Inp_LondonEnd_H = 16;                   // London End Hour
input int Inp_LondonEnd_M = 0;                    // London End Minute
input int Inp_NYOpen_H = 14;                      // NY Open Hour
input int Inp_NYOpen_M = 30;                      // NY Open Minute
input int Inp_NYEnd_H = 21;                       // NY End Hour
input int Inp_NYEnd_M = 0;                        // NY End Minute

input group "=== RISK MANAGEMENT ==="
input double Inp_DayLossPct = 3.0;                // Daily Loss % Cap
input double Inp_WeekLossPct = 8.0;               // Weekly Loss % Cap
input int Inp_MaxConsecLosses = 5;                // Max Consecutive Losses
input int Inp_MaxTradesPerDay = 10;               // Max Trades Per Day
input int Inp_ServerDayStart = 0;                 // Server Day Start Hour
input int Inp_BrokerGMT_Offset = 2;               // Broker GMT Offset

input group "=== TECHNICAL INDICATORS ==="
input int Inp_ATR_Period = 14;                    // ATR Period
input int Inp_ADX_Period = 14;                    // ADX Period

//--- Enums
enum SessionId { SES_TOKYO, SES_LONDON, SES_NY, SES_OFF };
enum ModState { M_IDLE, M_ARMED, M_ACTIVE, M_DONE };
enum EntryMode { ENTRY_STOP, ENTRY_STOP_LIMIT };

input group "=== ENTRY MODE ==="
input EntryMode Inp_ORB_EntryMode = ENTRY_STOP_LIMIT; // Entry mode: Stop or Stop-Limit
input int Inp_StopLimit_OffsetPts = 15;           // Stop-Limit retest offset in points

//--- Structures
struct IndCache {
    double ATR;
    double ADX;
    double SMA_Bias;
    double EMA_Bias;
    double VWAP;
    double VWAP_SD;
    double VWAP_Slope;
    bool Warmed;
    int ATR_Handle;
    int ADX_Handle;
    int SMA_Handle;
    int EMA_Handle;

    void Init(string symbol) {
        ATR = 0;
        ADX = 0;
        SMA_Bias = 0;
        EMA_Bias = 0;
        VWAP = 0;
        VWAP_SD = 0;
        VWAP_Slope = 0;
        Warmed = false;

        // Create indicator handles
        ATR_Handle = iATR(symbol, PERIOD_M5, Inp_ATR_Period);
        ADX_Handle = iADX(symbol, PERIOD_M5, Inp_ADX_Period);
        SMA_Handle = iMA(symbol, Inp_Bias_TF, Inp_Bias_SMA, 0, MODE_SMA, PRICE_CLOSE);
        EMA_Handle = iMA(symbol, Inp_Bias_EMA_TF, Inp_Bias_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);

        if(ATR_Handle == INVALID_HANDLE || ADX_Handle == INVALID_HANDLE ||
           SMA_Handle == INVALID_HANDLE || EMA_Handle == INVALID_HANDLE) {
            Print("Error creating indicator handles");
        }
    }

    bool Update() {
        double atr_buffer[1];
        double adx_buffer[3]; // Get 3 values for smoothing
        double sma_buffer[1];
        double ema_buffer[20]; // Fixed size array for EMA slope calculation (max 20 bars)

        // Copy ATR value from closed bar (shift=1)
        if(CopyBuffer(ATR_Handle, 0, 1, 1, atr_buffer) <= 0) {
            Print("Error copying ATR buffer");
            return false;
        }

        // Copy ADX values from closed bars (shift 1, 2, 3 for smoothing)
        if(CopyBuffer(ADX_Handle, 0, 1, 3, adx_buffer) <= 0) {
            Print("Error copying ADX buffer");
            return false;
        }

        // Copy SMA bias value from closed bar (shift=1)
        if(CopyBuffer(SMA_Handle, 0, 1, 1, sma_buffer) <= 0) {
            Print("Error copying SMA buffer");
            return false;
        }

        // Copy EMA values for slope calculation (shift=1 to shift=1+SlopeBars)
        int ema_bars_needed = MathMin(Inp_Bias_EMA_SlopeBars + 1, 20); // Limit to array size
        if(CopyBuffer(EMA_Handle, 0, 1, ema_bars_needed, ema_buffer) <= 0) {
            Print("Error copying EMA buffer");
            return false;
        }

        ATR = atr_buffer[0];
        SMA_Bias = sma_buffer[0];
        EMA_Bias = ema_buffer[0]; // Most recent closed bar

        // Smooth ADX over 3 points (most recent closed bars)
        ADX = (adx_buffer[0] + adx_buffer[1] + adx_buffer[2]) / 3.0;

        // Warmed when all indicators have valid values > 0
        if(ATR > 0 && ADX > 0 && SMA_Bias > 0 && EMA_Bias > 0) {
            Warmed = true;
            return true;
        }
        return false;
    }

    void Deinit() {
        if(ATR_Handle != INVALID_HANDLE) IndicatorRelease(ATR_Handle);
        if(ADX_Handle != INVALID_HANDLE) IndicatorRelease(ADX_Handle);
        if(SMA_Handle != INVALID_HANDLE) IndicatorRelease(SMA_Handle);
        if(EMA_Handle != INVALID_HANDLE) IndicatorRelease(EMA_Handle);
    }
};

struct TradeMeta {
    string strategy_short;
    SessionId session;
    double lots;
    double open_price;
    double sl_price;
    double tp_price;
    double remaining_lots;
    datetime open_time;
};

struct RiskLimits {
    double day_loss;
    double week_loss;
    int consec_losses;
    int trades_today;
    bool locked_day;
    bool locked_week;
    datetime last_reset_date;
};

//--- Global variables
CTrade g_trade;
IndCache g_cache;
ModState g_state = M_IDLE;
datetime g_next_arm_time = 0;
ulong g_pend_buy = 0;
ulong g_pend_sell = 0;
double g_range_high = 0;
double g_range_low = 0;
datetime g_arm_time = 0;
SessionId g_armed_session = SES_OFF;
RiskLimits g_limits;

//--- Active position management
ulong g_active_position_id = 0;
datetime g_active_start_time = 0;
bool g_partial_executed = false;
double g_highest_since_entry = 0;
double g_lowest_since_entry = 0;
double g_tp1_price = 0;        // Store TP1 price for partial close
double g_tp2_price = 0;        // Store TP2 price for runner

// Note: Stop-Limit entry tracking removed as it was unused
// Stop-Limit orders are now handled directly in PlacePendingOrders() with proper validation

//--- Bias filter
enum BiasDirection { BIAS_NONE, BIAS_BUY_ONLY, BIAS_SELL_ONLY };
BiasDirection g_allowed_direction = BIAS_NONE;

//--- One trade per session tracking
bool g_london_traded = false;
bool g_ny_traded = false;

//--- VWAP calculation variables
datetime g_session_start_time = 0;
SessionId g_vwap_session = SES_OFF;
double g_vwap_sum_pv = 0;      // Sum of price * volume
double g_vwap_sum_v = 0;       // Sum of volume
double g_vwap_values[];        // Array to store VWAP values for slope calculation
int g_vwap_count = 0;

//--- Trade tracking
TradeMeta g_trade_metas[];
ulong g_trade_tickets[];
int g_meta_count = 0;
const int MAX_TRADE_METAS = 100;

//--- Statistics
long g_total_trades = 0;
long g_total_wins = 0;
double g_total_pnl = 0;

//--- CSV
int g_csv_handle = INVALID_HANDLE;
string g_csv_filename = "";
bool g_csv_enabled = true;  // Runtime CSV status (can be disabled on errors)

//--- Function declarations
SessionId GetCurrentSession();
bool IsSessionActive(SessionId session);
bool AreSessionsOverlapping();
double CalculateLotSize(double risk_pct, double sl_price_distance);
bool StoreTradeMeta(ulong ticket, const TradeMeta& meta);
bool GetTradeMeta(ulong ticket, TradeMeta& meta);
void UpdateRiskLimits();
bool IsDayBoundaryReached();
void DoDailyReset();
void InitCSV();
void WriteTradeToCSV(ulong ticket, string action, double price, double lots, string comment,
                    ulong position_id = 0, string reason = "", string state_before = "", double trade_profit = 0,
                    ENUM_DEAL_REASON deal_reason = DEAL_REASON_CLIENT, bool is_full_close = true,
                    double stop_price = 0, double limit_price = 0);
double Pts(double price_diff);

//--- VWAP functions
void UpdateVWAP(SessionId session);
void ResetVWAP(SessionId session);
bool CheckSpreadFilter();
bool CheckVWAPFilter(SessionId session);

//--- Entry mode functions
bool PlacePendingOrders(SessionId session, double buy_entry, double sell_entry, double buy_sl, double sell_sl,
                       double buy_tp1, double sell_tp1, double lots, datetime expire_time);
void HandleStopLimitEntry();

//--- Order management helpers
void SafeCancel(ulong ticket, string whichSide);
bool NormalizeAndValidatePending(string side, double& entry, double& sl, double& tp);
string GetRetcodeDescription(uint retcode);

//--- Position modification helpers
bool ValidateStopLoss(double new_sl, ENUM_POSITION_TYPE pos_type, double current_price);
bool ValidateTakeProfit(double new_tp, ENUM_POSITION_TYPE pos_type, double current_price);
bool ValidatePositionModification(double new_sl, double new_tp, ENUM_POSITION_TYPE pos_type, double current_price);
double NormalizeVolume(double volume);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    // Validate input parameters
    if(Inp_Bias_EMA_SlopeBars > 19) {
        Print("ERROR: Inp_Bias_EMA_SlopeBars cannot exceed 19. Current value: ", Inp_Bias_EMA_SlopeBars);
        return INIT_FAILED;
    }

    // Validate session time parameters
    if(Inp_LondonOpen_M < 0 || Inp_LondonOpen_M > 59 || Inp_LondonEnd_M < 0 || Inp_LondonEnd_M > 59 ||
       Inp_NYOpen_M < 0 || Inp_NYOpen_M > 59 || Inp_NYEnd_M < 0 || Inp_NYEnd_M > 59) {
        Print("ERROR: Session minute parameters must be between 0 and 59");
        return INIT_FAILED;
    }

    if(Inp_LondonOpen_H < 0 || Inp_LondonOpen_H > 23 || Inp_LondonEnd_H < 0 || Inp_LondonEnd_H > 23 ||
       Inp_NYOpen_H < 0 || Inp_NYOpen_H > 23 || Inp_NYEnd_H < 0 || Inp_NYEnd_H > 23) {
        Print("ERROR: Session hour parameters must be between 0 and 23");
        return INIT_FAILED;
    }

    // Validate symbol
    if(!SymbolSelect(_Symbol, true)) {
        Print("ERROR: Failed to select symbol ", _Symbol);
        return INIT_FAILED;
    }
    
    // Initialize services
    g_cache.Init(_Symbol);
    g_trade.SetExpertMagicNumber(Inp_Magic);
    
    // Initialize arrays
    ArrayResize(g_trade_metas, MAX_TRADE_METAS);
    ArrayResize(g_trade_tickets, MAX_TRADE_METAS);
    ArrayResize(g_vwap_values, Inp_VWAP_SlopeBars + 10); // Extra buffer for VWAP slope calculation
    g_meta_count = 0;
    
    // Initialize CSV
    g_csv_enabled = Inp_WriteCSV;  // Copy input to runtime variable
    if(g_csv_enabled) {
        InitCSV();

        // Validate CSV handle after initialization
        if(g_csv_handle == INVALID_HANDLE) {
            Print("WARNING: CSV initialization failed. CSV logging disabled.");
            g_csv_enabled = false;
        }
    }
    
    // Initialize risk management
    DoDailyReset();
    
    // Warm up indicators using historical data
    Print("Warming up indicators using historical data...");

    // Copy historical data to ensure indicators are calculated
    double atr_warmup[200];
    double adx_warmup[200];
    double sma_warmup[200];
    double ema_warmup[200];

    // Copy 200 bars of historical data for each indicator
    int atr_copied = CopyBuffer(g_cache.ATR_Handle, 0, 0, 200, atr_warmup);
    int adx_copied = CopyBuffer(g_cache.ADX_Handle, 0, 0, 200, adx_warmup);
    int sma_copied = CopyBuffer(g_cache.SMA_Handle, 0, 0, 200, sma_warmup);
    int ema_copied = CopyBuffer(g_cache.EMA_Handle, 0, 0, 200, ema_warmup);

    if(atr_copied > 0 && adx_copied > 0 && sma_copied > 0 && ema_copied > 0) {
        // Set warmed status based on last valid values
        if(atr_warmup[atr_copied-1] > 0 && adx_warmup[adx_copied-1] > 0 &&
           sma_warmup[sma_copied-1] > 0 && ema_warmup[ema_copied-1] > 0) {
            g_cache.Warmed = true;
            Print("Indicators warmed up successfully: ATR(", atr_copied, "), ADX(", adx_copied,
                  "), SMA(", sma_copied, "), EMA(", ema_copied, ")");
        } else {
            Print("WARNING: Historical indicator values are invalid");
        }
    } else {
        Print("WARNING: Failed to copy historical indicator data");
    }
    
    // Log session configuration
    Print("=== SESSION CONFIGURATION ===");
    Print("London: ", StringFormat("%02d:%02d", Inp_LondonOpen_H, Inp_LondonOpen_M), " - ",
          StringFormat("%02d:%02d", Inp_LondonEnd_H, Inp_LondonEnd_M), " GMT");
    Print("NY: ", StringFormat("%02d:%02d", Inp_NYOpen_H, Inp_NYOpen_M), " - ",
          StringFormat("%02d:%02d", Inp_NYEnd_H, Inp_NYEnd_M), " GMT");
    Print("Broker GMT Offset: ", Inp_BrokerGMT_Offset, " hours");

    // Check for session overlap
    if(AreSessionsOverlapping()) {
        Print("WARNING: Sessions are currently overlapping - NY session will take priority");
    }

    Print("ORB EA initialized successfully. Magic: ", Inp_Magic);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("=== ORB EA DEINITIALIZATION SUMMARY ===");
    Print("Total trades: ", g_total_trades, " | Wins: ", g_total_wins, " | Win rate: ",
          g_total_trades > 0 ? DoubleToString((double)g_total_wins / g_total_trades * 100, 2) : "0.00", "%");
    Print("Total P&L: ", DoubleToString(g_total_pnl, 2));
    Print("Day loss: ", DoubleToString(g_limits.day_loss, 2), " | Week loss: ", DoubleToString(g_limits.week_loss, 2));
    Print("Risk locks - Day: ", g_limits.locked_day ? "YES" : "NO", " | Week: ", g_limits.locked_week ? "YES" : "NO");

    // Clean up indicators
    g_cache.Deinit();

    if(g_csv_handle != INVALID_HANDLE) {
        FileClose(g_csv_handle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Re-arm after cooldown if conditions are met
    if(g_state == M_DONE && TimeCurrent() >= g_next_arm_time && !g_limits.locked_day && !g_limits.locked_week) {
        g_state = M_IDLE;
        if(Inp_LogVerbose) Print("ORB Re-armed after cooldown");
    }

    // Update indicators
    if(!g_cache.Update()) return;

    // Get current session
    SessionId current_session = GetCurrentSession();

    // Update VWAP
    UpdateVWAP(current_session);

    // Update risk management
    UpdateRiskLimits();

    // Check if trading is locked
    if(g_limits.locked_day || g_limits.locked_week) {
        return;
    }

    // Handle session transitions and reset traded flags appropriately
    static SessionId last_session = SES_OFF;
    static bool was_overlapping = false;
    bool currently_overlapping = AreSessionsOverlapping();

    // Reset session traded flags when sessions end (not just when they change)
    // This handles overlapping sessions properly
    if(current_session != last_session || was_overlapping != currently_overlapping) {
        // Check if London session just ended
        if(last_session == SES_LONDON && current_session != SES_LONDON && !currently_overlapping) {
            g_london_traded = false;
            if(Inp_LogVerbose) Print("London session ended - resetting traded flag");
        }
        // Check if NY session just ended
        else if(last_session == SES_NY && current_session != SES_NY && !currently_overlapping) {
            g_ny_traded = false;
            if(Inp_LogVerbose) Print("NY session ended - resetting traded flag");
        }
        // Handle transition from overlap to single session
        else if(was_overlapping && !currently_overlapping) {
            if(current_session == SES_LONDON) {
                g_ny_traded = false; // NY ended, reset its flag
                if(Inp_LogVerbose) Print("Session overlap ended - NY session closed, resetting NY traded flag");
            } else if(current_session == SES_NY) {
                g_london_traded = false; // London ended, reset its flag
                if(Inp_LogVerbose) Print("Session overlap ended - London session closed, resetting London traded flag");
            }
        }

        last_session = current_session;
        was_overlapping = currently_overlapping;
    }

    // Strategy logic based on state
    if(g_state == M_IDLE) {
        // Check if eligible to arm
        if(IsEligible(current_session)) {
            if(Arm(current_session)) {
                g_state = M_ARMED;
            }
        }
    }
    else if(g_state == M_ARMED) {
        OnTickArmed(current_session);
    }
    else if(g_state == M_ACTIVE) {
        OnTickActive();
    }
}

//+------------------------------------------------------------------+
//| Trade transaction function                                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result) {
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
    if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != Inp_Magic) return;
    
    int entry_type = (int)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

    if(entry_type == DEAL_ENTRY_IN) {
        // Entry deal - position opened from pending order
        ulong order_ticket = HistoryDealGetInteger(trans.deal, DEAL_ORDER);
        ulong position_id = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
        ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
        double entry_price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
        double entry_lots = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);

        // Check if this was one of our pending orders
        if((deal_type == DEAL_TYPE_BUY && order_ticket == g_pend_buy) ||
           (deal_type == DEAL_TYPE_SELL && order_ticket == g_pend_sell)) {

            g_state = M_ACTIVE;
            g_active_position_id = position_id;
            g_active_start_time = TimeCurrent();
            g_partial_executed = false;

            // Initialize tracking for trailing
            g_highest_since_entry = entry_price;
            g_lowest_since_entry = entry_price;

            // Store TP1 and calculate TP2 prices for reference
            TradeMeta meta;
            if(GetTradeMeta(order_ticket, meta)) {
                g_tp1_price = meta.tp_price; // TP1 price from meta

                // Calculate TP2 price
                double tp2_distance = g_cache.ATR * Inp_ORB_TP2_ATR;
                if(deal_type == DEAL_TYPE_BUY) {
                    g_tp2_price = entry_price + tp2_distance;
                } else {
                    g_tp2_price = entry_price - tp2_distance;
                }

                // Normalize TP2 price
                double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                if(tick_size <= 0) tick_size = _Point;
                g_tp2_price = NormalizeDouble(MathRound(g_tp2_price / tick_size) * tick_size, _Digits);
            }

            // Cancel the opposite pending order using SafeCancel
            if(deal_type == DEAL_TYPE_BUY) {
                SafeCancel(g_pend_sell, "SELL");
            } else if(deal_type == DEAL_TYPE_SELL) {
                SafeCancel(g_pend_buy, "BUY");
            }

            // Copy meta from order_ticket to position_id and sync lots
            TradeMeta position_meta;
            if(GetTradeMeta(order_ticket, position_meta)) {
                position_meta.lots = entry_lots;
                position_meta.remaining_lots = entry_lots;
                StoreTradeMeta(position_id, position_meta); // Store by position_id for future reference
            }

            // Clear the triggered pending order
            if(deal_type == DEAL_TYPE_BUY) g_pend_buy = 0;
            else g_pend_sell = 0;

            // Log ENTRY to CSV
            if(g_csv_enabled) {
                string action = (deal_type == DEAL_TYPE_BUY) ? "BUY" : "SELL";
                WriteTradeToCSV(order_ticket, action, entry_price, entry_lots, "ENTRY", position_id, "", "M_ARMED",
                              0, DEAL_REASON_CLIENT, true, 0, 0);
            }

            // Set session traded flag on ENTRY (not exit) to prevent multiple trades in same session
            if(g_armed_session == SES_LONDON) {
                g_london_traded = true;
            } else if(g_armed_session == SES_NY) {
                g_ny_traded = true;
            }

            if(Inp_LogVerbose) {
                Print("ORB ", deal_type == DEAL_TYPE_BUY ? "Buy" : "Sell", " order triggered via OnTradeTransaction");
            }
        }
    }
    else if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_INOUT) {
        // Exit deal - handle trade outcome
        ulong position_id = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
        ulong deal_ticket = trans.deal;
        double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
        double lots = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
        double price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);

        // Determine close reason using DEAL_REASON
        string close_reason = "UNKNOWN";
        ENUM_DEAL_REASON deal_reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);

        switch(deal_reason) {
            case DEAL_REASON_SL:
                close_reason = "STOP_LOSS";
                break;
            case DEAL_REASON_TP:
                close_reason = "TAKE_PROFIT";
                break;
            case DEAL_REASON_CLIENT:
                close_reason = "MANUAL_CLOSE";
                break;
            case DEAL_REASON_MOBILE:
                close_reason = "MOBILE_CLOSE";
                break;
            case DEAL_REASON_WEB:
                close_reason = "WEB_CLOSE";
                break;
            case DEAL_REASON_EXPERT:
                close_reason = "EA_CLOSE";
                break;
            case DEAL_REASON_SO:
                close_reason = "STOP_OUT";
                break;
            case DEAL_REASON_ROLLOVER:
                close_reason = "ROLLOVER";
                break;
            default:
                close_reason = "OTHER";
                break;
        }

        // Check if this is a full close (position no longer exists)
        bool is_full_close = (PositionsTotal() == 0 || !PositionSelectByTicket(position_id));

        // Update TradeMeta for partial closes
        if(!is_full_close) {
            // This is a partial close - update remaining lots in TradeMeta
            TradeMeta meta;
            if(GetTradeMeta(position_id, meta)) {
                meta.remaining_lots -= lots;
                // Update the stored meta with new remaining lots
                for(int i = 0; i < g_meta_count; i++) {
                    if(g_trade_tickets[i] == position_id) {
                        g_trade_metas[i].remaining_lots = meta.remaining_lots;
                        break;
                    }
                }
            }
        }

        // Only update final statistics for full closes
        if(is_full_close) {
            g_total_trades++;
            g_total_pnl += profit;

            bool is_profit = profit > 0;
            if(is_profit) {
                g_total_wins++;
                g_limits.consec_losses = 0;
            } else {
                g_limits.consec_losses++;
                g_limits.day_loss += MathAbs(profit);
                g_limits.week_loss += MathAbs(profit);
            }

            g_limits.trades_today++;
        }

        // Log to CSV with position_id for proper tracking
        if(g_csv_enabled) {
            string action = is_full_close ? "CLOSE" : "PARTIAL";
            WriteTradeToCSV(deal_ticket, action, price, lots,
                          is_profit ? "PROFIT" : "LOSS", position_id, close_reason, "M_ACTIVE", profit, deal_reason, is_full_close, 0, 0);
        }

        // Session traded flags are now set on ENTRY, not exit

        // Handle strategy completion
        OnExit(is_profit);

        if(Inp_LogVerbose) {
            Print("ORB Trade closed: Position=", position_id, " Profit=", DoubleToString(profit, 2),
                  " Result=", is_profit ? "WIN" : "LOSS", " Reason=", close_reason);
        }
    }
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
SessionId GetCurrentSession() {
    // Get server time and apply GMT offset to get GMT time
    datetime server_time = TimeCurrent();
    datetime gmt_time = server_time - Inp_BrokerGMT_Offset * 3600;

    MqlDateTime dt;
    TimeToStruct(gmt_time, dt);

    // Create current time in minutes since midnight for comparison
    int current_minutes = dt.hour * 60 + dt.min;

    // London session times in minutes since midnight
    int london_open_minutes = Inp_LondonOpen_H * 60 + Inp_LondonOpen_M;
    int london_end_minutes = Inp_LondonEnd_H * 60 + Inp_LondonEnd_M;

    // NY session times in minutes since midnight
    int ny_open_minutes = Inp_NYOpen_H * 60 + Inp_NYOpen_M;
    int ny_end_minutes = Inp_NYEnd_H * 60 + Inp_NYEnd_M;

    // Check London session (handle potential overnight sessions)
    bool in_london = false;
    if(london_end_minutes > london_open_minutes) {
        // Same day session
        in_london = (current_minutes >= london_open_minutes && current_minutes < london_end_minutes);
    } else {
        // Overnight session (crosses midnight)
        in_london = (current_minutes >= london_open_minutes || current_minutes < london_end_minutes);
    }

    // Check NY session (handle potential overnight sessions)
    bool in_ny = false;
    if(ny_end_minutes > ny_open_minutes) {
        // Same day session
        in_ny = (current_minutes >= ny_open_minutes && current_minutes < ny_end_minutes);
    } else {
        // Overnight session (crosses midnight)
        in_ny = (current_minutes >= ny_open_minutes || current_minutes < ny_end_minutes);
    }

    // Handle overlapping sessions - prioritize NY when both are active
    // This ensures that during overlap periods (e.g., London 14:30-16:00 and NY 14:30-21:00),
    // the system treats it as NY session for consistency in strategy execution
    if(in_ny) {
        return SES_NY;
    } else if(in_london) {
        return SES_LONDON;
    }

    return SES_OFF;
}

bool IsSessionActive(SessionId session) {
    return session == SES_LONDON || session == SES_NY;
}

bool AreSessionsOverlapping() {
    // Get GMT time for consistent session checking
    datetime server_time = TimeCurrent();
    datetime gmt_time = server_time - Inp_BrokerGMT_Offset * 3600;

    MqlDateTime dt;
    TimeToStruct(gmt_time, dt);
    int current_minutes = dt.hour * 60 + dt.min;

    // London session times in minutes since midnight
    int london_open_minutes = Inp_LondonOpen_H * 60 + Inp_LondonOpen_M;
    int london_end_minutes = Inp_LondonEnd_H * 60 + Inp_LondonEnd_M;

    // NY session times in minutes since midnight
    int ny_open_minutes = Inp_NYOpen_H * 60 + Inp_NYOpen_M;
    int ny_end_minutes = Inp_NYEnd_H * 60 + Inp_NYEnd_M;

    // Check if currently in London session
    bool in_london = false;
    if(london_end_minutes > london_open_minutes) {
        in_london = (current_minutes >= london_open_minutes && current_minutes < london_end_minutes);
    } else {
        in_london = (current_minutes >= london_open_minutes || current_minutes < london_end_minutes);
    }

    // Check if currently in NY session
    bool in_ny = false;
    if(ny_end_minutes > ny_open_minutes) {
        in_ny = (current_minutes >= ny_open_minutes && current_minutes < ny_end_minutes);
    } else {
        in_ny = (current_minutes >= ny_open_minutes || current_minutes < ny_end_minutes);
    }

    return (in_london && in_ny);
}

double CalculateLotSize(double risk_pct, double sl_price_distance) {
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * risk_pct / 100.0;

    // Validate input parameters
    if(sl_price_distance <= 0) {
        if(Inp_LogVerbose) Print("ERROR: Invalid SL price distance = ", DoubleToString(sl_price_distance, _Digits));
        return 0;
    }

    if(account_balance <= 0) {
        if(Inp_LogVerbose) Print("ERROR: Invalid account balance = ", DoubleToString(account_balance, 2));
        return 0;
    }

    // Get symbol properties - no fallback values
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    // Validate all symbol properties - fail gracefully if any are invalid
    if(tick_value <= 0) {
        Print("ERROR: Invalid SYMBOL_TRADE_TICK_VALUE = ", DoubleToString(tick_value, 8), " for symbol ", _Symbol);
        return 0;
    }

    if(tick_size <= 0) {
        Print("ERROR: Invalid SYMBOL_TRADE_TICK_SIZE = ", DoubleToString(tick_size, 8), " for symbol ", _Symbol);
        return 0;
    }

    if(min_lot <= 0) {
        Print("ERROR: Invalid SYMBOL_VOLUME_MIN = ", DoubleToString(min_lot, 8), " for symbol ", _Symbol);
        return 0;
    }

    if(max_lot <= 0) {
        Print("ERROR: Invalid SYMBOL_VOLUME_MAX = ", DoubleToString(max_lot, 8), " for symbol ", _Symbol);
        return 0;
    }

    if(lot_step <= 0) {
        Print("ERROR: Invalid SYMBOL_VOLUME_STEP = ", DoubleToString(lot_step, 8), " for symbol ", _Symbol);
        return 0;
    }

    // Calculate risk per lot: ticks = sl_price_distance / tick_size, then risk_per_lot = ticks * tick_value
    double ticks = sl_price_distance / tick_size;
    double risk_per_lot = ticks * tick_value;

    if(risk_per_lot <= 0) {
        if(Inp_LogVerbose) Print("ERROR: Calculated risk per lot <= 0: ticks=", DoubleToString(ticks, 2),
                                " risk_per_lot=", DoubleToString(risk_per_lot, 2));
        return 0;
    }

    // Calculate lot size
    double lots = risk_amount / risk_per_lot;

    // Apply lot constraints and rounding
    lots = MathMax(lots, min_lot);
    lots = MathMin(lots, max_lot);
    lots = MathRound(lots / lot_step) * lot_step;

    // Final validation
    if(lots <= 0) {
        if(Inp_LogVerbose) Print("ERROR: Final calculated lot size <= 0");
        return 0;
    }

    if(Inp_LogVerbose) {
        Print("Risk calculation: Balance=", DoubleToString(account_balance, 2),
              " Risk%=", DoubleToString(risk_pct, 2),
              " RiskAmount=", DoubleToString(risk_amount, 2),
              " SL_Distance=", DoubleToString(sl_price_distance, _Digits),
              " Ticks=", DoubleToString(ticks, 2),
              " RiskPerLot=", DoubleToString(risk_per_lot, 2),
              " Lots=", DoubleToString(lots, 2));
    }

    return lots;
}

bool StoreTradeMeta(ulong ticket, const TradeMeta& meta) {
    if(g_meta_count >= MAX_TRADE_METAS) {
        Print("WARNING: Trade meta storage full");
        return false;
    }

    g_trade_tickets[g_meta_count] = ticket;
    g_trade_metas[g_meta_count] = meta;
    g_meta_count++;

    return true;
}

bool GetTradeMeta(ulong ticket, TradeMeta& meta) {
    for(int i = 0; i < g_meta_count; i++) {
        if(g_trade_tickets[i] == ticket) {
            meta = g_trade_metas[i];
            return true;
        }
    }
    return false;
}

double Pts(double price_diff) {
    return price_diff / _Point;
}

//+------------------------------------------------------------------+
//| Risk Management Functions                                        |
//+------------------------------------------------------------------+
void UpdateRiskLimits() {
    // Check for daily reset
    if(IsDayBoundaryReached()) {
        DoDailyReset();
    }

    // Check limits and apply locks
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(account_balance <= 0.0) return;

    double day_loss_pct = (g_limits.day_loss / account_balance) * 100.0;
    double week_loss_pct = (g_limits.week_loss / account_balance) * 100.0;

    // Check daily limits
    if(!g_limits.locked_day) {
        if(day_loss_pct >= Inp_DayLossPct ||
           g_limits.consec_losses >= Inp_MaxConsecLosses ||
           g_limits.trades_today >= Inp_MaxTradesPerDay) {
            g_limits.locked_day = true;
            Print("DAILY LOCK ACTIVATED - Loss: ", DoubleToString(day_loss_pct, 2), "% | Consec: ",
                  g_limits.consec_losses, " | Trades: ", g_limits.trades_today);
        }
    }

    // Check weekly limits
    if(!g_limits.locked_week && week_loss_pct >= Inp_WeekLossPct) {
        g_limits.locked_week = true;
        Print("WEEKLY LOCK ACTIVATED - Loss: ", DoubleToString(week_loss_pct, 2), "%");
    }
}

bool IsDayBoundaryReached() {
    // Apply GMT offset to get GMT time for consistent day boundary detection
    datetime server_time = TimeCurrent();
    datetime gmt_time = server_time - Inp_BrokerGMT_Offset * 3600;

    MqlDateTime dt;
    TimeToStruct(gmt_time, dt);

    // Create today's day start time in GMT
    MqlDateTime day_start_dt = dt;
    day_start_dt.hour = Inp_ServerDayStart;
    day_start_dt.min = 0;
    day_start_dt.sec = 0;
    datetime todays_day_start_gmt = StructToTime(day_start_dt);

    // Check if we've passed today's day start and it's a different date than last reset
    if(gmt_time >= todays_day_start_gmt) {
        MqlDateTime reset_dt;
        TimeToStruct(todays_day_start_gmt, reset_dt);
        int reset_date = reset_dt.year * 10000 + reset_dt.mon * 100 + reset_dt.day;

        // Convert last reset date to GMT for comparison
        datetime last_reset_gmt = g_limits.last_reset_date - Inp_BrokerGMT_Offset * 3600;
        MqlDateTime last_reset_dt;
        TimeToStruct(last_reset_gmt, last_reset_dt);
        int last_reset_date_int = last_reset_dt.year * 10000 + last_reset_dt.mon * 100 + last_reset_dt.day;

        return (reset_date != last_reset_date_int);
    }

    return false;
}

void DoDailyReset() {
    datetime server_time = TimeCurrent();
    datetime gmt_time = server_time - Inp_BrokerGMT_Offset * 3600;

    // Store previous values for logging
    double prev_day_loss = g_limits.day_loss;
    int prev_trades = g_limits.trades_today;
    int prev_consec = g_limits.consec_losses;
    bool was_locked = g_limits.locked_day;

    // Reset daily counters
    g_limits.day_loss = 0;
    g_limits.trades_today = 0;
    g_limits.consec_losses = 0;
    g_limits.locked_day = false;
    g_limits.last_reset_date = server_time; // Store server time for consistency

    // Reset ORB state and pending orders
    g_state = M_IDLE;
    g_pend_buy = 0;
    g_pend_sell = 0;
    g_armed_session = SES_OFF;
    g_active_position_id = 0;
    g_partial_executed = false;

    // Check for weekly reset (Monday) using GMT time
    MqlDateTime dt;
    TimeToStruct(gmt_time, dt);
    if(dt.day_of_week == 1) { // Monday
        double prev_week_loss = g_limits.week_loss;
        bool was_week_locked = g_limits.locked_week;

        g_limits.week_loss = 0;
        g_limits.locked_week = false;

        Print("=== WEEKLY RESET @ ", TimeToString(gmt_time, TIME_DATE|TIME_MINUTES), " GMT (Server: ", TimeToString(server_time, TIME_DATE|TIME_MINUTES), ") ===");
        Print("Previous week loss: ", DoubleToString(prev_week_loss, 2), " | Was locked: ", was_week_locked ? "YES" : "NO");
    }

    // Log daily reset
    Print("=== DAILY RESET @ ", TimeToString(gmt_time, TIME_DATE|TIME_MINUTES), " GMT (Server: ", TimeToString(server_time, TIME_DATE|TIME_MINUTES), ") ===");
    Print("Previous day loss: ", DoubleToString(prev_day_loss, 2), " | Trades: ", prev_trades,
          " | Consec losses: ", prev_consec, " | Was locked: ", was_locked ? "YES" : "NO");
}

//+------------------------------------------------------------------+
//| CSV Functions                                                    |
//+------------------------------------------------------------------+
void InitCSV() {
    // Create unique filename with timestamp, symbol, timeframe, magic, and pass ID
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    string timeframe_str = EnumToString(PERIOD_CURRENT);
    StringReplace(timeframe_str, "PERIOD_", "");

    // Get optimization pass ID if available
    string pass_id = "";
    if(MQLInfoInteger(MQL_OPTIMIZATION)) {
        pass_id = "__pass_" + IntegerToString(GetTickCount() % 10000); // Simple pass identifier
    }

    g_csv_filename = StringFormat("%s_%04d_%02d_%02d_%02d%02d%02d_%s_%s_%d%s.csv",
        Inp_EA_Tag,
        dt.year, dt.mon, dt.day,
        dt.hour, dt.min, dt.sec,
        _Symbol,
        timeframe_str,
        Inp_Magic,
        pass_id
    );

    // Use FILE_COMMON to save in MQL5\Files\Common directory with UTF8 encoding
    g_csv_handle = FileOpen(g_csv_filename, FILE_WRITE|FILE_CSV|FILE_COMMON);

    if(g_csv_handle != INVALID_HANDLE) {
        // Enhanced CSV headers with additional analysis columns
        FileWrite(g_csv_handle,
            "timestamp", "action", "ticket", "position_id", "symbol", "type", "lots", "price",
            "sl", "tp", "profit", "comment", "strategy", "session", "state_before",
            "adx", "atr", "range_high", "range_low", "range_pts", "buffer_pts", "reason",
            "mae", "mfe", "entry_mode", "spread_pts", "vwap", "vwap_sd", "vwap_slope",
            "tp1_price", "tp2_price", "bias_direction", "deal_reason", "is_full_close",
            "stop_price", "limit_price"
        );

        // Print full file path
        string common_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH);
        string full_path = common_path + "\\Files\\" + g_csv_filename;
        Print("CSV file created: ", g_csv_filename);
        Print("Full path: ", full_path);
        FileFlush(g_csv_handle);
    } else {
        Print("ERROR: Failed to create CSV file: ", g_csv_filename);
        Print("Error code: ", GetLastError());
        g_csv_enabled = false; // Disable CSV writing on error
    }
}

void WriteTradeToCSV(ulong ticket, string action, double price, double lots, string comment,
                    ulong position_id = 0, string reason = "", string state_before = "", double trade_profit = 0,
                    ENUM_DEAL_REASON deal_reason = DEAL_REASON_CLIENT, bool is_full_close = true,
                    double stop_price = 0, double limit_price = 0) {
    if(g_csv_handle == INVALID_HANDLE || !g_csv_enabled) return;

    TradeMeta meta;
    string strategy = "ORB";
    string session = "UNKNOWN";
    double sl = 0, tp = 0;
    double mae = 0, mfe = 0; // Max Adverse/Favorable Excursion

    // Get trade metadata
    ulong lookup_key = (position_id > 0) ? position_id : ticket;
    if(GetTradeMeta(lookup_key, meta)) {
        session = EnumToString(meta.session);
        sl = meta.sl_price;
        tp = meta.tp_price;

        // For CANCEL/EXPIRE events, use pending order prices from meta if not provided
        if((action == "CANCEL" || action == "EXPIRE") && stop_price == 0 && limit_price == 0) {
            stop_price = meta.open_price; // For regular stops, this is the stop price
            // For stop-limit orders, limit price would be stored separately (handled in calling code)
        }
    }

    // Use profit directly from parameter (passed from OnTradeTransaction)
    double profit = trade_profit;

    // Get current market data for additional columns
    double current_adx = g_cache.Warmed ? g_cache.ADX : 0;
    double current_atr = g_cache.Warmed ? g_cache.ATR : 0;
    double range_pts = Pts(g_range_high - g_range_low);
    double buffer_pts = current_atr * Inp_ORB_BufferATR;

    // Calculate current spread
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double spread_pts = Pts(ask - bid);

    // Get VWAP data
    double vwap = g_cache.VWAP;
    double vwap_sd = g_cache.VWAP_SD;
    double vwap_slope = g_cache.VWAP_Slope;

    // Entry mode string
    string entry_mode = EnumToString(Inp_ORB_EntryMode);

    // Bias direction string
    string bias_dir = "NONE";
    if(g_allowed_direction == BIAS_BUY_ONLY) bias_dir = "BUY_ONLY";
    else if(g_allowed_direction == BIAS_SELL_ONLY) bias_dir = "SELL_ONLY";

    if(state_before == "") state_before = EnumToString(g_state);

    // Improved type mapping based on action
    string type_column = "";
    if(action == "BUY" || action == "SELL") {
        type_column = action; // "BUY" or "SELL" for entries
    } else if(action == "PENDING") {
        type_column = "PENDING";
    } else if(action == "CLOSE") {
        type_column = "CLOSE";
    } else if(action == "PARTIAL") {
        type_column = "PARTIAL";
    } else if(action == "CANCEL") {
        type_column = "CANCEL";
    } else if(action == "EXPIRE") {
        type_column = "EXPIRE";
    } else if(action == "INFO") {
        type_column = "INFO"; // For trail updates, etc.
    } else {
        type_column = action; // Use action as-is for any other cases
    }

    FileWrite(g_csv_handle,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
        action,
        IntegerToString(ticket),
        IntegerToString(position_id),
        _Symbol,
        type_column,
        DoubleToString(lots, 2),
        DoubleToString(price, _Digits),
        DoubleToString(sl, _Digits),
        DoubleToString(tp, _Digits),
        DoubleToString(profit, 2),
        comment,
        strategy,
        session,
        state_before,
        DoubleToString(current_adx, 2),
        DoubleToString(current_atr, _Digits),
        DoubleToString(g_range_high, _Digits),
        DoubleToString(g_range_low, _Digits),
        DoubleToString(range_pts, 1),
        DoubleToString(buffer_pts, _Digits),
        reason,
        DoubleToString(mae, _Digits),
        DoubleToString(mfe, _Digits),
        entry_mode,
        DoubleToString(spread_pts, 1),
        DoubleToString(vwap, _Digits),
        DoubleToString(vwap_sd, _Digits),
        DoubleToString(vwap_slope, _Digits),
        DoubleToString(g_tp1_price, _Digits),
        DoubleToString(g_tp2_price, _Digits),
        bias_dir,
        EnumToString(deal_reason),
        is_full_close ? "TRUE" : "FALSE",
        DoubleToString(stop_price, _Digits),
        DoubleToString(limit_price, _Digits)
    );
    FileFlush(g_csv_handle);
}

//+------------------------------------------------------------------+
//| Order Management Helper Functions                                |
//+------------------------------------------------------------------+
void SafeCancel(ulong ticket, string whichSide) {
    // Return immediately if ticket is 0
    if(ticket == 0) return;

    // Check if order exists in orders pool and is in valid state
    if(OrderSelect(ticket)) {
        ENUM_ORDER_STATE order_state = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
        if(order_state == ORDER_STATE_PLACED || order_state == ORDER_STATE_STARTED) {
            // Order is valid for cancellation
            if(!g_trade.OrderDelete(ticket)) {
                // Only log if there was an actual error (not "order not found")
                uint error_code = GetLastError();
                if(error_code != TRADE_RETCODE_INVALID_ORDER && Inp_LogVerbose) {
                    Print("SafeCancel warning for ", whichSide, " ticket ", ticket, ": ", error_code);
                }
            }
        }
    }

    // Always reset the corresponding global ticket regardless of outcome
    if(whichSide == "BUY") {
        g_pend_buy = 0;
    } else if(whichSide == "SELL") {
        g_pend_sell = 0;
    }
}

bool NormalizeAndValidatePending(string side, double& entry, double& sl, double& tp) {
    // Normalize all prices to _Digits and SYMBOL_TRADE_TICK_SIZE
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tick_size <= 0) tick_size = _Point;

    entry = NormalizeDouble(MathRound(entry / tick_size) * tick_size, _Digits);
    sl = NormalizeDouble(MathRound(sl / tick_size) * tick_size, _Digits);
    tp = NormalizeDouble(MathRound(tp / tick_size) * tick_size, _Digits);

    // Store original distances before any adjustments
    double original_sl_dist, original_tp_dist;
    if(side == "BUY") {
        original_sl_dist = entry - sl;  // Distance from entry to SL (positive)
        original_tp_dist = tp - entry;  // Distance from entry to TP (positive)
    } else {
        original_sl_dist = sl - entry;  // Distance from entry to SL (positive)
        original_tp_dist = entry - tp;  // Distance from entry to TP (positive)
    }

    // Get stops and freeze levels
    int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    int min_dist_pts = MathMax(stops_level, freeze_level) + 2; // Small buffer
    double min_dist = min_dist_pts * _Point;

    // Get current prices
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    if(side == "BUY") {
        // BuyStop: entry must be >= Ask + MinDist
        double min_entry = ask + min_dist;
        if(entry < min_entry) {
            if(Inp_LogVerbose) {
                Print("ORB NormalizeAndValidatePending BUY: Adjusting entry from ", DoubleToString(entry, _Digits),
                      " to ", DoubleToString(min_entry, _Digits), " due to minimum distance");
            }

            // Adjust entry upward
            entry = NormalizeDouble(min_entry, _Digits);

            // Recalculate SL/TP based on new entry, preserving original distances
            sl = NormalizeDouble(entry - original_sl_dist, _Digits);
            tp = NormalizeDouble(entry + original_tp_dist, _Digits);
        }

        // Validate that SL and TP respect minimum distance requirements from new entry
        if((entry - sl) < min_dist) {
            if(Inp_LogVerbose) {
                Print("ORB NormalizeAndValidatePending BUY: SL distance violation. Entry-SL=",
                      DoubleToString(entry - sl, _Digits), " < MinDist=", DoubleToString(min_dist, _Digits));
            }
            return false;
        }
        if((tp - entry) < min_dist) {
            if(Inp_LogVerbose) {
                Print("ORB NormalizeAndValidatePending BUY: TP distance violation. TP-Entry=",
                      DoubleToString(tp - entry, _Digits), " < MinDist=", DoubleToString(min_dist, _Digits));
            }
            return false;
        }
    }
    else if(side == "SELL") {
        // SellStop: entry must be <= Bid - MinDist
        double max_entry = bid - min_dist;
        if(entry > max_entry) {
            if(Inp_LogVerbose) {
                Print("ORB NormalizeAndValidatePending SELL: Adjusting entry from ", DoubleToString(entry, _Digits),
                      " to ", DoubleToString(max_entry, _Digits), " due to minimum distance");
            }

            // Adjust entry downward
            entry = NormalizeDouble(max_entry, _Digits);

            // Recalculate SL/TP based on new entry, preserving original distances
            sl = NormalizeDouble(entry + original_sl_dist, _Digits);
            tp = NormalizeDouble(entry - original_tp_dist, _Digits);
        }

        // Validate that SL and TP respect minimum distance requirements from new entry
        if((sl - entry) < min_dist) {
            if(Inp_LogVerbose) {
                Print("ORB NormalizeAndValidatePending SELL: SL distance violation. SL-Entry=",
                      DoubleToString(sl - entry, _Digits), " < MinDist=", DoubleToString(min_dist, _Digits));
            }
            return false;
        }
        if((entry - tp) < min_dist) {
            if(Inp_LogVerbose) {
                Print("ORB NormalizeAndValidatePending SELL: TP distance violation. Entry-TP=",
                      DoubleToString(entry - tp, _Digits), " < MinDist=", DoubleToString(min_dist, _Digits));
            }
            return false;
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| ORB Strategy Functions                                           |
//+------------------------------------------------------------------+
bool IsEligible(SessionId session) {
    if(session != SES_LONDON && session != SES_NY) return false;
    if(!g_cache.Warmed) return false;
    if(g_cache.ADX < Inp_ORB_ADX_Min || g_cache.ADX > Inp_ORB_ADX_Max) return false;
    if(TimeCurrent() < g_next_arm_time) return false;
    if(g_state != M_IDLE) return false;

    // Spread guard filter
    if(!CheckSpreadFilter()) return false;

    // VWAP filter (must be called after bias filter to combine properly)
    if(!CheckVWAPFilter(session)) return false;

    // Check one trade per session
    if(session == SES_LONDON && g_london_traded) return false;
    if(session == SES_NY && g_ny_traded) return false;

    // Check session subwindow timing with GMT offset
    datetime server_time = TimeCurrent();
    datetime gmt_time = server_time - Inp_BrokerGMT_Offset * 3600;

    MqlDateTime dt;
    TimeToStruct(gmt_time, dt);

    datetime session_start;
    MqlDateTime session_dt = dt;
    if(session == SES_LONDON) {
        session_dt.hour = Inp_LondonOpen_H;
        session_dt.min = Inp_LondonOpen_M;
    } else {
        session_dt.hour = Inp_NYOpen_H;
        session_dt.min = Inp_NYOpen_M;
    }
    session_dt.sec = 0;
    session_start = StructToTime(session_dt);

    int minutes_from_open = (int)((gmt_time - session_start) / 60);

    if(session == SES_LONDON) {
        if(minutes_from_open < Inp_LO_MinFromOpen || minutes_from_open > Inp_LO_MaxFromOpen) {
            return false;
        }
    } else if(session == SES_NY) {
        if(minutes_from_open < Inp_NY_MinFromOpen || minutes_from_open > Inp_NY_MaxFromOpen) {
            return false;
        }
    }

    // Bias filter
    g_allowed_direction = BIAS_NONE;
    if(Inp_ORB_UseBias) {
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

        // Safety check: Validate SMA and EMA values
        if(g_cache.SMA_Bias <= 0 || g_cache.EMA_Bias <= 0) {
            if(Inp_LogVerbose) {
                Print("ORB Bias filter: Invalid SMA or EMA values. SMA=", DoubleToString(g_cache.SMA_Bias, _Digits),
                      " EMA=", DoubleToString(g_cache.EMA_Bias, _Digits));
            }
            return false;
        }

        // Calculate EMA slope: EMA[1] - EMA[1+SlopeBars] (most recent closed bar vs older bar)
        double ema_buffer[20]; // Fixed size array for EMA slope calculation
        int ema_bars_needed = MathMin(Inp_Bias_EMA_SlopeBars + 1, 20); // Limit to array size

        // Ensure we have enough bars for slope calculation
        if(ema_bars_needed < 2) {
            if(Inp_LogVerbose) {
                Print("ORB Bias filter: Insufficient SlopeBars setting. SlopeBars=", Inp_Bias_EMA_SlopeBars);
            }
            return false;
        }

        // Copy EMA buffer starting from shift=1 (most recent closed bar)
        int copied = CopyBuffer(g_cache.EMA_Handle, 0, 1, ema_bars_needed, ema_buffer);
        if(copied <= 0) {
            if(Inp_LogVerbose) {
                Print("ORB Bias filter: Failed to copy EMA buffer. Error=", GetLastError());
            }
            return false;
        }

        // Verify we have enough data points for slope calculation
        if(copied < ema_bars_needed) {
            if(Inp_LogVerbose) {
                Print("ORB Bias filter: Insufficient EMA data. Requested=", ema_bars_needed,
                      " Received=", copied);
            }
            return false;
        }

        // Calculate slope: EMA[1] - EMA[1+SlopeBars]
        // ema_buffer[0] = EMA at shift=1 (most recent closed bar)
        // ema_buffer[SlopeBars] = EMA at shift=1+SlopeBars (older bar)
        int slope_index = MathMin(Inp_Bias_EMA_SlopeBars, copied - 1); // Ensure valid index
        double ema_slope = ema_buffer[0] - ema_buffer[slope_index];

        if(Inp_LogVerbose) {
            Print("ORB Bias filter: EMA slope calculation - Recent EMA=", DoubleToString(ema_buffer[0], _Digits),
                  " Older EMA=", DoubleToString(ema_buffer[slope_index], _Digits),
                  " Slope=", DoubleToString(ema_slope, _Digits), " over ", slope_index + 1, " bars");
        }

        // Determine allowed direction with enhanced logic and logging
        bool bid_above_sma = (bid >= g_cache.SMA_Bias);
        bool bid_below_sma = (bid <= g_cache.SMA_Bias);
        bool ema_slope_positive = (ema_slope >= 0);
        bool ema_slope_negative = (ema_slope <= 0);

        if(Inp_LogVerbose) {
            Print("ORB Bias filter conditions: Bid=", DoubleToString(bid, _Digits),
                  " SMA=", DoubleToString(g_cache.SMA_Bias, _Digits),
                  " EMA_slope=", DoubleToString(ema_slope, _Digits),
                  " BidAboveSMA=", (bid_above_sma ? "Yes" : "No"),
                  " EMASlopePositive=", (ema_slope_positive ? "Yes" : "No"));
        }

        // BUY condition: Bid >= SMA AND EMA slope >= 0 (uptrend)
        if(bid_above_sma && ema_slope_positive) {
            g_allowed_direction = BIAS_BUY_ONLY;
            if(Inp_LogVerbose) {
                Print("ORB Bias filter: BUY_ONLY allowed - Bid above SMA and EMA slope positive");
            }
        }
        // SELL condition: Bid <= SMA AND EMA slope <= 0 (downtrend)
        else if(bid_below_sma && ema_slope_negative) {
            g_allowed_direction = BIAS_SELL_ONLY;
            if(Inp_LogVerbose) {
                Print("ORB Bias filter: SELL_ONLY allowed - Bid below SMA and EMA slope negative");
            }
        }
        // No valid direction - explain why
        else {
            g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;

            if(Inp_LogVerbose) {
                string rejection_reason = "";
                if(bid_above_sma && !ema_slope_positive) {
                    rejection_reason = "Bid above SMA but EMA slope negative";
                } else if(bid_below_sma && !ema_slope_negative) {
                    rejection_reason = "Bid below SMA but EMA slope positive";
                } else if(!bid_above_sma && !bid_below_sma) {
                    rejection_reason = "Bid exactly at SMA level";
                } else {
                    rejection_reason = "Mixed conditions - no clear direction";
                }

                Print("ORB Bias filter: No valid direction - ", rejection_reason,
                      ". Bid=", DoubleToString(bid, _Digits),
                      " SMA=", DoubleToString(g_cache.SMA_Bias, _Digits),
                      " EMA_slope=", DoubleToString(ema_slope, _Digits));
            }
            return false;
        }
    } else {
        // No bias filter - allow both directions
        g_allowed_direction = BIAS_NONE;
        if(Inp_LogVerbose) {
            Print("ORB Bias filter: DISABLED - Both directions allowed");
        }
    }

    return true;
}

bool Arm(SessionId session) {
    // Calculate range from session start with GMT offset
    datetime server_time = TimeCurrent();
    datetime gmt_time = server_time - Inp_BrokerGMT_Offset * 3600;

    MqlDateTime dt;
    TimeToStruct(gmt_time, dt);

    datetime session_start;
    if(session == SES_LONDON) {
        dt.hour = Inp_LondonOpen_H;
        dt.min = Inp_LondonOpen_M;
    } else {
        dt.hour = Inp_NYOpen_H;
        dt.min = Inp_NYOpen_M;
    }
    dt.sec = 0;
    session_start = StructToTime(dt);

    // Convert session_start back to server time for bar calculations
    datetime session_start_server = session_start + Inp_BrokerGMT_Offset * 3600;

    // Validate session_start is reasonable (not too far in past/future)
    datetime current_time = TimeCurrent();
    int session_age_hours = (int)((current_time - session_start_server) / 3600);
    if(session_age_hours < -24 || session_age_hours > 48) {
        if(Inp_LogVerbose) {
            Print("ORB Arm: Invalid session_start time - ", session_age_hours, " hours from current time. Session: ",
                  TimeToString(session_start_server, TIME_DATE|TIME_MINUTES));
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    // Align window with closed M1 bars using server time
    int first_bar = iBarShift(_Symbol, PERIOD_M1, session_start_server, true);
    int end_bar = iBarShift(_Symbol, PERIOD_M1, session_start_server + Inp_ORB_RangeMin * 60, true);

    // Handle iBarShift() returning -1 (bar not found)
    if(first_bar == -1) {
        if(Inp_LogVerbose) {
            Print("ORB Arm: Cannot find M1 bar for session start time: ",
                  TimeToString(session_start_server, TIME_DATE|TIME_MINUTES));
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    if(end_bar == -1) {
        if(Inp_LogVerbose) {
            Print("ORB Arm: Cannot find M1 bar for range end time: ",
                  TimeToString(session_start_server + Inp_ORB_RangeMin * 60, TIME_DATE|TIME_MINUTES));
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    int count = first_bar - end_bar + 1;

    // Validate we have sufficient M1 bars available
    int available_bars = iBars(_Symbol, PERIOD_M1);
    if(available_bars < first_bar + 1) {
        if(Inp_LogVerbose) {
            Print("ORB Arm: Insufficient M1 bars available. Need: ", first_bar + 1, ", Available: ", available_bars);
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    // Reject if insufficient bars for range calculation
    if(count < 3) {
        if(Inp_LogVerbose) {
            Print("ORB Arm: Insufficient bars for range calculation: count=", count, ", need minimum 3");
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    // Get range high/low over count bars from end_bar
    int highest_bar = iHighest(_Symbol, PERIOD_M1, MODE_HIGH, count, end_bar);
    int lowest_bar = iLowest(_Symbol, PERIOD_M1, MODE_LOW, count, end_bar);

    // Validate iHighest/iLowest results
    if(highest_bar == -1 || lowest_bar == -1) {
        if(Inp_LogVerbose) {
            Print("ORB Arm: Failed to find highest/lowest bars. Highest: ", highest_bar, ", Lowest: ", lowest_bar);
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    g_range_high = iHigh(_Symbol, PERIOD_M1, highest_bar);
    g_range_low = iLow(_Symbol, PERIOD_M1, lowest_bar);

    // Validate range values
    if(g_range_high <= 0 || g_range_low <= 0) {
        if(Inp_LogVerbose) {
            Print("ORB Arm: Invalid range values. High: ", DoubleToString(g_range_high, _Digits),
                  ", Low: ", DoubleToString(g_range_low, _Digits));
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    // Check that range_high > range_low
    if(g_range_high <= g_range_low) {
        if(Inp_LogVerbose) {
            Print("ORB Arm: Invalid range - High (", DoubleToString(g_range_high, _Digits),
                  ") <= Low (", DoubleToString(g_range_low, _Digits), ")");
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    double range_pts = Pts(g_range_high - g_range_low);
    if(range_pts < 10) { // Minimum range check
        if(Inp_LogVerbose) {
            Print("ORB Arm: Range too small: ", DoubleToString(range_pts, 1), " points (minimum: 10)");
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    // Validate ATR before using in calculations
    if(g_cache.ATR <= 0) {
        if(Inp_LogVerbose) {
            Print("ORB Arm: Invalid ATR value: ", DoubleToString(g_cache.ATR, _Digits), " (must be > 0)");
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    // Range sanity vs ATR
    double atr_pts = Pts(g_cache.ATR);
    if(atr_pts <= 0) {
        if(Inp_LogVerbose) {
            Print("ORB Arm: Invalid ATR points: ", DoubleToString(atr_pts, 1), " (ATR: ",
                  DoubleToString(g_cache.ATR, _Digits), ")");
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    double range_atr_ratio = range_pts / atr_pts;

    if(range_atr_ratio < Inp_ORB_RangeATR_Min || range_atr_ratio > Inp_ORB_RangeATR_Max) {
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        if(Inp_LogVerbose) {
            Print("ORB Arm: Range/ATR ratio out of bounds: ", DoubleToString(range_atr_ratio, 3),
                  " (limits: ", DoubleToString(Inp_ORB_RangeATR_Min, 2), "-", DoubleToString(Inp_ORB_RangeATR_Max, 2),
                  ") | Range: ", DoubleToString(range_pts, 1), " pts, ATR: ", DoubleToString(atr_pts, 1), " pts");
        }
        return false;
    }

    // ChopGuard: Calculate range efficiency
    double sum_tr = 0;
    int valid_bars = 0;

    for(int i = end_bar; i <= first_bar; i++) {
        double high = iHigh(_Symbol, PERIOD_M1, i);
        double low = iLow(_Symbol, PERIOD_M1, i);
        double close_prev = (i < first_bar) ? iClose(_Symbol, PERIOD_M1, i + 1) : iClose(_Symbol, PERIOD_M1, i);

        // Validate bar data
        if(high <= 0 || low <= 0 || close_prev <= 0 || high < low) {
            if(Inp_LogVerbose) {
                Print("ORB Arm: Invalid bar data at index ", i, " - High: ", DoubleToString(high, _Digits),
                      ", Low: ", DoubleToString(low, _Digits), ", Close_prev: ", DoubleToString(close_prev, _Digits));
            }
            continue; // Skip invalid bar
        }

        double tr = MathMax(high - low, MathMax(MathAbs(high - close_prev), MathAbs(low - close_prev)));
        sum_tr += tr;
        valid_bars++;
    }

    // Ensure we have enough valid bars for efficiency calculation
    if(valid_bars < 2) {
        if(Inp_LogVerbose) {
            Print("ORB Arm: Insufficient valid bars for efficiency calculation: ", valid_bars, " (need minimum 2)");
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    double efficiency = (sum_tr > 0) ? (g_range_high - g_range_low) / sum_tr : 0;

    if(efficiency < Inp_ORB_EfficiencyMin) {
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        if(Inp_LogVerbose) {
            Print("ORB Arm: Range efficiency too low: ", DoubleToString(efficiency, 4),
                  " (minimum required: ", DoubleToString(Inp_ORB_EfficiencyMin, 3),
                  ") | Range: ", DoubleToString(g_range_high - g_range_low, _Digits),
                  ", Sum TR: ", DoubleToString(sum_tr, _Digits), ", Bars: ", count);
        }
        return false;
    }

    // Calculate entry levels with buffer
    double buffer_pts = g_cache.ATR * Inp_ORB_BufferATR;
    double buy_entry = g_range_high + buffer_pts;
    double sell_entry = g_range_low - buffer_pts;

    // Calculate SL/TP levels
    double sl_pts = g_cache.ATR * Inp_ORB_SL_ATR;
    double tp1_pts = g_cache.ATR * Inp_ORB_TP1_ATR;

    double buy_sl = buy_entry - sl_pts;
    double buy_tp = buy_entry + tp1_pts;
    double sell_sl = sell_entry + sl_pts;
    double sell_tp = sell_entry - tp1_pts;

    // Calculate lot size - pass actual price distance, not points
    double lots = CalculateLotSize(Inp_RiskPct, sl_pts);
    if(lots <= 0) {
        if(Inp_LogVerbose) Print("ORB Arm: Failed to calculate lot size, aborting arm");
        return false;
    }

    // Protect against race/duplicate placement - only place if both tickets are 0
    if(g_pend_buy != 0 || g_pend_sell != 0) {
        if(Inp_LogVerbose) Print("ORB Arm: Pending orders already exist, skipping placement");
        return false;
    }

    // No-touch arming: check gap from current price to entry levels
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double min_gap = Inp_ORB_MinGapFromEntryPts * _Point;

    double buy_gap = buy_entry - ask;
    double sell_gap = bid - sell_entry;

    if(buy_gap < min_gap || sell_gap < min_gap) {
        // Too close to entry levels, postpone
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        if(Inp_LogVerbose) {
            Print("ORB Arm: Entry levels too close to market (Buy gap: ", DoubleToString(Pts(buy_gap), 1),
                  ", Sell gap: ", DoubleToString(Pts(sell_gap), 1), " pts), postponing");
        }
        return false;
    }

    // Place pending orders using the new system
    datetime expire_time = TimeCurrent() + Inp_ORB_ExpireMin * 60;
    bool success = PlacePendingOrders(session, buy_entry, sell_entry, buy_sl, sell_sl, buy_tp, sell_tp, lots, expire_time);

    if(success) {
        g_arm_time = TimeCurrent();
        g_armed_session = session;
        if(Inp_LogVerbose) {
            Print("ORB Armed Successfully:");
            Print("  Range: ", DoubleToString(g_range_low, _Digits), " - ", DoubleToString(g_range_high, _Digits),
                  " (", DoubleToString(range_pts, 1), " pts)");
            Print("  ATR: ", DoubleToString(g_cache.ATR, _Digits), " (", DoubleToString(atr_pts, 1), " pts)");
            Print("  Range/ATR Ratio: ", DoubleToString(range_atr_ratio, 3));
            Print("  Efficiency: ", DoubleToString(efficiency, 4), " (", valid_bars, " valid bars)");
            Print("  Orders: Buy=", g_pend_buy, ", Sell=", g_pend_sell, ", Lots=", DoubleToString(lots, 2));
        }
        return true;
    } else {
        if(Inp_LogVerbose) {
            Print("ORB Arm: Failed to place pending orders");
        }
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }
}

void OnTickArmed(SessionId current_session) {
    bool expire_hit = (TimeCurrent() - g_arm_time) > Inp_ORB_ExpireMin * 60;
    bool session_mismatch = (Inp_ORB_CancelOutOfSession && current_session != g_armed_session);

    if(expire_hit || session_mismatch) {
        // Determine disarm reason for logging
        string disarm_reason = "";
        if(expire_hit) disarm_reason = "EXPIRE";
        else if(session_mismatch) disarm_reason = "SESSION_MISMATCH";

        // Log disarm events to CSV before cancellation
        if(g_csv_enabled) {
            if(g_pend_buy > 0) {
                // Get pending order prices for logging
                double buy_stop_price = 0, buy_limit_price = 0;
                if(OrderSelect(g_pend_buy)) {
                    ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                    buy_stop_price = OrderGetDouble(ORDER_PRICE_OPEN);

                    // For stop-limit orders, get the limit price from ORDER_PRICE_STOPLIMIT
                    if(order_type == ORDER_TYPE_BUY_STOP_LIMIT || order_type == ORDER_TYPE_SELL_STOP_LIMIT) {
                        buy_limit_price = OrderGetDouble(ORDER_PRICE_STOPLIMIT);
                    }
                }

                string action_type = expire_hit ? "EXPIRE" : "CANCEL";
                WriteTradeToCSV(g_pend_buy, action_type, 0, 0, "BUY_CANCELLED", 0, disarm_reason, "M_ARMED",
                              0, DEAL_REASON_CLIENT, true, buy_stop_price, buy_limit_price);
            }
            if(g_pend_sell > 0) {
                // Get pending order prices for logging
                double sell_stop_price = 0, sell_limit_price = 0;
                if(OrderSelect(g_pend_sell)) {
                    ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                    sell_stop_price = OrderGetDouble(ORDER_PRICE_OPEN);

                    // For stop-limit orders, get the limit price from ORDER_PRICE_STOPLIMIT
                    if(order_type == ORDER_TYPE_BUY_STOP_LIMIT || order_type == ORDER_TYPE_SELL_STOP_LIMIT) {
                        sell_limit_price = OrderGetDouble(ORDER_PRICE_STOPLIMIT);
                    }
                }

                string action_type = expire_hit ? "EXPIRE" : "CANCEL";
                WriteTradeToCSV(g_pend_sell, action_type, 0, 0, "SELL_CANCELLED", 0, disarm_reason, "M_ARMED",
                              0, DEAL_REASON_CLIENT, true, sell_stop_price, sell_limit_price);
            }
        }

        // Cancel pending orders using SafeCancel
        SafeCancel(g_pend_buy, "BUY");
        SafeCancel(g_pend_sell, "SELL");

        g_state = M_DONE;
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;

        if(Inp_LogVerbose) {
            Print("ORB disarmed - Expire:", expire_hit, " Session:", session_mismatch);
        }
        return;
    }

    // Fill detection is now handled by OnTradeTransaction only
    // No ADX-based disarming after arm - ADX only used in IsEligible before arm
}

void OnTickActive() {
    // Check if position is still open
    if(PositionsTotal() == 0) {
        g_state = M_DONE;
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        g_active_position_id = 0;
        return;
    }

    // Time stop based on input parameter
    if((TimeCurrent() - g_active_start_time) > Inp_ORB_TimeStopMin * 60) {
        if(PositionSelectByTicket(g_active_position_id)) {
            g_trade.PositionClose(g_active_position_id);
            if(g_csv_enabled) {
                WriteTradeToCSV(g_active_position_id, "CLOSE", PositionGetDouble(POSITION_PRICE_CURRENT),
                              PositionGetDouble(POSITION_VOLUME), "TIME_STOP", g_active_position_id, "TIME_STOP", "M_ACTIVE",
                              0, DEAL_REASON_CLIENT, true, 0, 0);
            }
            if(Inp_LogVerbose) Print("ORB Position closed by ", Inp_ORB_TimeStopMin, "-minute timestop");
        }
        return;
    }

    // TP1-partial + Break-Even + TP2 logic
    if(!g_partial_executed && PositionSelectByTicket(g_active_position_id)) {
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        }

        TradeMeta meta;
        if(GetTradeMeta(g_active_position_id, meta)) {
            double tp1_price = meta.tp_price; // This is TP1 from the stored meta
            bool tp1_hit = false;

            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                tp1_hit = (current_price >= tp1_price);
            } else {
                tp1_hit = (current_price <= tp1_price);
            }

            if(tp1_hit) {
                // Execute partial close
                double current_volume = PositionGetDouble(POSITION_VOLUME);
                double partial_volume = current_volume * Inp_ORB_PartialPct;
                partial_volume = NormalizeVolume(partial_volume);

                if(partial_volume > 0 && partial_volume < current_volume) {
                    if(g_trade.PositionClosePartial(g_active_position_id, partial_volume)) {
                        g_partial_executed = true;

                        // Log partial close to CSV
                        if(g_csv_enabled) {
                            WriteTradeToCSV(g_active_position_id, "PARTIAL", current_price, partial_volume,
                                          "TP1_PARTIAL", g_active_position_id, "TP1_PARTIAL", "M_ACTIVE",
                                          0, DEAL_REASON_CLIENT, false, 0, 0);
                        }

                        // Move SL to Break-Even + Offset
                        double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
                        double new_sl;
                        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                            new_sl = entry_price + Inp_ORB_BE_OffsetPts * _Point;
                        } else {
                            new_sl = entry_price - Inp_ORB_BE_OffsetPts * _Point;
                        }

                        // Calculate and set TP2 for the runner
                        double tp2_distance = g_cache.ATR * Inp_ORB_TP2_ATR;
                        double tp2_price;
                        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                            tp2_price = entry_price + tp2_distance;
                        } else {
                            tp2_price = entry_price - tp2_distance;
                        }

                        // Normalize TP2 price
                        double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                        if(tick_size <= 0) tick_size = _Point;
                        tp2_price = NormalizeDouble(MathRound(tp2_price / tick_size) * tick_size, _Digits);
                        new_sl = NormalizeDouble(MathRound(new_sl / tick_size) * tick_size, _Digits);

                        // Store TP2 price for reference
                        g_tp2_price = tp2_price;

                        // Validate position modification before attempting
                        ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                        if(ValidatePositionModification(new_sl, tp2_price, pos_type, current_price)) {
                            // Modify position with new SL and TP2
                            if(!g_trade.PositionModify(g_active_position_id, new_sl, tp2_price)) {
                                uint error_code = g_trade.ResultRetcode();
                                if(Inp_LogVerbose) {
                                    Print("ORB Position modification failed after partial close: ",
                                          GetRetcodeDescription(error_code), " (", error_code, ")");
                                }
                                // Continue execution - don't abort strategy on modification failure
                            }
                        } else {
                            if(Inp_LogVerbose) {
                                Print("ORB Position modification skipped - validation failed for SL=",
                                      DoubleToString(new_sl, _Digits), " TP2=", DoubleToString(tp2_price, _Digits));
                            }
                        }

                        if(Inp_LogVerbose) {
                            Print("ORB Partial close executed: ", DoubleToString(partial_volume, 2),
                                  " lots at ", DoubleToString(current_price, _Digits),
                                  " | SL moved to BE+", DoubleToString(Inp_ORB_BE_OffsetPts, 0),
                                  " | TP2 set at ", DoubleToString(tp2_price, _Digits));
                        }
                    }
                }
            }
        }
    }

    // ATR Trailing Stop for runner (after partial execution)
    if(g_partial_executed && PositionSelectByTicket(g_active_position_id)) {
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        }

        // Update highest/lowest since entry
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            if(current_price > g_highest_since_entry) {
                g_highest_since_entry = current_price;
            }
        } else {
            if(current_price < g_lowest_since_entry) {
                g_lowest_since_entry = current_price;
            }
        }

        // Calculate trailing stop
        double current_sl = PositionGetDouble(POSITION_SL);
        double atr_trail_dist = g_cache.ATR * Inp_ORB_Trail_ATR;
        double new_sl = current_sl;
        bool should_trail = false;

        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            // BUY: SL = max(current_SL, highest_since_entry - ATR*Trail)
            double trail_sl = g_highest_since_entry - atr_trail_dist;
            if(trail_sl > current_sl) {
                new_sl = trail_sl;
                should_trail = true;
            }
        } else {
            // SELL: SL = min(current_SL, lowest_since_entry + ATR*Trail)
            double trail_sl = g_lowest_since_entry + atr_trail_dist;
            if(trail_sl < current_sl) {
                new_sl = trail_sl;
                should_trail = true;
            }
        }

        if(should_trail) {
            // Normalize the new SL
            double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
            if(tick_size <= 0) tick_size = _Point;
            new_sl = NormalizeDouble(MathRound(new_sl / tick_size) * tick_size, _Digits);

            // Keep existing TP (which should be TP2 after partial execution)
            double current_tp = PositionGetDouble(POSITION_TP);
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            // Validate trailing SL before attempting modification
            if(ValidateStopLoss(new_sl, pos_type, current_price)) {
                if(g_trade.PositionModify(g_active_position_id, new_sl, current_tp)) {
                    // Log trail update to CSV
                    if(g_csv_enabled) {
                        WriteTradeToCSV(g_active_position_id, "INFO", current_price, PositionGetDouble(POSITION_VOLUME),
                                      "TRAIL_SL", g_active_position_id, "TRAIL_SL", "M_ACTIVE",
                                      0, DEAL_REASON_CLIENT, true, 0, 0);
                    }

                    if(Inp_LogVerbose) {
                        Print("ORB Trailing SL updated: ", DoubleToString(new_sl, _Digits),
                              " | ATR Trail: ", DoubleToString(atr_trail_dist, _Digits),
                              " | TP2: ", DoubleToString(current_tp, _Digits));
                    }
                } else {
                    uint error_code = g_trade.ResultRetcode();
                    if(Inp_LogVerbose) {
                        Print("ORB Trailing SL modification failed: ", GetRetcodeDescription(error_code),
                              " (", error_code, ") - continuing with current SL");
                    }
                    // Continue execution - don't treat as critical error
                }
            } else {
                if(Inp_LogVerbose) {
                    Print("ORB Trailing SL skipped - validation failed for new_sl=",
                          DoubleToString(new_sl, _Digits), " current_price=", DoubleToString(current_price, _Digits));
                }
            }
        }
    }
}

void OnExit(bool profit) {
    // Cancel any remaining pending orders using SafeCancel
    SafeCancel(g_pend_buy, "BUY");
    SafeCancel(g_pend_sell, "SELL");

    g_state = M_DONE;
    g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;

    if(Inp_LogVerbose) {
        Print("ORB Exit: ", profit ? "Profit" : "Loss",
              " | Total: ", g_total_wins, "/", g_total_trades,
              " | Win Rate: ", g_total_trades > 0 ? DoubleToString((double)g_total_wins / g_total_trades * 100, 2) : "0.00", "%");
    }
}

//+------------------------------------------------------------------+
//| Filter Functions                                                 |
//+------------------------------------------------------------------+
bool CheckSpreadFilter() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double spread_pts = Pts(ask - bid);

    if(spread_pts > Inp_MaxSpreadPts) {
        if(Inp_LogVerbose) {
            Print("ORB Spread filter: Spread too high: ", DoubleToString(spread_pts, 1),
                  " pts (max: ", Inp_MaxSpreadPts, ")");
        }
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| VWAP Functions                                                   |
//+------------------------------------------------------------------+
void ResetVWAP(SessionId session) {
    g_vwap_session = session;
    g_vwap_sum_pv = 0;
    g_vwap_sum_v = 0;
    g_vwap_count = 0;
    ArrayFill(g_vwap_values, 0, ArraySize(g_vwap_values), 0);

    // Set session start time
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    if(session == SES_LONDON) {
        dt.hour = Inp_LondonOpen_H;
        dt.min = Inp_LondonOpen_M;
    } else if(session == SES_NY) {
        dt.hour = Inp_NYOpen_H;
        dt.min = Inp_NYOpen_M;
    }
    dt.sec = 0;
    g_session_start_time = StructToTime(dt);

    g_cache.VWAP = 0;
    g_cache.VWAP_SD = 0;
    g_cache.VWAP_Slope = 0;
}

void UpdateVWAP(SessionId session) {
    if(!Inp_UseVWAP) return;

    // Reset VWAP if session changed
    if(g_vwap_session != session) {
        ResetVWAP(session);
    }

    // Only calculate VWAP for London and NY sessions
    if(session != SES_LONDON && session != SES_NY) return;

    // Get current M1 bar data
    double high = iHigh(_Symbol, PERIOD_M1, 1);    // Previous closed bar
    double low = iLow(_Symbol, PERIOD_M1, 1);
    double close = iClose(_Symbol, PERIOD_M1, 1);
    long volume = iVolume(_Symbol, PERIOD_M1, 1);

    if(high <= 0 || low <= 0 || close <= 0 || volume <= 0) return;

    // Calculate typical price
    double typical_price = (high + low + close) / 3.0;

    // Update VWAP sums
    g_vwap_sum_pv += typical_price * (double)volume;
    g_vwap_sum_v += (double)volume;

    if(g_vwap_sum_v > 0) {
        g_cache.VWAP = g_vwap_sum_pv / g_vwap_sum_v;

        // Store VWAP value for slope calculation
        if(g_vwap_count < ArraySize(g_vwap_values)) {
            g_vwap_values[g_vwap_count] = g_cache.VWAP;
            g_vwap_count++;
        } else {
            // Shift array and add new value
            for(int i = 0; i < ArraySize(g_vwap_values) - 1; i++) {
                g_vwap_values[i] = g_vwap_values[i + 1];
            }
            g_vwap_values[ArraySize(g_vwap_values) - 1] = g_cache.VWAP;
        }

        // Calculate VWAP slope if we have enough data
        if(g_vwap_count >= Inp_VWAP_SlopeBars && g_vwap_count >= Inp_VWAP_MinBars) {
            int slope_bars = MathMin(Inp_VWAP_SlopeBars, g_vwap_count);
            g_cache.VWAP_Slope = g_vwap_values[g_vwap_count - 1] - g_vwap_values[g_vwap_count - slope_bars];

            if(Inp_LogVerbose && g_vwap_count == Inp_VWAP_SlopeBars) {
                Print("ORB VWAP: Slope calculation now active. Slope=",
                      DoubleToString(g_cache.VWAP_Slope, _Digits), " over ", slope_bars, " bars");
            }
        } else {
            // Reset slope if we don't have enough data
            g_cache.VWAP_Slope = 0;
        }

        // Calculate standard deviation - ensure robust calculation
        int min_sd_bars = MathMax(10, Inp_VWAP_MinBars); // Use at least MinBars or 10, whichever is higher
        if(g_vwap_count >= min_sd_bars) {
            double sum_sq_diff = 0;
            int bars_to_use = MathMin(g_vwap_count, 50); // Use last 50 bars for SD calculation

            for(int i = g_vwap_count - bars_to_use; i < g_vwap_count; i++) {
                double diff = g_vwap_values[i] - g_cache.VWAP;
                sum_sq_diff += diff * diff;
            }

            g_cache.VWAP_SD = MathSqrt(sum_sq_diff / bars_to_use);

            if(Inp_LogVerbose && g_vwap_count == min_sd_bars) {
                Print("ORB VWAP: Standard deviation calculation now active. SD=",
                      DoubleToString(g_cache.VWAP_SD, _Digits), " using ", bars_to_use, " bars");
            }
        } else {
            // Reset SD if we don't have enough data
            g_cache.VWAP_SD = 0;
        }
    }
}

bool CheckVWAPFilter(SessionId session) {
    if(!Inp_UseVWAP) return true; // No filter if VWAP is disabled

    // Only apply VWAP filter for London and NY sessions
    if(session != SES_LONDON && session != SES_NY) return true;

    // Check if we have minimum bars for VWAP filter activation
    if(g_vwap_count < Inp_VWAP_MinBars) {
        if(Inp_LogVerbose) {
            Print("ORB VWAP filter: Insufficient bars for activation. Current: ", g_vwap_count,
                  " Required: ", Inp_VWAP_MinBars);
        }
        return false;
    }

    // Need valid VWAP data
    if(g_cache.VWAP <= 0) {
        if(Inp_LogVerbose) Print("ORB VWAP filter: Invalid VWAP value");
        return false;
    }

    // Allow arming when VWAP data exists but SD not yet calculated (if bars >= MinBars)
    bool has_sd = (g_cache.VWAP_SD > 0);
    bool has_slope = (g_vwap_count >= Inp_VWAP_SlopeBars);

    double current_price = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2.0;

    // Log VWAP status for debugging
    if(Inp_LogVerbose) {
        Print("ORB VWAP Status: VWAP=", DoubleToString(g_cache.VWAP, _Digits),
              " SD=", DoubleToString(g_cache.VWAP_SD, _Digits),
              " Slope=", DoubleToString(g_cache.VWAP_Slope, _Digits),
              " Price=", DoubleToString(current_price, _Digits),
              " Bars=", g_vwap_count);
    }

    // If SD not available yet, allow arming (basic VWAP filter only)
    if(!has_sd) {
        if(Inp_LogVerbose) {
            Print("ORB VWAP filter: SD not yet available, allowing arming with basic VWAP filter");
        }
        // Basic filter: just check if price is above/below VWAP
        bool basic_long = (current_price > g_cache.VWAP);
        bool basic_short = (current_price < g_cache.VWAP);

        if(g_allowed_direction == BIAS_BUY_ONLY && !basic_long) {
            if(Inp_LogVerbose) Print("ORB VWAP filter: Basic long filter failed");
            return false;
        }
        if(g_allowed_direction == BIAS_SELL_ONLY && !basic_short) {
            if(Inp_LogVerbose) Print("ORB VWAP filter: Basic short filter failed");
            return false;
        }
        return true;
    }

    // Full VWAP filter with SD bands
    double vwap_upper = g_cache.VWAP + (g_cache.VWAP_SD * Inp_ORB_VWAP_SD);
    double vwap_lower = g_cache.VWAP - (g_cache.VWAP_SD * Inp_ORB_VWAP_SD);

    // Log VWAP bands
    if(Inp_LogVerbose) {
        Print("ORB VWAP Bands: Upper=", DoubleToString(vwap_upper, _Digits),
              " Lower=", DoubleToString(vwap_lower, _Digits),
              " Price relative to VWAP: ", DoubleToString(current_price - g_cache.VWAP, _Digits));
    }

    // Determine allowed directions based on slope requirement
    bool long_allowed, short_allowed;

    if(Inp_VWAP_RequireSlope && has_slope) {
        // Full filter with slope requirement
        long_allowed = (current_price > vwap_upper && g_cache.VWAP_Slope >= 0);
        short_allowed = (current_price < vwap_lower && g_cache.VWAP_Slope <= 0);
    } else if(!Inp_VWAP_RequireSlope) {
        // Filter without slope requirement
        long_allowed = (current_price > vwap_upper);
        short_allowed = (current_price < vwap_lower);
    } else {
        // Slope required but not available yet - use basic filter
        if(Inp_LogVerbose) {
            Print("ORB VWAP filter: Slope required but not available, using basic filter");
        }
        long_allowed = (current_price > vwap_upper);
        short_allowed = (current_price < vwap_lower);
    }

    // Combine with existing bias filter
    if(g_allowed_direction == BIAS_BUY_ONLY && !long_allowed) {
        if(Inp_LogVerbose) {
            Print("ORB VWAP filter: Long not allowed. Price=", DoubleToString(current_price, _Digits),
                  " VWAP=", DoubleToString(g_cache.VWAP, _Digits),
                  " Upper=", DoubleToString(has_sd ? vwap_upper : g_cache.VWAP, _Digits),
                  " Slope=", DoubleToString(g_cache.VWAP_Slope, _Digits),
                  " SlopeReq=", (Inp_VWAP_RequireSlope ? "Yes" : "No"));
        }
        return false;
    }

    if(g_allowed_direction == BIAS_SELL_ONLY && !short_allowed) {
        if(Inp_LogVerbose) {
            Print("ORB VWAP filter: Short not allowed. Price=", DoubleToString(current_price, _Digits),
                  " VWAP=", DoubleToString(g_cache.VWAP, _Digits),
                  " Lower=", DoubleToString(has_sd ? vwap_lower : g_cache.VWAP, _Digits),
                  " Slope=", DoubleToString(g_cache.VWAP_Slope, _Digits),
                  " SlopeReq=", (Inp_VWAP_RequireSlope ? "Yes" : "No"));
        }
        return false;
    }

    if(g_allowed_direction == BIAS_NONE) {
        // Update allowed direction based on VWAP filter
        if(long_allowed && short_allowed) {
            g_allowed_direction = BIAS_NONE; // Both allowed
            if(Inp_LogVerbose) {
                Print("ORB VWAP filter: Both directions allowed by VWAP conditions");
            }
        } else if(long_allowed) {
            g_allowed_direction = BIAS_BUY_ONLY;
            if(Inp_LogVerbose) {
                Print("ORB VWAP filter: Only LONG allowed by VWAP conditions");
            }
        } else if(short_allowed) {
            g_allowed_direction = BIAS_SELL_ONLY;
            if(Inp_LogVerbose) {
                Print("ORB VWAP filter: Only SHORT allowed by VWAP conditions");
            }
        } else {
            if(Inp_LogVerbose) {
                Print("ORB VWAP filter: No direction allowed by VWAP conditions. Long=",
                      (long_allowed ? "Yes" : "No"), " Short=", (short_allowed ? "Yes" : "No"));
            }
            return false;
        }
    }

    if(Inp_LogVerbose) {
        Print("ORB VWAP filter: PASSED - Final direction: ",
              (g_allowed_direction == BIAS_BUY_ONLY ? "BUY_ONLY" :
               (g_allowed_direction == BIAS_SELL_ONLY ? "SELL_ONLY" : "BOTH")));
    }

    return true;
}

//+------------------------------------------------------------------+
//| Entry Mode Functions                                             |
//+------------------------------------------------------------------+
bool PlacePendingOrders(SessionId session, double buy_entry, double sell_entry, double buy_sl, double sell_sl,
                       double buy_tp1, double sell_tp1, double lots, datetime expire_time) {

    // Check spread filter before any order placement
    if(!CheckSpreadFilter()) {
        if(Inp_LogVerbose) Print("ORB PlacePendingOrders: Spread filter failed, aborting order placement");
        return false;
    }

    bool success = false;

    // Determine which orders to place based on bias direction
    bool place_buy = (g_allowed_direction == BIAS_NONE || g_allowed_direction == BIAS_BUY_ONLY);
    bool place_sell = (g_allowed_direction == BIAS_NONE || g_allowed_direction == BIAS_SELL_ONLY);

    // Validate and normalize pending prices
    double validated_buy_entry = buy_entry, validated_buy_sl = buy_sl, validated_buy_tp = buy_tp1;
    double validated_sell_entry = sell_entry, validated_sell_sl = sell_sl, validated_sell_tp = sell_tp1;

    bool buy_valid = false;
    bool sell_valid = false;

    if(place_buy) {
        buy_valid = NormalizeAndValidatePending("BUY", validated_buy_entry, validated_buy_sl, validated_buy_tp);
        if(!buy_valid && Inp_LogVerbose) {
            Print("ORB PlacePendingOrders: BUY order validation failed - cannot maintain required SL/TP distances");
        }
    }
    if(place_sell) {
        sell_valid = NormalizeAndValidatePending("SELL", validated_sell_entry, validated_sell_sl, validated_sell_tp);
        if(!sell_valid && Inp_LogVerbose) {
            Print("ORB PlacePendingOrders: SELL order validation failed - cannot maintain required SL/TP distances");
        }
    }

    if(!buy_valid && !sell_valid) {
        if(Inp_LogVerbose) Print("ORB PlacePendingOrders: No valid pending prices for allowed direction(s)");
        return false;
    }

    // Place orders based on entry mode
    if(Inp_ORB_EntryMode == ENTRY_STOP) {
        // Classic Stop orders
        if(buy_valid) {
            if(g_trade.BuyStop(lots, validated_buy_entry, _Symbol, validated_buy_sl, 0, // TP=0 for manual management
                              ORDER_TIME_SPECIFIED, expire_time, Inp_EA_Tag + "_BUY")) {
                g_pend_buy = g_trade.ResultOrder();

                // Store trade meta with TP1 price for later use
                TradeMeta meta;
                meta.strategy_short = "ORB";
                meta.session = session;
                meta.lots = lots;
                meta.open_price = validated_buy_entry;
                meta.sl_price = validated_buy_sl;
                meta.tp_price = validated_buy_tp; // Store TP1 price
                meta.remaining_lots = lots;
                meta.open_time = TimeCurrent();
                StoreTradeMeta(g_pend_buy, meta);

                // Log to CSV
                if(g_csv_enabled) {
                    WriteTradeToCSV(g_pend_buy, "PENDING", validated_buy_entry, lots, "BUY_STOP", 0, "", "M_IDLE",
                                  0, DEAL_REASON_CLIENT, true, validated_buy_entry, 0);
                }

                success = true;
            }
        }

        if(sell_valid) {
            if(g_trade.SellStop(lots, validated_sell_entry, _Symbol, validated_sell_sl, 0, // TP=0 for manual management
                               ORDER_TIME_SPECIFIED, expire_time, Inp_EA_Tag + "_SELL")) {
                g_pend_sell = g_trade.ResultOrder();

                // Store trade meta with TP1 price for later use
                TradeMeta meta;
                meta.strategy_short = "ORB";
                meta.session = session;
                meta.lots = lots;
                meta.open_price = validated_sell_entry;
                meta.sl_price = validated_sell_sl;
                meta.tp_price = validated_sell_tp; // Store TP1 price
                meta.remaining_lots = lots;
                meta.open_time = TimeCurrent();
                StoreTradeMeta(g_pend_sell, meta);

                // Log to CSV
                if(g_csv_enabled) {
                    WriteTradeToCSV(g_pend_sell, "PENDING", validated_sell_entry, lots, "SELL_STOP", 0, "", "M_IDLE",
                                  0, DEAL_REASON_CLIENT, true, validated_sell_entry, 0);
                }

                success = true;
            }
        }
    }
    else if(Inp_ORB_EntryMode == ENTRY_STOP_LIMIT) {
        // Stop-Limit orders with retest logic
        double offset_pts = Inp_StopLimit_OffsetPts * _Point;

        if(buy_valid) {
            double limit_price = validated_buy_entry - offset_pts; // Pullback entry for buy

            // Normalize limit price using same tick_size logic
            double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
            if(tick_size <= 0) tick_size = _Point;
            limit_price = NormalizeDouble(MathRound(limit_price / tick_size) * tick_size, _Digits);

            // Validate Stop-Limit relationship: For BUY, Stop > Limit
            if(validated_buy_entry <= limit_price) {
                if(Inp_LogVerbose) {
                    Print("ORB PlacePendingOrders BUY_STOP_LIMIT: Invalid relationship - Stop (",
                          DoubleToString(validated_buy_entry, _Digits), ") must be > Limit (",
                          DoubleToString(limit_price, _Digits), ")");
                }
                // Skip this order
            } else {
                // Validate minimum distance requirements for limit price
                double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
                int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
                int min_dist_pts = MathMax(stops_level, freeze_level) + 2;
                double min_dist = min_dist_pts * _Point;

                // For BuyStopLimit: limit_price should be >= ask + min_dist (when triggered)
                // But we also need to ensure the offset creates a valid limit price
                if((validated_buy_entry - limit_price) < min_dist) {
                    if(Inp_LogVerbose) {
                        Print("ORB PlacePendingOrders BUY_STOP_LIMIT: Limit price too close to stop price. Distance=",
                              DoubleToString(validated_buy_entry - limit_price, _Digits), " < MinDist=",
                              DoubleToString(min_dist, _Digits));
                    }
                    // Skip this order
                } else {
                    // Use OrderSend for BuyStopLimit since CTrade doesn't have this method
                    MqlTradeRequest request = {};
                    MqlTradeResult result = {};

                    request.action = TRADE_ACTION_PENDING;
                    request.type = ORDER_TYPE_BUY_STOP_LIMIT;
                    request.symbol = _Symbol;
                    request.volume = lots;
                    request.price = validated_buy_entry;  // Stop price (already normalized)
                    request.stoplimit = limit_price;      // Limit price (now normalized)
                    request.sl = validated_buy_sl;
                    request.tp = 0; // TP=0 for manual management
                    request.type_time = ORDER_TIME_SPECIFIED;
                    request.expiration = expire_time;
                    request.comment = Inp_EA_Tag + "_BUY_SL";
                    request.magic = Inp_Magic;

                    if(Inp_LogVerbose) {
                        Print("ORB PlacePendingOrders BUY_STOP_LIMIT: Placing order - Stop:",
                              DoubleToString(validated_buy_entry, _Digits), " Limit:",
                              DoubleToString(limit_price, _Digits));
                    }

                    if(OrderSend(request, result)) {
                        if(result.retcode == TRADE_RETCODE_DONE) {
                            g_pend_buy = result.order;

                            // Store trade meta
                            TradeMeta meta;
                            meta.strategy_short = "ORB";
                            meta.session = session;
                            meta.lots = lots;
                            meta.open_price = limit_price; // Store limit price as entry
                            meta.sl_price = validated_buy_sl;
                            meta.tp_price = validated_buy_tp; // Store TP1 price
                            meta.remaining_lots = lots;
                            meta.open_time = TimeCurrent();
                            StoreTradeMeta(g_pend_buy, meta);

                            // Log to CSV
                            if(g_csv_enabled) {
                                WriteTradeToCSV(g_pend_buy, "PENDING", validated_buy_entry, lots, "BUY_STOP_LIMIT", 0,
                                              "Stop:" + DoubleToString(validated_buy_entry, _Digits) +
                                              " Limit:" + DoubleToString(limit_price, _Digits), "M_IDLE",
                                              0, DEAL_REASON_CLIENT, true, validated_buy_entry, limit_price);
                            }

                            success = true;
                        } else {
                            // Handle OrderSend failure with specific error codes
                            if(Inp_LogVerbose) {
                                Print("ORB PlacePendingOrders BUY_STOP_LIMIT: OrderSend failed - RetCode: ",
                                      result.retcode, " (", GetRetcodeDescription(result.retcode), ")");
                            }
                        }
                    } else {
                        // OrderSend function call failed
                        if(Inp_LogVerbose) {
                            Print("ORB PlacePendingOrders BUY_STOP_LIMIT: OrderSend function call failed - Error: ",
                                  GetLastError());
                        }
                    }
                }
            }
        }

        if(sell_valid) {
            double limit_price = validated_sell_entry + offset_pts; // Pullback entry for sell

            // Normalize limit price using same tick_size logic
            double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
            if(tick_size <= 0) tick_size = _Point;
            limit_price = NormalizeDouble(MathRound(limit_price / tick_size) * tick_size, _Digits);

            // Validate Stop-Limit relationship: For SELL, Stop < Limit
            if(validated_sell_entry >= limit_price) {
                if(Inp_LogVerbose) {
                    Print("ORB PlacePendingOrders SELL_STOP_LIMIT: Invalid relationship - Stop (",
                          DoubleToString(validated_sell_entry, _Digits), ") must be < Limit (",
                          DoubleToString(limit_price, _Digits), ")");
                }
                // Skip this order
            } else {
                // Validate minimum distance requirements for limit price
                double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
                int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
                int min_dist_pts = MathMax(stops_level, freeze_level) + 2;
                double min_dist = min_dist_pts * _Point;

                // For SellStopLimit: limit_price should be <= bid - min_dist (when triggered)
                // But we also need to ensure the offset creates a valid limit price
                if((limit_price - validated_sell_entry) < min_dist) {
                    if(Inp_LogVerbose) {
                        Print("ORB PlacePendingOrders SELL_STOP_LIMIT: Limit price too close to stop price. Distance=",
                              DoubleToString(limit_price - validated_sell_entry, _Digits), " < MinDist=",
                              DoubleToString(min_dist, _Digits));
                    }
                    // Skip this order
                } else {
                    // Use OrderSend for SellStopLimit since CTrade doesn't have this method
                    MqlTradeRequest request = {};
                    MqlTradeResult result = {};

                    request.action = TRADE_ACTION_PENDING;
                    request.type = ORDER_TYPE_SELL_STOP_LIMIT;
                    request.symbol = _Symbol;
                    request.volume = lots;
                    request.price = validated_sell_entry;  // Stop price (already normalized)
                    request.stoplimit = limit_price;       // Limit price (now normalized)
                    request.sl = validated_sell_sl;
                    request.tp = 0; // TP=0 for manual management
                    request.type_time = ORDER_TIME_SPECIFIED;
                    request.expiration = expire_time;
                    request.comment = Inp_EA_Tag + "_SELL_SL";
                    request.magic = Inp_Magic;

                    if(Inp_LogVerbose) {
                        Print("ORB PlacePendingOrders SELL_STOP_LIMIT: Placing order - Stop:",
                              DoubleToString(validated_sell_entry, _Digits), " Limit:",
                              DoubleToString(limit_price, _Digits));
                    }

                    if(OrderSend(request, result)) {
                        if(result.retcode == TRADE_RETCODE_DONE) {
                            g_pend_sell = result.order;

                            // Store trade meta
                            TradeMeta meta;
                            meta.strategy_short = "ORB";
                            meta.session = session;
                            meta.lots = lots;
                            meta.open_price = limit_price; // Store limit price as entry
                            meta.sl_price = validated_sell_sl;
                            meta.tp_price = validated_sell_tp; // Store TP1 price
                            meta.remaining_lots = lots;
                            meta.open_time = TimeCurrent();
                            StoreTradeMeta(g_pend_sell, meta);

                            // Log to CSV
                            if(g_csv_enabled) {
                                WriteTradeToCSV(g_pend_sell, "PENDING", validated_sell_entry, lots, "SELL_STOP_LIMIT", 0,
                                              "Stop:" + DoubleToString(validated_sell_entry, _Digits) +
                                              " Limit:" + DoubleToString(limit_price, _Digits), "M_IDLE",
                                              0, DEAL_REASON_CLIENT, true, validated_sell_entry, limit_price);
                            }

                            success = true;
                        } else {
                            // Handle OrderSend failure with specific error codes
                            if(Inp_LogVerbose) {
                                Print("ORB PlacePendingOrders SELL_STOP_LIMIT: OrderSend failed - RetCode: ",
                                      result.retcode, " (", GetRetcodeDescription(result.retcode), ")");
                            }
                        }
                    } else {
                        // OrderSend function call failed
                        if(Inp_LogVerbose) {
                            Print("ORB PlacePendingOrders SELL_STOP_LIMIT: OrderSend function call failed - Error: ",
                                  GetLastError());
                        }
                    }
                }
            }
        }
    }

    return success;
}

void HandleStopLimitEntry() {
    // This function can be used for additional Stop-Limit entry logic if needed
    // Currently, the Stop-Limit logic is handled in PlacePendingOrders
    // and the standard OnTradeTransaction handles the fills
}

//+------------------------------------------------------------------+
//| Get human-readable description for trade return codes           |
//+------------------------------------------------------------------+
string GetRetcodeDescription(uint retcode) {
    switch(retcode) {
        case TRADE_RETCODE_REQUOTE:         return "Requote";
        case TRADE_RETCODE_REJECT:          return "Request rejected";
        case TRADE_RETCODE_CANCEL:          return "Request canceled by trader";
        case TRADE_RETCODE_PLACED:          return "Order placed";
        case TRADE_RETCODE_DONE:            return "Request completed";
        case TRADE_RETCODE_DONE_PARTIAL:    return "Only part of the request was completed";
        case TRADE_RETCODE_ERROR:           return "Request processing error";
        case TRADE_RETCODE_TIMEOUT:         return "Request canceled by timeout";
        case TRADE_RETCODE_INVALID:         return "Invalid request";
        case TRADE_RETCODE_INVALID_VOLUME:  return "Invalid volume in the request";
        case TRADE_RETCODE_INVALID_PRICE:   return "Invalid price in the request";
        case TRADE_RETCODE_INVALID_STOPS:   return "Invalid stops in the request";
        case TRADE_RETCODE_TRADE_DISABLED:  return "Trade is disabled";
        case TRADE_RETCODE_MARKET_CLOSED:   return "Market is closed";
        case TRADE_RETCODE_NO_MONEY:        return "There is not enough money to complete the request";
        case TRADE_RETCODE_PRICE_CHANGED:   return "Prices changed";
        case TRADE_RETCODE_PRICE_OFF:       return "There are no quotes to process the request";
        case TRADE_RETCODE_INVALID_EXPIRATION: return "Invalid order expiration date in the request";
        case TRADE_RETCODE_ORDER_CHANGED:   return "Order state changed";
        case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too frequent requests";
        case TRADE_RETCODE_NO_CHANGES:      return "No changes in request";
        case TRADE_RETCODE_SERVER_DISABLES_AT: return "Autotrading disabled by server";
        case TRADE_RETCODE_CLIENT_DISABLES_AT: return "Autotrading disabled by client terminal";
        case TRADE_RETCODE_LOCKED:          return "Request locked for processing";
        case TRADE_RETCODE_FROZEN:          return "Order or position frozen";
        case TRADE_RETCODE_INVALID_FILL:    return "Invalid order filling type";
        case TRADE_RETCODE_CONNECTION:      return "No connection with the trade server";
        case TRADE_RETCODE_ONLY_REAL:       return "Operation is allowed only for live accounts";
        case TRADE_RETCODE_LIMIT_ORDERS:    return "The number of pending orders has reached the limit";
        case TRADE_RETCODE_LIMIT_VOLUME:    return "The volume of orders and positions for the symbol has reached the limit";
        case TRADE_RETCODE_INVALID_ORDER:   return "Incorrect or prohibited order type";
        case TRADE_RETCODE_POSITION_CLOSED: return "Position with the specified POSITION_IDENTIFIER has already been closed";
        default:                            return "Unknown error code: " + IntegerToString(retcode);
    }
}

//+------------------------------------------------------------------+
//| Position modification validation functions                       |
//+------------------------------------------------------------------+
bool ValidateStopLoss(double new_sl, ENUM_POSITION_TYPE pos_type, double current_price) {
    if(new_sl <= 0) return true; // No SL is valid

    double stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    double freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
    double min_distance = MathMax(stops_level, freeze_level);

    if(pos_type == POSITION_TYPE_BUY) {
        // For BUY positions, SL must be below current price by minimum distance
        if(new_sl >= current_price - min_distance) {
            if(Inp_LogVerbose) {
                Print("SL validation failed for BUY: SL=", DoubleToString(new_sl, _Digits),
                      " too close to price=", DoubleToString(current_price, _Digits),
                      " min_distance=", DoubleToString(min_distance, _Digits));
            }
            return false;
        }
    } else {
        // For SELL positions, SL must be above current price by minimum distance
        if(new_sl <= current_price + min_distance) {
            if(Inp_LogVerbose) {
                Print("SL validation failed for SELL: SL=", DoubleToString(new_sl, _Digits),
                      " too close to price=", DoubleToString(current_price, _Digits),
                      " min_distance=", DoubleToString(min_distance, _Digits));
            }
            return false;
        }
    }
    return true;
}

bool ValidateTakeProfit(double new_tp, ENUM_POSITION_TYPE pos_type, double current_price) {
    if(new_tp <= 0) return true; // No TP is valid

    double stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    double freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
    double min_distance = MathMax(stops_level, freeze_level);

    if(pos_type == POSITION_TYPE_BUY) {
        // For BUY positions, TP must be above current price by minimum distance
        if(new_tp <= current_price + min_distance) {
            if(Inp_LogVerbose) {
                Print("TP validation failed for BUY: TP=", DoubleToString(new_tp, _Digits),
                      " too close to price=", DoubleToString(current_price, _Digits),
                      " min_distance=", DoubleToString(min_distance, _Digits));
            }
            return false;
        }
    } else {
        // For SELL positions, TP must be below current price by minimum distance
        if(new_tp >= current_price - min_distance) {
            if(Inp_LogVerbose) {
                Print("TP validation failed for SELL: TP=", DoubleToString(new_tp, _Digits),
                      " too close to price=", DoubleToString(current_price, _Digits),
                      " min_distance=", DoubleToString(min_distance, _Digits));
            }
            return false;
        }
    }
    return true;
}

bool ValidatePositionModification(double new_sl, double new_tp, ENUM_POSITION_TYPE pos_type, double current_price) {
    return ValidateStopLoss(new_sl, pos_type, current_price) &&
           ValidateTakeProfit(new_tp, pos_type, current_price);
}

double NormalizeVolume(double volume) {
    double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(volume_step <= 0) volume_step = 0.01; // Default step

    double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    // Round to volume step
    volume = MathRound(volume / volume_step) * volume_step;

    // Ensure within bounds
    volume = MathMax(volume, min_volume);
    volume = MathMin(volume, max_volume);

    return volume;
}
