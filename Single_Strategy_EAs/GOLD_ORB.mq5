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
input double Inp_ORB_TP2_ATR = 1.20;              // Take Profit 2 ATR multiplier
input double Inp_ORB_VWAP_SD = 1.0;               // VWAP Standard Deviation
input int Inp_ORB_ADX_Min = 10;                   // ADX Minimum
input int Inp_ORB_ADX_Max = 55;                   // ADX Maximum
input int Inp_ORB_RecalcMin = 3;                  // Recalc minutes
input int Inp_ORB_ExpireMin = 90;                 // Expire minutes
input bool Inp_ORB_CancelOutOfSession = true;     // Cancel out of session
input double Inp_ORB_RangeATR_Min = 0.30;         // Range ATR Min ratio
input double Inp_ORB_RangeATR_Max = 1.20;         // Range ATR Max ratio
input double Inp_ORB_PartialPct = 0.70;           // Partial close % at TP1
input double Inp_ORB_BE_OffsetPts = 5;            // Break-Even offset points
input int Inp_ORB_MinGapFromEntryPts = 20;        // Min gap from current price to entry
input double Inp_ORB_EfficiencyMin = 0.35;        // ChopGuard: Min range efficiency
input int Inp_ORB_TimeStopMin = 30;               // Time stop in minutes
input double Inp_ORB_Trail_ATR = 0.60;            // ATR trailing multiplier for runner

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
input int Inp_NYOpen_H = 14;                      // NY Open Hour
input int Inp_NYOpen_M = 30;                      // NY Open Minute
input int Inp_NYEnd_H = 21;                       // NY End Hour

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

