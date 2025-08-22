//+------------------------------------------------------------------+
//|                                             GOLD_VWAP_Trend.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "GOLD VWAP Trend Reentry Strategy EA"

#include <Trade/Trade.mqh>

//--- Input parameters
input group "=== STRATEGY SETTINGS ==="
input int Inp_Magic = 55221003;                    // Magic Number (VWAP Trend)
input string Inp_EA_Tag = "XAU_VWAP_Trend";       // EA Tag
input double Inp_RiskPct = 1.0;                   // Risk % per trade
input bool Inp_LogVerbose = true;                 // Verbose logging
input bool Inp_WriteCSV = true;                   // Write CSV files

input group "=== VWAP TREND PARAMETERS ==="
input int Inp_TR_ADX_Min = 24;                    // ADX Minimum for Trend
input double Inp_TR_SL_ATR = 0.8;                 // Stop Loss ATR multiplier
input int Inp_TR_TimeStopMin = 45;                // Time Stop Minutes
input int Inp_EMA_Fast = 21;                      // Fast EMA Period
input int Inp_EMA_Slow = 55;                      // Slow EMA Period
input int Inp_SMA_Trend = 200;                    // Trend SMA Period
input double Inp_Pullback_Tolerance = 0.001;     // Pullback tolerance (0.1%)

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
enum Bias { B_LONG, B_SHORT, B_NONE };

//--- Structures
struct IndCache {
    double ATR;
    double ADX;
    double EMA_fast;
    double EMA_slow;
    double SMA_trend;
    Bias bias;
    bool Warmed;
    
    void Init(string symbol) {
        ATR = 0;
        ADX = 0;
        EMA_fast = 0;
        EMA_slow = 0;
        SMA_trend = 0;
        bias = B_NONE;
        Warmed = false;
    }
    