//--- Structures
struct IndCache {
    double ATR;
    double ADX;
    double SMA_Bias;
    double EMA_Bias;
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

//--- Bias filter
enum BiasDirection { BIAS_NONE, BIAS_BUY_ONLY, BIAS_SELL_ONLY };
BiasDirection g_allowed_direction = BIAS_NONE;

//--- One trade per session tracking
bool g_london_traded = false;
bool g_ny_traded = false;

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
double CalculateLotSize(double risk_pct, double sl_points);
bool StoreTradeMeta(ulong ticket, const TradeMeta& meta);
bool GetTradeMeta(ulong ticket, TradeMeta& meta);
void UpdateRiskLimits();
bool IsDayBoundaryReached();
void DoDailyReset();
void InitCSV();
void WriteTradeToCSV(ulong ticket, string action, double price, double lots, string comment,
                    ulong position_id = 0, string reason = "", string state_before = "", double trade_profit = 0);
double Pts(double price_diff);

//--- Order management helpers
void SafeCancel(ulong ticket, string whichSide);
bool NormalizeAndValidatePending(string side, double& entry, double& sl, double& tp);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    // Validate input parameters
    if(Inp_Bias_EMA_SlopeBars > 19) {
        Print("ERROR: Inp_Bias_EMA_SlopeBars cannot exceed 19. Current value: ", Inp_Bias_EMA_SlopeBars);
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

    // Update risk management
    UpdateRiskLimits();
    
    // Check if trading is locked
    if(g_limits.locked_day || g_limits.locked_week) {
        return;
    }
    
    SessionId current_session = GetCurrentSession();

    // Reset session traded flags when session changes
    static SessionId last_session = SES_OFF;
    if(current_session != last_session) {
        if(last_session == SES_LONDON) {
            g_london_traded = false;
        } else if(last_session == SES_NY) {
            g_ny_traded = false;
        }
        last_session = current_session;
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

            // Cancel the opposite pending order using SafeCancel
            if(deal_type == DEAL_TYPE_BUY) {
                SafeCancel(g_pend_sell, "SELL");
            } else if(deal_type == DEAL_TYPE_SELL) {
                SafeCancel(g_pend_buy, "BUY");
            }

            // Copy meta from order_ticket to position_id and sync lots
            TradeMeta meta;
            if(GetTradeMeta(order_ticket, meta)) {
                meta.lots = entry_lots;
                meta.remaining_lots = entry_lots;
                StoreTradeMeta(position_id, meta); // Store by position_id for future reference
            }

            // Clear the triggered pending order
            if(deal_type == DEAL_TYPE_BUY) g_pend_buy = 0;
            else g_pend_sell = 0;

            // Log ENTRY to CSV
            if(g_csv_enabled) {
                string action = (deal_type == DEAL_TYPE_BUY) ? "BUY" : "SELL";
                WriteTradeToCSV(order_ticket, action, entry_price, entry_lots, "ENTRY", position_id, "", "M_ARMED");
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

        // Determine close reason
        string close_reason = "UNKNOWN";
        if(PositionsTotal() == 0) {
            // Check if it was SL, TP, or manual close
            if(HistoryOrderSelect(HistoryDealGetInteger(trans.deal, DEAL_ORDER))) {
                ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(HistoryDealGetInteger(trans.deal, DEAL_ORDER), ORDER_TYPE);
                if(order_type == ORDER_TYPE_BUY_STOP_LIMIT || order_type == ORDER_TYPE_SELL_STOP_LIMIT) {
                    close_reason = "STOP_LOSS";
                } else if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT) {
                    close_reason = "TAKE_PROFIT";
                } else {
                    close_reason = "MARKET_CLOSE";
                }
            }
        }

        // Update statistics
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

        // Log to CSV with position_id for proper tracking
        if(g_csv_enabled) {
            WriteTradeToCSV(deal_ticket, "CLOSE", price, lots,
                          is_profit ? "PROFIT" : "LOSS", position_id, close_reason, "M_ACTIVE", profit);
        }

        // Set session traded flag before exit
        if(g_armed_session == SES_LONDON) {
            g_london_traded = true;
        } else if(g_armed_session == SES_NY) {
            g_ny_traded = true;
        }

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
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    int hour = dt.hour;

    // London session
    if(hour >= Inp_LondonOpen_H && hour < Inp_LondonEnd_H) {
        return SES_LONDON;
    }
    // NY session
    if(hour >= Inp_NYOpen_H && hour < Inp_NYEnd_H) {
        return SES_NY;
    }

    return SES_OFF;
}

bool IsSessionActive(SessionId session) {
    return session == SES_LONDON || session == SES_NY;
}

double CalculateLotSize(double risk_pct, double sl_points) {
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * risk_pct / 100.0;

    // Get symbol properties with fallback values
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);

    // Fallback values for XAUUSD if broker returns 0
    if(tick_value <= 0) {
        tick_value = 1.0; // Fallback for XAUUSD
        if(Inp_LogVerbose) Print("WARNING: Using fallback tick_value = ", tick_value);
    }

    if(tick_size <= 0) {
        tick_size = 0.01; // Fallback for XAUUSD
        if(Inp_LogVerbose) Print("WARNING: Using fallback tick_size = ", tick_size);
    }

    if(contract_size <= 0) {
        contract_size = 100.0; // Fallback for XAUUSD
        if(Inp_LogVerbose) Print("WARNING: Using fallback contract_size = ", contract_size);
    }

    if(sl_points <= 0) {
        if(Inp_LogVerbose) Print("ERROR: Invalid SL points = ", sl_points);
        return 0;
    }

    double lots = risk_amount / (sl_points * tick_value / tick_size);

    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    // Fallback values if broker returns 0
    if(min_lot <= 0) min_lot = 0.01;
    if(max_lot <= 0) max_lot = 100.0;
    if(lot_step <= 0) lot_step = 0.01;

    lots = MathMax(lots, min_lot);
    lots = MathMin(lots, max_lot);
    lots = MathRound(lots / lot_step) * lot_step;

    // Final safety check
    if(lots <= 0) {
        if(Inp_LogVerbose) Print("ERROR: Calculated lot size <= 0, using minimum lot");
        lots = min_lot;
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
    datetime current_time = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(current_time, dt);

    // Create today's day start time
    MqlDateTime day_start_dt = dt;
    day_start_dt.hour = Inp_ServerDayStart;
    day_start_dt.min = 0;
    day_start_dt.sec = 0;
    datetime todays_day_start = StructToTime(day_start_dt);

    // Check if we've passed today's day start and it's a different date than last reset
    if(current_time >= todays_day_start) {
        MqlDateTime reset_dt;
        TimeToStruct(todays_day_start, reset_dt);
        int reset_date = reset_dt.year * 10000 + reset_dt.mon * 100 + reset_dt.day;

        MqlDateTime last_reset_dt;
        TimeToStruct(g_limits.last_reset_date, last_reset_dt);
        int last_reset_date_int = last_reset_dt.year * 10000 + last_reset_dt.mon * 100 + last_reset_dt.day;

        return (reset_date != last_reset_date_int);
    }

    return false;
}

void DoDailyReset() {
    datetime current_time = TimeCurrent();

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
    g_limits.last_reset_date = current_time;

    // Reset ORB state and pending orders
    g_state = M_IDLE;
    g_pend_buy = 0;
    g_pend_sell = 0;
    g_armed_session = SES_OFF;
    g_active_position_id = 0;
    g_partial_executed = false;

    // Check for weekly reset (Monday)
    MqlDateTime dt;
    TimeToStruct(current_time, dt);
    if(dt.day_of_week == 1) { // Monday
        double prev_week_loss = g_limits.week_loss;
        bool was_week_locked = g_limits.locked_week;

        g_limits.week_loss = 0;
        g_limits.locked_week = false;

        Print("=== WEEKLY RESET @ ", TimeToString(current_time, TIME_DATE|TIME_MINUTES), " ===");
        Print("Previous week loss: ", DoubleToString(prev_week_loss, 2), " | Was locked: ", was_week_locked ? "YES" : "NO");
    }

    // Log daily reset
    Print("=== DAILY RESET @ ", TimeToString(current_time, TIME_DATE|TIME_MINUTES), " ===");
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
            "mae", "mfe"
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
                    ulong position_id = 0, string reason = "", string state_before = "", double trade_profit = 0) {
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
    }

    // Use profit directly from parameter (passed from OnTradeTransaction)
    double profit = trade_profit;

    // Get current market data for additional columns
    double current_adx = g_cache.Warmed ? g_cache.ADX : 0;
    double current_atr = g_cache.Warmed ? g_cache.ATR : 0;
    double range_pts = Pts(g_range_high - g_range_low);
    double buffer_pts = current_atr * Inp_ORB_BufferATR;

    if(state_before == "") state_before = EnumToString(g_state);

    FileWrite(g_csv_handle,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
        action,
        IntegerToString(ticket),
        IntegerToString(position_id),
        _Symbol,
        action == "BUY" ? "BUY" : (action == "SELL" ? "SELL" : (action == "PENDING" ? "PENDING" : "CLOSE")),
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
        DoubleToString(mfe, _Digits)
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
            // Adjust entry upward
            entry = NormalizeDouble(min_entry, _Digits);

            // Recalculate SL/TP based on new entry
            double sl_dist = entry - sl;
            double tp_dist = tp - entry;

            sl = NormalizeDouble(entry - sl_dist, _Digits);
            tp = NormalizeDouble(entry + tp_dist, _Digits);
        }

        // Validate SL/TP distances from entry
        if((entry - sl) < min_dist || (tp - entry) < min_dist) {
            // Cannot create valid order with current ATR/spread conditions
            return false;
        }
    }
    else if(side == "SELL") {
        // SellStop: entry must be <= Bid - MinDist
        double max_entry = bid - min_dist;
        if(entry > max_entry) {
            // Adjust entry downward
            entry = NormalizeDouble(max_entry, _Digits);

            // Recalculate SL/TP based on new entry
            double sl_dist = sl - entry;
            double tp_dist = entry - tp;

            sl = NormalizeDouble(entry + sl_dist, _Digits);
            tp = NormalizeDouble(entry - tp_dist, _Digits);
        }

        // Validate SL/TP distances from entry
        if((sl - entry) < min_dist || (entry - tp) < min_dist) {
            // Cannot create valid order with current ATR/spread conditions
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

    // Check one trade per session
    if(session == SES_LONDON && g_london_traded) return false;
    if(session == SES_NY && g_ny_traded) return false;

    // Check session subwindow timing
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

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

    int minutes_from_open = (int)((TimeCurrent() - session_start) / 60);

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

        // Get EMA slope: EMA(0) - EMA(SlopeBars)
        double ema_buffer[20]; // Fixed size array for EMA slope calculation
        int ema_bars_needed = MathMin(Inp_Bias_EMA_SlopeBars + 1, 20); // Limit to array size
        if(CopyBuffer(g_cache.EMA_Handle, 0, 1, ema_bars_needed, ema_buffer) > 0) {
            int slope_index = MathMin(Inp_Bias_EMA_SlopeBars, 19); // Ensure valid index
            double ema_slope = ema_buffer[0] - ema_buffer[slope_index];

            // Determine allowed direction
            if(bid >= g_cache.SMA_Bias && ema_slope >= 0) {
                g_allowed_direction = BIAS_BUY_ONLY;
            } else if(bid <= g_cache.SMA_Bias && ema_slope <= 0) {
                g_allowed_direction = BIAS_SELL_ONLY;
            } else {
                // No valid direction - skip this round
                g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
                if(Inp_LogVerbose) {
                    Print("ORB Bias filter: No valid direction. Bid=", DoubleToString(bid, _Digits),
                          " SMA=", DoubleToString(g_cache.SMA_Bias, _Digits),
                          " EMA_slope=", DoubleToString(ema_slope, _Digits));
                }
                return false;
            }
        } else {
            Print("Error copying EMA buffer for slope calculation");
            return false;
        }
    } else {
        // No bias filter - allow both directions
        g_allowed_direction = BIAS_NONE;
    }

    return true;
}

bool Arm(SessionId session) {
    // Calculate range from session start
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

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

    // Align window with closed M1 bars
    int first_bar = iBarShift(_Symbol, PERIOD_M1, session_start, true);
    int end_bar = iBarShift(_Symbol, PERIOD_M1, session_start + Inp_ORB_RangeMin * 60, true);
    int count = first_bar - end_bar + 1;

    // Reject if insufficient bars
    if(count < 3) {
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    // Get range high/low over count bars from end_bar
    int highest_bar = iHighest(_Symbol, PERIOD_M1, MODE_HIGH, count, end_bar);
    int lowest_bar = iLowest(_Symbol, PERIOD_M1, MODE_LOW, count, end_bar);

    g_range_high = iHigh(_Symbol, PERIOD_M1, highest_bar);
    g_range_low = iLow(_Symbol, PERIOD_M1, lowest_bar);

    double range_pts = Pts(g_range_high - g_range_low);
    if(range_pts < 10) { // Minimum range check
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    // Range sanity vs ATR
    double atr_pts = Pts(g_cache.ATR);
    double range_atr_ratio = range_pts / atr_pts;

    if(range_atr_ratio < Inp_ORB_RangeATR_Min || range_atr_ratio > Inp_ORB_RangeATR_Max) {
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        if(Inp_LogVerbose) {
            Print("ORB Range/ATR ratio out of bounds: ", DoubleToString(range_atr_ratio, 2),
                  " (", DoubleToString(Inp_ORB_RangeATR_Min, 2), "-", DoubleToString(Inp_ORB_RangeATR_Max, 2), ")");
        }
        return false;
    }

    // ChopGuard: Calculate range efficiency
    double sum_tr = 0;
    for(int i = end_bar; i <= first_bar; i++) {
        double high = iHigh(_Symbol, PERIOD_M1, i);
        double low = iLow(_Symbol, PERIOD_M1, i);
        double close_prev = (i < first_bar) ? iClose(_Symbol, PERIOD_M1, i + 1) : iClose(_Symbol, PERIOD_M1, i);

        double tr = MathMax(high - low, MathMax(MathAbs(high - close_prev), MathAbs(low - close_prev)));
        sum_tr += tr;
    }

    double efficiency = (sum_tr > 0) ? (g_range_high - g_range_low) / sum_tr : 0;

    if(efficiency < Inp_ORB_EfficiencyMin) {
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        if(Inp_LogVerbose) {
            Print("ORB ChopGuard: Range efficiency too low: ", DoubleToString(efficiency, 3),
                  " (min: ", DoubleToString(Inp_ORB_EfficiencyMin, 3), ")");
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

    // Calculate lot size
    double lots = CalculateLotSize(Inp_RiskPct, Pts(sl_pts));
    if(lots <= 0) return false;

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

    // Validate and normalize pending prices based on bias direction
    double validated_buy_entry = buy_entry, validated_buy_sl = buy_sl, validated_buy_tp = buy_tp;
    double validated_sell_entry = sell_entry, validated_sell_sl = sell_sl, validated_sell_tp = sell_tp;

    bool buy_valid = false;
    bool sell_valid = false;

    // Only validate the direction allowed by bias filter
    if(g_allowed_direction == BIAS_NONE || g_allowed_direction == BIAS_BUY_ONLY) {
        buy_valid = NormalizeAndValidatePending("BUY", validated_buy_entry, validated_buy_sl, validated_buy_tp);
    }
    if(g_allowed_direction == BIAS_NONE || g_allowed_direction == BIAS_SELL_ONLY) {
        sell_valid = NormalizeAndValidatePending("SELL", validated_sell_entry, validated_sell_sl, validated_sell_tp);
    }

    if(!buy_valid && !sell_valid) {
        if(Inp_LogVerbose) Print("ORB Arm: No valid pending prices for allowed direction(s)");
        g_next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
        return false;
    }

    // Place pending orders
    bool success = false;
    datetime expire_time = TimeCurrent() + Inp_ORB_ExpireMin * 60;

    // Buy stop order
    if(buy_valid) {
        if(g_trade.BuyStop(lots, validated_buy_entry, _Symbol, validated_buy_sl, validated_buy_tp,
                          ORDER_TIME_SPECIFIED, expire_time, Inp_EA_Tag + "_BUY")) {
            g_pend_buy = g_trade.ResultOrder();

            // Store trade meta
            TradeMeta meta;
            meta.strategy_short = "ORB";
            meta.session = session;
            meta.lots = lots;
            meta.open_price = validated_buy_entry;
            meta.sl_price = validated_buy_sl;
            meta.tp_price = validated_buy_tp;
            meta.remaining_lots = lots;
            meta.open_time = TimeCurrent();
            StoreTradeMeta(g_pend_buy, meta);

            // Log PENDING order to CSV
            if(g_csv_enabled) {
                WriteTradeToCSV(g_pend_buy, "PENDING", validated_buy_entry, lots, "BUY_STOP", 0, "", "M_IDLE");
            }

            success = true;
        } else {
            // Handle price error with one retry
            uint error_code = GetLastError();
            if(error_code == TRADE_RETCODE_INVALID_PRICE || error_code == TRADE_RETCODE_REQUOTE ||
               error_code == TRADE_RETCODE_PRICE_OFF) {

                // One retry: move entry further away
                int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
                int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
                int min_dist_pts = MathMax(stops_level, freeze_level) + 2;
                double additional_dist = min_dist_pts * _Point;

                validated_buy_entry += additional_dist;
                validated_buy_sl += additional_dist;
                validated_buy_tp += additional_dist;

                // Normalize again
                double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                if(tick_size <= 0) tick_size = _Point;
                validated_buy_entry = NormalizeDouble(MathRound(validated_buy_entry / tick_size) * tick_size, _Digits);
                validated_buy_sl = NormalizeDouble(MathRound(validated_buy_sl / tick_size) * tick_size, _Digits);
                validated_buy_tp = NormalizeDouble(MathRound(validated_buy_tp / tick_size) * tick_size, _Digits);

                // Log reprice attempt
                if(g_csv_enabled) {
                    WriteTradeToCSV(0, "INFO", validated_buy_entry, lots, "REPRICE_+MinDist", 0, "REPRICE", "M_IDLE");
                }

                // Second attempt
                if(g_trade.BuyStop(lots, validated_buy_entry, _Symbol, validated_buy_sl, validated_buy_tp,
                                  ORDER_TIME_SPECIFIED, expire_time, Inp_EA_Tag + "_BUY")) {
                    g_pend_buy = g_trade.ResultOrder();

                    // Store trade meta
                    TradeMeta meta;
                    meta.strategy_short = "ORB";
                    meta.session = session;
                    meta.lots = lots;
                    meta.open_price = validated_buy_entry;
                    meta.sl_price = validated_buy_sl;
                    meta.tp_price = validated_buy_tp;
                    meta.remaining_lots = lots;
                    meta.open_time = TimeCurrent();
                    StoreTradeMeta(g_pend_buy, meta);

                    // Log PENDING order to CSV
                    if(g_csv_enabled) {
                        WriteTradeToCSV(g_pend_buy, "PENDING", validated_buy_entry, lots, "BUY_STOP", 0, "", "M_IDLE");
                    }

                    success = true;
                } else {
                    // Second failure - log and give up on buy side
                    if(g_csv_enabled) {
                        WriteTradeToCSV(0, "INFO", validated_buy_entry, lots, "REPRICE_FAIL", 0, "REPRICE_FAIL", "M_IDLE");
                    }
                }
            }
        }
    }

    // Sell stop order
    if(sell_valid) {
        if(g_trade.SellStop(lots, validated_sell_entry, _Symbol, validated_sell_sl, validated_sell_tp,
                           ORDER_TIME_SPECIFIED, expire_time, Inp_EA_Tag + "_SELL")) {
            g_pend_sell = g_trade.ResultOrder();

            // Store trade meta
            TradeMeta meta;
            meta.strategy_short = "ORB";
            meta.session = session;
            meta.lots = lots;
            meta.open_price = validated_sell_entry;
            meta.sl_price = validated_sell_sl;
            meta.tp_price = validated_sell_tp;
            meta.remaining_lots = lots;
            meta.open_time = TimeCurrent();
            StoreTradeMeta(g_pend_sell, meta);

            // Log PENDING order to CSV
            if(g_csv_enabled) {
                WriteTradeToCSV(g_pend_sell, "PENDING", validated_sell_entry, lots, "SELL_STOP", 0, "", "M_IDLE");
            }

            success = true;
        } else {
            // Handle price error with one retry
            uint error_code = GetLastError();
            if(error_code == TRADE_RETCODE_INVALID_PRICE || error_code == TRADE_RETCODE_REQUOTE ||
               error_code == TRADE_RETCODE_PRICE_OFF) {

                // One retry: move entry further away
                int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
                int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
                int min_dist_pts = MathMax(stops_level, freeze_level) + 2;
                double additional_dist = min_dist_pts * _Point;

                validated_sell_entry -= additional_dist;
                validated_sell_sl -= additional_dist;
                validated_sell_tp -= additional_dist;

                // Normalize again
                double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                if(tick_size <= 0) tick_size = _Point;
                validated_sell_entry = NormalizeDouble(MathRound(validated_sell_entry / tick_size) * tick_size, _Digits);
                validated_sell_sl = NormalizeDouble(MathRound(validated_sell_sl / tick_size) * tick_size, _Digits);
                validated_sell_tp = NormalizeDouble(MathRound(validated_sell_tp / tick_size) * tick_size, _Digits);

                // Log reprice attempt
                if(g_csv_enabled) {
                    WriteTradeToCSV(0, "INFO", validated_sell_entry, lots, "REPRICE_-MinDist", 0, "REPRICE", "M_IDLE");
                }

                // Second attempt
                if(g_trade.SellStop(lots, validated_sell_entry, _Symbol, validated_sell_sl, validated_sell_tp,
                                   ORDER_TIME_SPECIFIED, expire_time, Inp_EA_Tag + "_SELL")) {
                    g_pend_sell = g_trade.ResultOrder();

                    // Store trade meta
                    TradeMeta meta;
                    meta.strategy_short = "ORB";
                    meta.session = session;
                    meta.lots = lots;
                    meta.open_price = validated_sell_entry;
                    meta.sl_price = validated_sell_sl;
                    meta.tp_price = validated_sell_tp;
                    meta.remaining_lots = lots;
                    meta.open_time = TimeCurrent();
                    StoreTradeMeta(g_pend_sell, meta);

                    // Log PENDING order to CSV
                    if(g_csv_enabled) {
                        WriteTradeToCSV(g_pend_sell, "PENDING", validated_sell_entry, lots, "SELL_STOP", 0, "", "M_IDLE");
                    }

                    success = true;
                } else {
                    // Second failure - log and give up on sell side
                    if(g_csv_enabled) {
                        WriteTradeToCSV(0, "INFO", validated_sell_entry, lots, "REPRICE_FAIL", 0, "REPRICE_FAIL", "M_IDLE");
                    }
                }
            }
        }
    }

    if(success) {
        g_arm_time = TimeCurrent();
        g_armed_session = session;
        if(Inp_LogVerbose) {
            Print("ORB Armed: Range ", DoubleToString(g_range_low, _Digits), "-", DoubleToString(g_range_high, _Digits),
                  " ATR:", DoubleToString(g_cache.ATR, _Digits), " Buy:", g_pend_buy, " Sell:", g_pend_sell);
        }
        return true;
    } else {
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
                WriteTradeToCSV(g_pend_buy, "CANCEL", 0, 0, "BUY_CANCELLED", 0, disarm_reason, "M_ARMED");
            }
            if(g_pend_sell > 0) {
                WriteTradeToCSV(g_pend_sell, "CANCEL", 0, 0, "SELL_CANCELLED", 0, disarm_reason, "M_ARMED");
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
                              PositionGetDouble(POSITION_VOLUME), "TIME_STOP", g_active_position_id, "TIME_STOP", "M_ACTIVE");
            }
            if(Inp_LogVerbose) Print("ORB Position closed by ", Inp_ORB_TimeStopMin, "-minute timestop");
        }
        return;
    }

    // TP1-partial + Break-Even logic
    if(!g_partial_executed && PositionSelectByTicket(g_active_position_id)) {
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        }

        TradeMeta meta;
        if(GetTradeMeta(g_active_position_id, meta)) {
            double tp1_price = meta.tp_price;
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
                partial_volume = MathRound(partial_volume / SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)) * SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

                if(partial_volume > 0 && partial_volume < current_volume) {
                    if(g_trade.PositionClosePartial(g_active_position_id, partial_volume)) {
                        g_partial_executed = true;

                        // Log partial close to CSV
                        if(g_csv_enabled) {
                            WriteTradeToCSV(g_active_position_id, "PARTIAL", current_price, partial_volume,
                                          "TP1_PARTIAL", g_active_position_id, "TP1_PARTIAL", "M_ACTIVE");
                        }

                        // Move SL to Break-Even + Offset
                        double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
                        double new_sl;
                        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                            new_sl = entry_price + Inp_ORB_BE_OffsetPts * _Point;
                        } else {
                            new_sl = entry_price - Inp_ORB_BE_OffsetPts * _Point;
                        }

                        g_trade.PositionModify(g_active_position_id, new_sl, PositionGetDouble(POSITION_TP));

                        if(Inp_LogVerbose) {
                            Print("ORB Partial close executed: ", DoubleToString(partial_volume, 2),
                                  " lots at ", DoubleToString(current_price, _Digits),
                                  " | SL moved to BE+", DoubleToString(Inp_ORB_BE_OffsetPts, 0));
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

            if(g_trade.PositionModify(g_active_position_id, new_sl, PositionGetDouble(POSITION_TP))) {
                // Log trail update to CSV
                if(g_csv_enabled) {
                    WriteTradeToCSV(g_active_position_id, "INFO", current_price, PositionGetDouble(POSITION_VOLUME),
                                  "TRAIL_SL", g_active_position_id, "TRAIL_SL", "M_ACTIVE");
                }

                if(Inp_LogVerbose) {
                    Print("ORB Trailing SL updated: ", DoubleToString(new_sl, _Digits),
                          " | ATR Trail: ", DoubleToString(atr_trail_dist, _Digits));
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