    bool Update() {
        double atr_buffer[1];
        double adx_buffer[1];
        double ema_fast_buffer[1];
        double ema_slow_buffer[1];
        double sma_trend_buffer[1];

        int atr_handle = iATR(_Symbol, PERIOD_M5, Inp_ATR_Period);
        int adx_handle = iADX(_Symbol, PERIOD_M5, Inp_ADX_Period);
        int ema_fast_handle = iMA(_Symbol, PERIOD_M5, Inp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
        int ema_slow_handle = iMA(_Symbol, PERIOD_M5, Inp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
        int sma_trend_handle = iMA(_Symbol, PERIOD_M5, Inp_SMA_Trend, 0, MODE_SMA, PRICE_CLOSE);

        if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) ATR = atr_buffer[0];
        if(CopyBuffer(adx_handle, 0, 0, 1, adx_buffer) > 0) ADX = adx_buffer[0];
        if(CopyBuffer(ema_fast_handle, 0, 0, 1, ema_fast_buffer) > 0) EMA_fast = ema_fast_buffer[0];
        if(CopyBuffer(ema_slow_handle, 0, 0, 1, ema_slow_buffer) > 0) EMA_slow = ema_slow_buffer[0];
        if(CopyBuffer(sma_trend_handle, 0, 0, 1, sma_trend_buffer) > 0) SMA_trend = sma_trend_buffer[0];
        
        // Determine bias
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(current_price > SMA_trend && EMA_fast > EMA_slow) {
            bias = B_LONG;
        } else if(current_price < SMA_trend && EMA_fast < EMA_slow) {
            bias = B_SHORT;
        } else {
            bias = B_NONE;
        }
        
        if(ATR > 0 && ADX > 0 && EMA_fast > 0 && EMA_slow > 0 && SMA_trend > 0) {
            Warmed = true;
            return true;
        }
        return false;
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
ulong g_active_ticket = 0;
datetime g_entry_time = 0;
RiskLimits g_limits;

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
void WriteTradeToCSV(ulong ticket, string action, double price, double lots, string comment);
double Pts(double price_diff);

//--- Strategy functions
bool IsEligible(SessionId session);
bool Arm(SessionId session);
void OnTickActive();
void OnExit(bool profit);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
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
    if(Inp_WriteCSV) {
        InitCSV();
    }
    
    // Initialize risk management
    DoDailyReset();
    
    // Wait for indicators to warm up
    Print("Waiting for indicators to warm up...");
    int warmup_attempts = 0;
    while(!g_cache.Update() && warmup_attempts < 100) {
        Sleep(100);
        warmup_attempts++;
    }
    
    if(!g_cache.Warmed) {
        Print("WARNING: Indicators not warmed up after 100 attempts");
    }
    
    Print("VWAP Trend EA initialized successfully. Magic: ", Inp_Magic);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("=== VWAP TREND EA DEINITIALIZATION SUMMARY ===");
    Print("Total trades: ", g_total_trades, " | Wins: ", g_total_wins, " | Win rate: ", 
          g_total_trades > 0 ? DoubleToString((double)g_total_wins / g_total_trades * 100, 2) : "0.00", "%");
    Print("Total P&L: ", DoubleToString(g_total_pnl, 2));
    Print("Day loss: ", DoubleToString(g_limits.day_loss, 2), " | Week loss: ", DoubleToString(g_limits.week_loss, 2));
    Print("Risk locks - Day: ", g_limits.locked_day ? "YES" : "NO", " | Week: ", g_limits.locked_week ? "YES" : "NO");
    
    if(g_csv_handle != INVALID_HANDLE) {
        FileClose(g_csv_handle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Update indicators
    if(!g_cache.Update()) return;
    
    // Update risk management
    UpdateRiskLimits();
    
    // Check if trading is locked
    if(g_limits.locked_day || g_limits.locked_week) {
        return;
    }
    
    SessionId current_session = GetCurrentSession();
    
    // Strategy logic based on state
    if(g_state == M_IDLE) {
        // Check if eligible to arm
        if(IsEligible(current_session)) {
            if(Arm(current_session)) {
                g_state = M_ACTIVE;
            }
        }
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
    if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_INOUT) {
        // Exit deal - handle trade outcome
        ulong ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
        double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
        double lots = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
        double price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
        
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
        
        // Log to CSV
        if(Inp_WriteCSV) {
            WriteTradeToCSV(ticket, "CLOSE", price, lots, is_profit ? "PROFIT" : "LOSS");
        }
        
        // Handle strategy completion
        OnExit(is_profit);
        
        if(Inp_LogVerbose) {
            Print("VWAP Trend Trade closed: Ticket=", ticket, " Profit=", DoubleToString(profit, 2),
                  " Result=", is_profit ? "WIN" : "LOSS");
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
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(tick_value == 0 || tick_size == 0 || sl_points <= 0) return 0;

    double lots = risk_amount / (sl_points * tick_value / tick_size);

    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    lots = MathMax(lots, min_lot);
    lots = MathMin(lots, max_lot);
    lots = MathRound(lots / lot_step) * lot_step;

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
    string date_str = TimeToString(TimeCurrent(), TIME_DATE);
    StringReplace(date_str, ".", "_");
    g_csv_filename = Inp_EA_Tag + "_" + date_str + ".csv";

    g_csv_handle = FileOpen(g_csv_filename, FILE_WRITE|FILE_CSV);
    if(g_csv_handle != INVALID_HANDLE) {
        FileWrite(g_csv_handle, "timestamp", "action", "ticket", "symbol", "type", "lots", "price",
                 "sl", "tp", "profit", "comment", "strategy", "session", "bias", "ema_fast", "ema_slow", "sma_trend", "adx");
        Print("CSV file created: ", g_csv_filename);
    } else {
        Print("ERROR: Failed to create CSV file: ", g_csv_filename);
    }
}

void WriteTradeToCSV(ulong ticket, string action, double price, double lots, string comment) {
    if(g_csv_handle == INVALID_HANDLE) return;

    TradeMeta meta;
    string strategy = "VWAP_TREND";
    string session = "UNKNOWN";
    double sl = 0, tp = 0, profit = 0;

    if(GetTradeMeta(ticket, meta)) {
        session = EnumToString(meta.session);
        sl = meta.sl_price;
        tp = meta.tp_price;
    }

    if(action == "CLOSE") {
        if(HistorySelectByPosition(ticket)) {
            profit = HistoryDealGetDouble(HistoryDealsTotal()-1, DEAL_PROFIT);
        }
    }

    FileWrite(g_csv_handle,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
        action,
        ticket,
        _Symbol,
        action == "BUY" ? "BUY" : (action == "SELL" ? "SELL" : "CLOSE"),
        DoubleToString(lots, 2),
        DoubleToString(price, _Digits),
        DoubleToString(sl, _Digits),
        DoubleToString(tp, _Digits),
        DoubleToString(profit, 2),
        comment,
        strategy,
        session,
        EnumToString(g_cache.bias),
        DoubleToString(g_cache.EMA_fast, _Digits),
        DoubleToString(g_cache.EMA_slow, _Digits),
        DoubleToString(g_cache.SMA_trend, _Digits),
        DoubleToString(g_cache.ADX, 2)
    );
    FileFlush(g_csv_handle);
}

//+------------------------------------------------------------------+
//| VWAP Trend Strategy Functions                                    |
//+------------------------------------------------------------------+
bool IsEligible(SessionId session) {
    if(!g_cache.Warmed) return false;
    if(g_cache.ADX < Inp_TR_ADX_Min) return false;
    if(g_cache.bias == B_NONE) return false;
    if(g_state != M_IDLE) return false;

    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Check for pullback to EMA in trend direction
    if(g_cache.bias == B_LONG && current_price > g_cache.SMA_trend) {
        // Look for pullback to slow EMA in uptrend
        if(current_price <= g_cache.EMA_slow && current_price > g_cache.EMA_slow * (1.0 - Inp_Pullback_Tolerance)) {
            return true;
        }
    }
    else if(g_cache.bias == B_SHORT && current_price < g_cache.SMA_trend) {
        // Look for pullback to slow EMA in downtrend
        if(current_price >= g_cache.EMA_slow && current_price < g_cache.EMA_slow * (1.0 + Inp_Pullback_Tolerance)) {
            return true;
        }
    }

    return false;
}

bool Arm(SessionId session) {
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl_pts = g_cache.ATR * Inp_TR_SL_ATR;

    // Calculate lot size
    double lots = CalculateLotSize(Inp_RiskPct, Pts(sl_pts));
    if(lots <= 0) return false;

    bool success = false;
    ulong ticket = 0;

    if(g_cache.bias == B_LONG) {
        // Buy on pullback in uptrend
        double sl_price = current_price - sl_pts;
        double tp_price = 0; // No fixed TP for trend following

        if(g_trade.Buy(lots, _Symbol, 0, sl_price, tp_price, Inp_EA_Tag + "_TREND_BUY")) {
            ticket = g_trade.ResultOrder();
            success = true;

            // Log to CSV
            if(Inp_WriteCSV) {
                WriteTradeToCSV(ticket, "BUY", current_price, lots, "TREND_PULLBACK_LONG");
            }
        }
    }
    else if(g_cache.bias == B_SHORT) {
        // Sell on pullback in downtrend
        double sl_price = current_price + sl_pts;
        double tp_price = 0; // No fixed TP for trend following

        if(g_trade.Sell(lots, _Symbol, 0, sl_price, tp_price, Inp_EA_Tag + "_TREND_SELL")) {
            ticket = g_trade.ResultOrder();
            success = true;

            // Log to CSV
            if(Inp_WriteCSV) {
                WriteTradeToCSV(ticket, "SELL", current_price, lots, "TREND_PULLBACK_SHORT");
            }
        }
    }

    if(success) {
        // Store trade meta
        TradeMeta meta;
        meta.strategy_short = "VWAP_TREND";
        meta.session = session;
        meta.lots = lots;
        meta.open_price = current_price;
        meta.sl_price = g_cache.bias == B_LONG ? current_price - sl_pts : current_price + sl_pts;
        meta.tp_price = 0; // No fixed TP
        meta.remaining_lots = lots;
        meta.open_time = TimeCurrent();
        StoreTradeMeta(ticket, meta);

        g_active_ticket = ticket;
        g_entry_time = TimeCurrent();

        if(Inp_LogVerbose) {
            Print("VWAP Trend Armed: Bias=", EnumToString(g_cache.bias),
                  " Price=", DoubleToString(current_price, _Digits),
                  " EMA_Fast=", DoubleToString(g_cache.EMA_fast, _Digits),
                  " EMA_Slow=", DoubleToString(g_cache.EMA_slow, _Digits),
                  " ADX=", DoubleToString(g_cache.ADX, 2),
                  " Ticket=", ticket);
        }
        return true;
    }

    return false;
}

void OnTickActive() {
    // Check if position is still open
    if(PositionsTotal() == 0) {
        g_state = M_DONE;
        g_active_ticket = 0;
        g_entry_time = 0;
        return;
    }

    // Check time stop
    if(Inp_TR_TimeStopMin > 0 && g_entry_time > 0) {
        if(TimeCurrent() - g_entry_time > Inp_TR_TimeStopMin * 60) {
            if(g_active_ticket > 0 && PositionSelectByTicket(g_active_ticket)) {
                if(PositionGetInteger(POSITION_MAGIC) == Inp_Magic) {
                    g_trade.PositionClose(g_active_ticket);
                    if(Inp_LogVerbose) {
                        Print("VWAP Trend position closed due to time stop: ", Inp_TR_TimeStopMin, " minutes");
                    }
                }
            }
        }
    }

    // Check if trend bias changed
    if(g_cache.bias == B_NONE) {
        if(g_active_ticket > 0 && PositionSelectByTicket(g_active_ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == Inp_Magic) {
                g_trade.PositionClose(g_active_ticket);
                if(Inp_LogVerbose) {
                    Print("VWAP Trend position closed due to bias change to NONE");
                }
            }
        }
    }
}

void OnExit(bool profit) {
    g_state = M_DONE;
    g_active_ticket = 0;
    g_entry_time = 0;

    if(Inp_LogVerbose) {
        Print("VWAP Trend Exit: ", profit ? "Profit" : "Loss",
              " | Total: ", g_total_wins, "/", g_total_trades,
              " | Win Rate: ", g_total_trades > 0 ? DoubleToString((double)g_total_wins / g_total_trades * 100, 2) : "0.00", "%");
    }
}
