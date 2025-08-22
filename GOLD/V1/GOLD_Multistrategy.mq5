//+------------------------------------------------------------------+
//|                                              GOLD_V10.mq5 |
//|                                                         Kjaehr96 |
//|                                                                  |
//| V10.1 – robust arm + ORB pending fix + gate relax + telemetry   |
//| Date: 2025-01-22                                                |
//+------------------------------------------------------------------+
#property copyright "Kjaehr96"
#property link      ""
#property version   "1.00"
#property description "Multi-strategy XAUUSD EA with MTF analysis and risk management"

#include <Trade/Trade.mqh>

//--- Constants
#define MAX_STRATEGIES 11  // Number of strategies in StrategyId enum

//--- Input parameters
// General
input string Inp_EA_Tag = "XAU_Multi";
input long Inp_Magic = 55220011;
input bool Inp_OnePosAtATime = true;
input bool Inp_LogVerbose = false;
input bool Inp_WriteCSV = true;
input int Inp_BrokerGMT_Offset = 2;
input int Inp_ServerDayStart = 0;  // Server day start hour (0-23)

// Execution & Costs
input int Inp_MaxSpreadPts = 35;
input int Inp_MaxSlipPts = 25;
input int Inp_SlipRingSize = 50;

// Risk
input double Inp_RiskPerTradePct = 0.5;
input double Inp_DailyMaxLossPct = 2.0;
input double Inp_WeeklyMaxLossPct = 5.0;
input int Inp_MaxConsecLosses = 3;
input int Inp_CooldownSec = 180;

// Sessions (CET)
input int Inp_TokyoOpen_H=0, Inp_TokyoOpen_M=0, Inp_TokyoClose_H=7, Inp_TokyoClose_M=0;
input int Inp_LondonOpen_H=8, Inp_LondonOpen_M=0, Inp_LondonEnd_H=11, Inp_LondonEnd_M=0;
input int Inp_NYOpen_H=14, Inp_NYOpen_M=30, Inp_NYEnd_H=16, Inp_NYEnd_M=30;

// News filter
input bool Inp_UseNewsFilter = false;
input int Inp_NewsBlockMin = 15;

// Indicators (MTF cache)
input ENUM_TIMEFRAMES Inp_TF_ATRADX = PERIOD_M15;
input int Inp_ATR_Period = 14;
input int Inp_ADX_Period = 14;
input int Inp_EMA_Trend = 55;
input int Inp_SMA_Bias = 200;
input int Inp_Keltner_EMA = 20;
input int Inp_Keltner_ATR = 14;
input double Inp_Keltner_Mult = 2.8;

// VWAP
input bool Inp_UseSessionVWAP = true;
input double Inp_VWAP_FadeZ = 1.2;
input int Inp_VWAP_SlopeMaxPts = 50;

// ORB (London/NY)
input int Inp_ORB_RangeMin = 10;
input double Inp_ORB_BufferATR = 0.10;
input double Inp_ORB_SL_ATR = 1.00;
input double Inp_ORB_TP1_ATR = 0.50;
input double Inp_ORB_TP2_ATR = 1.20;
input double Inp_ORB_VWAP_SD = 1.0;
input int Inp_ORB_ADX_Min = 15;
input int Inp_ORB_ADX_Max = 45;
input int Inp_ORB_RecalcMin = 3;
input int  Inp_ORB_ExpireMin = 30;
input bool Inp_ORB_CancelOutOfSession = true;

// VWAP Fade
input int Inp_RSI_Period = 14;
input int Inp_RSI_BuyMax = 45;
input int Inp_RSI_SellMin = 55;
input int Inp_ADX_Max_Fade = 26;
input double Inp_Fade_SL_ATR = 0.8;

// VWAP Trend Re-entry
input int Inp_TR_ADX_Min = 24;
input double Inp_TR_SL_ATR = 0.8;
input int Inp_TR_TimeStopMin = 45;

// Keltner MR
input int Inp_K_ADX_Max = 24;
input double Inp_K_SL_FactorATR = 0.5;

// Liquidity Sweep
input int Inp_Sweep_Lookback = 80;
input int Inp_Sweep_MinWickPts = 20;
input int Inp_Sweep_SL_Buffer = 15;

// Asian Range & Retest
input int Inp_Asia_MinRangePts = 30;
input int Inp_Asia_Break_H1 = 8;
input int Inp_Asia_Break_H2 = 10;

// News Spike Fade
input int Inp_News_FadeDelaySec = 45;
input double Inp_News_SL_ATR = 1.2;

// Module toggles
input bool Enable_ORB=true, Enable_VWAP_Fade=true, Enable_VWAP_TR=true, Enable_Keltner=true, Enable_Sweep=true, Enable_AsiaRange=false, Enable_NewsFade=false;
input bool Enable_Experimental_DogWalk=false, Enable_Experimental_AsianEarly=false, Enable_Experimental_VolOsc=false;

//--- Enums
enum StrategyId { S_ORB, S_VWAP_FADE, S_VWAP_TR, S_KELTNER, S_SWEEP, S_ASIA, S_NEWS, S_DOGWALK, S_ASIANEARLY, S_VOLOSC, S_NONE };
enum SessionId { SES_TOKYO, SES_LONDON, SES_NY, SES_OFF };
enum Regime { REG_RANGE, REG_TREND, REG_SPIKE };
enum Bias { B_LONG, B_SHORT, B_NONE };
enum ModState { M_IDLE, M_ARMED, M_ACTIVE, M_DONE };

//--- Forward declarations for structures used in functions
struct TradeMeta {
    // Basic trade info
    StrategyId sid;
    ulong ticket;
    double sl_pts;
    double tp_pts;
    datetime open_time;

    // Partial close support
    ulong parent_ticket;        // Original position ticket (0 if this is the original)
    int partial_sequence;       // Sequence number for partial closes (0 for original)
    double original_lots;       // Original position size
    double remaining_lots;      // Remaining position size after partials

    // Strategy identification
    string strategy_name;
    string strategy_short;

    // Market context
    SessionId session;
    Regime regime;
    Bias bias;

    // Technical indicators at entry
    double entry_atr;
    double entry_adx;
    double entry_vwap_dev;
    double entry_spread;
    double entry_slip;

    // Trade planning
    datetime entry_time;
    double lots;
    double entry_price;
    double planned_sl;
    double planned_tp;

    // Constructor for easy initialization
    TradeMeta() {
        sid = S_NONE;
        ticket = 0;
        sl_pts = 0;
        tp_pts = 0;
        open_time = 0;
        parent_ticket = 0;
        partial_sequence = 0;
        original_lots = 0;
        remaining_lots = 0;
        strategy_name = "";
        strategy_short = "";
        session = SES_OFF;
        regime = REG_RANGE;
        bias = B_NONE;
        entry_atr = 0;
        entry_adx = 0;
        entry_vwap_dev = 0;
        entry_spread = 0;
        entry_slip = 0;
        entry_time = 0;
        lots = 0;
        entry_price = 0;
        planned_sl = 0;
        planned_tp = 0;
    }

    // Copy constructor to fix deprecation warning
    TradeMeta(const TradeMeta& other) {
        sid = other.sid;
        ticket = other.ticket;
        sl_pts = other.sl_pts;
        tp_pts = other.tp_pts;
        open_time = other.open_time;
        parent_ticket = other.parent_ticket;
        partial_sequence = other.partial_sequence;
        original_lots = other.original_lots;
        remaining_lots = other.remaining_lots;
        strategy_name = other.strategy_name;
        strategy_short = other.strategy_short;
        session = other.session;
        regime = other.regime;
        bias = other.bias;
        entry_atr = other.entry_atr;
        entry_adx = other.entry_adx;
        entry_vwap_dev = other.entry_vwap_dev;
        entry_spread = other.entry_spread;
        entry_slip = other.entry_slip;
        entry_time = other.entry_time;
        lots = other.lots;
        entry_price = other.entry_price;
        planned_sl = other.planned_sl;
        planned_tp = other.planned_tp;
    }
};

struct IndCache {
    bool Warmed;
    double ATR, ADX, RSI;
    double EMA_hi, EMA_lo;
    double SMA200;
    double Keltner_mid, Keltner_up, Keltner_dn;
    double VWAP_sess, VWAP_day, VWAP_sd;
    int VWAP_slope_pts;
    Bias bias;
    Regime regime;

    // Indicator handles
    int h_ATR, h_ADX, h_RSI, h_EMA, h_SMA, h_Keltner_EMA, h_Keltner_ATR;

    bool Update();
    void Init(string symbol);
    void CalcSessionVWAP();
};

//--- Strategy standardization constants
const string STRATEGY_NAMES[] = {
    "Opening Range Breakout",      // S_ORB
    "VWAP Fade",                  // S_VWAP_FADE
    "VWAP Trend Reentry",         // S_VWAP_TR
    "Keltner Mean Reversion",     // S_KELTNER
    "Liquidity Sweep",            // S_SWEEP
    "Asian Range Breakout",       // S_ASIA
    "News Spike Fade",            // S_NEWS
    "Dog Walk Experimental",      // S_DOGWALK
    "Asian Early Experimental",   // S_ASIANEARLY
    "Volume Oscillator Exp",      // S_VOLOSC
    "None"                        // S_NONE
};

const string STRATEGY_SHORT[] = {
    "ORB",      // S_ORB
    "VWFD",     // S_VWAP_FADE
    "VWTR",     // S_VWAP_TR
    "KELT",     // S_KELTNER
    "SWP",      // S_SWEEP
    "ASIA",     // S_ASIA
    "NEWS",     // S_NEWS
    "DOGW",     // S_DOGWALK
    "ASIE",     // S_ASIANEARLY
    "VOSC",     // S_VOLOSC
    "NONE"      // S_NONE
};

//--- Strategy helper functions
string GetStrategyName(StrategyId sid) {
    if(sid >= 0 && sid < ArraySize(STRATEGY_NAMES)) {
        return STRATEGY_NAMES[sid];
    }
    return "Unknown Strategy";
}

string GetStrategyShort(StrategyId sid) {
    if(sid >= 0 && sid < ArraySize(STRATEGY_SHORT)) {
        return STRATEGY_SHORT[sid];
    }
    return "UNK";
}

string GetStrategyComment(StrategyId sid) {
    return Inp_EA_Tag + "|" + GetStrategyShort(sid);
}

//--- Trade meta lookup helper functions
void InitTradeMetaSystem() {
    ArrayResize(g_trade_metas, MAX_TRADE_METAS);
    ArrayResize(g_trade_tickets, MAX_TRADE_METAS);
    g_meta_count = 0;
}

bool StoreTradeMeta(ulong ticket, const TradeMeta& meta) {
    if(g_meta_count >= MAX_TRADE_METAS) {
        Print("WARNING: Trade meta storage full, cannot store ticket ", ticket);
        return false;
    }

    // Check if ticket already exists (shouldn't happen, but safety check)
    for(int i = 0; i < g_meta_count; i++) {
        if(i < ArraySize(g_trade_tickets) && g_trade_tickets[i] == ticket) {
            Print("WARNING: Ticket ", ticket, " already exists in meta storage, updating...");
            if(i < ArraySize(g_trade_metas)) {
                g_trade_metas[i] = meta;
            }
            return true;
        }
    }

    // Store new meta with bounds checking
    if(g_meta_count < ArraySize(g_trade_tickets) && g_meta_count < ArraySize(g_trade_metas)) {
        g_trade_tickets[g_meta_count] = ticket;
        g_trade_metas[g_meta_count] = meta;
        g_meta_count++;

        if(Inp_LogVerbose) {
            Print("Stored trade meta for ticket ", ticket, " | Strategy: ", meta.strategy_short,
                  " | Session: ", EnumToString(meta.session), " | Count: ", g_meta_count);
        }
        return true;
    } else {
        Print("ERROR: Array bounds exceeded in StoreTradeMeta. Count: ", g_meta_count,
              " | Tickets size: ", ArraySize(g_trade_tickets), " | Metas size: ", ArraySize(g_trade_metas));
        return false;
    }
}

bool GetTradeMeta(ulong ticket, TradeMeta& meta) {
    for(int i = 0; i < g_meta_count; i++) {
        if(i < ArraySize(g_trade_tickets) && g_trade_tickets[i] == ticket) {
            if(i < ArraySize(g_trade_metas)) {
                meta = g_trade_metas[i];
                return true;
            }
        }
    }
    return false;
}

bool RemoveTradeMeta(ulong ticket) {
    for(int i = 0; i < g_meta_count; i++) {
        if(i < ArraySize(g_trade_tickets) && g_trade_tickets[i] == ticket) {
            // Shift remaining elements down with bounds checking
            for(int j = i; j < g_meta_count - 1; j++) {
                if(j + 1 < ArraySize(g_trade_tickets) && j < ArraySize(g_trade_tickets)) {
                    g_trade_tickets[j] = g_trade_tickets[j + 1];
                }
                if(j + 1 < ArraySize(g_trade_metas) && j < ArraySize(g_trade_metas)) {
                    g_trade_metas[j] = g_trade_metas[j + 1];
                }
            }
            g_meta_count--;

            if(Inp_LogVerbose) {
                Print("Removed trade meta for ticket ", ticket, " | Remaining count: ", g_meta_count);
            }

            return true;
        }
    }
    return false;
}

int GetTradeMetaCount() {
    return g_meta_count;
}

//--- Exit reason tracking functions
void StoreExitReason(ulong ticket, string reason) {
    // Ensure array is properly sized
    if(ArraySize(g_exit_reasons) <= g_exit_reason_count) {
        ArrayResize(g_exit_reasons, g_exit_reason_count + 50);
    }

    // Clean up old entries first (keep only last 50)
    if(g_exit_reason_count >= MAX_EXIT_REASONS) {
        int keep_count = 50;
        for(int i = 0; i < keep_count; i++) {
            int source_idx = g_exit_reason_count - keep_count + i;
            if(source_idx >= 0 && source_idx < ArraySize(g_exit_reasons) && i < ArraySize(g_exit_reasons)) {
                g_exit_reasons[i] = g_exit_reasons[source_idx];
            }
        }
        g_exit_reason_count = keep_count;
    }

    // Store new exit reason with bounds checking
    if(g_exit_reason_count < ArraySize(g_exit_reasons)) {
        g_exit_reasons[g_exit_reason_count].ticket = ticket;
        g_exit_reasons[g_exit_reason_count].exit_reason = reason;
        g_exit_reasons[g_exit_reason_count].timestamp = TimeCurrent();
        g_exit_reason_count++;

        if(Inp_LogVerbose) {
            Print("Exit reason stored: Ticket ", ticket, " | Reason: ", reason);
        }
    } else {
        Print("ERROR: Cannot store exit reason - array bounds exceeded. Count: ", g_exit_reason_count,
              " | Array size: ", ArraySize(g_exit_reasons));
    }
}

string GetStoredExitReason(ulong ticket) {
    // Search for the exit reason (most recent first)
    for(int i = g_exit_reason_count - 1; i >= 0; i--) {
        if(i < ArraySize(g_exit_reasons) && g_exit_reasons[i].ticket == ticket) {
            string reason = g_exit_reasons[i].exit_reason;

            // Remove the entry after retrieval to prevent memory buildup
            for(int j = i; j < g_exit_reason_count - 1; j++) {
                if(j + 1 < ArraySize(g_exit_reasons) && j < ArraySize(g_exit_reasons)) {
                    g_exit_reasons[j] = g_exit_reasons[j + 1];
                }
            }
            g_exit_reason_count--;

            return reason;
        }
    }
    return ""; // Not found
}

void CleanupOldExitReasons() {
    datetime cutoff = TimeCurrent() - 3600; // Remove entries older than 1 hour
    int write_pos = 0;

    for(int i = 0; i < g_exit_reason_count; i++) {
        if(i < ArraySize(g_exit_reasons) && g_exit_reasons[i].timestamp > cutoff) {
            if(write_pos != i && write_pos < ArraySize(g_exit_reasons)) {
                g_exit_reasons[write_pos] = g_exit_reasons[i];
            }
            write_pos++;
        }
    }
    g_exit_reason_count = write_pos;
}

//--- Trailing stop tracking functions
void TrackPositionModification(ulong ticket, double new_sl) {
    // Ensure array is properly sized
    if(ArraySize(g_trailing_stops) <= g_trailing_stop_count) {
        ArrayResize(g_trailing_stops, g_trailing_stop_count + 25);
    }

    // Find existing entry or create new one
    int index = -1;
    for(int i = 0; i < g_trailing_stop_count; i++) {
        if(i < ArraySize(g_trailing_stops) && g_trailing_stops[i].ticket == ticket) {
            index = i;
            break;
        }
    }

    if(index == -1) {
        // Create new entry
        if(g_trailing_stop_count < MAX_TRAILING_STOPS && g_trailing_stop_count < ArraySize(g_trailing_stops)) {
            index = g_trailing_stop_count;
            g_trailing_stop_count++;
            g_trailing_stops[index].ticket = ticket;
            g_trailing_stops[index].last_sl = new_sl;
            g_trailing_stops[index].last_modification = TimeCurrent();
        } else {
            Print("WARNING: Cannot add trailing stop - capacity reached or array bounds exceeded");
        }
    } else {
        // Update existing entry
        if(index < ArraySize(g_trailing_stops)) {
            g_trailing_stops[index].last_sl = new_sl;
            g_trailing_stops[index].last_modification = TimeCurrent();
        }
    }
}

bool IsTrailingStopExit(ulong ticket, double exit_price) {
    for(int i = 0; i < g_trailing_stop_count; i++) {
        if(i < ArraySize(g_trailing_stops) && g_trailing_stops[i].ticket == ticket) {
            // Check if exit price is close to last known SL (within 2 points)
            if(MathAbs(exit_price - g_trailing_stops[i].last_sl) < _Point * 2) {
                // Remove the entry with bounds checking
                for(int j = i; j < g_trailing_stop_count - 1; j++) {
                    if(j + 1 < ArraySize(g_trailing_stops) && j < ArraySize(g_trailing_stops)) {
                        g_trailing_stops[j] = g_trailing_stops[j + 1];
                    }
                }
                g_trailing_stop_count--;
                return true;
            }
        }
    }
    return false;
}

void CleanupTrailingStops() {
    datetime cutoff = TimeCurrent() - 7200; // Remove entries older than 2 hours
    int write_pos = 0;

    for(int i = 0; i < g_trailing_stop_count; i++) {
        if(i < ArraySize(g_trailing_stops) && g_trailing_stops[i].last_modification > cutoff) {
            if(write_pos != i && write_pos < ArraySize(g_trailing_stops)) {
                g_trailing_stops[write_pos] = g_trailing_stops[i];
            }
            write_pos++;
        }
    }
    g_trailing_stop_count = write_pos;
}

//--- Partial close detection and handling functions
bool IsPartialClose(ulong position_ticket, double deal_volume) {
    // Check if there's still an open position with the same ticket
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionSelectByTicket(PositionGetTicket(i))) {
            if(PositionGetTicket(i) == position_ticket) {
                double remaining_volume = PositionGetDouble(POSITION_VOLUME);
                // If there's still volume remaining, this was a partial close
                return (remaining_volume > 0);
            }
        }
    }
    return false; // Position fully closed
}

TradeMeta CreatePartialCloseMeta(const TradeMeta& parent_meta, double closed_lots, int sequence) {
    TradeMeta partial_meta = parent_meta; // Copy all parent data

    // Update partial close specific fields
    partial_meta.parent_ticket = (parent_meta.parent_ticket == 0) ? parent_meta.ticket : parent_meta.parent_ticket;
    partial_meta.partial_sequence = sequence;
    partial_meta.lots = closed_lots;
    partial_meta.remaining_lots = parent_meta.remaining_lots - closed_lots;

    return partial_meta;
}

void UpdateRemainingLots(ulong ticket, double closed_lots) {
    for(int i = 0; i < g_meta_count; i++) {
        if(i < ArraySize(g_trade_tickets) && g_trade_tickets[i] == ticket) {
            if(i < ArraySize(g_trade_metas)) {
                g_trade_metas[i].remaining_lots -= closed_lots;
                if(Inp_LogVerbose) {
                    Print("Updated remaining lots for ticket ", ticket,
                          " | Closed: ", DoubleToString(closed_lots, 2),
                          " | Remaining: ", DoubleToString(g_trade_metas[i].remaining_lots, 2));
                }
            }
            break;
        }
    }
}

//--- Helper function to create trade meta with market context
TradeMeta CreateTradeMeta(StrategyId sid, const IndCache& cache, SessionId session, double lots, double entry_price, double planned_sl, double planned_tp) {
    TradeMeta meta;

    // Strategy identification
    meta.sid = sid;
    meta.strategy_name = GetStrategyName(sid);
    meta.strategy_short = GetStrategyShort(sid);

    // Market context
    meta.session = session;
    meta.regime = cache.regime;
    meta.bias = cache.bias;

    // Technical indicators at entry
    meta.entry_atr = cache.ATR;
    meta.entry_adx = cache.ADX;
    meta.entry_vwap_dev = (cache.VWAP_sd > 0) ? (entry_price - cache.VWAP_sess) / cache.VWAP_sd : 0;
    meta.entry_spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
    meta.entry_slip = 0; // Will be updated after execution

    // Trade planning
    meta.entry_time = TimeCurrent();
    meta.lots = lots;
    meta.entry_price = entry_price;
    meta.planned_sl = planned_sl;
    meta.planned_tp = planned_tp;

    // Partial close initialization (for original positions)
    meta.parent_ticket = 0;         // This is the original position
    meta.partial_sequence = 0;      // Original position sequence
    meta.original_lots = lots;      // Store original lot size
    meta.remaining_lots = lots;     // Initially all lots remain

    return meta;
}

//--- Global Strategy Statistics Functions
void InitStrategyStats() {
    for(int i = 0; i < MAX_STRATEGIES; i++) {
        g_strategy_trades[i] = 0;
        g_strategy_wins[i] = 0;
        g_strategy_gross_profit[i] = 0.0;
        g_strategy_gross_loss[i] = 0.0;
        g_strategy_net_pnl[i] = 0.0;
        g_strategy_max_dd_seq[i] = 0;
        g_strategy_current_dd_seq[i] = 0;
        g_strategy_total_rr[i] = 0.0;
        g_strategy_total_holding_time[i] = 0.0;
    }
}

void UpdateStrategyStats(StrategyId sid, double pnl, double rr_ratio, double holding_time_sec) {
    int idx = (int)sid;
    if(idx < 0 || idx >= MAX_STRATEGIES) return;

    // Update basic counters
    g_strategy_trades[idx]++;

    // Update P&L tracking
    g_strategy_net_pnl[idx] += pnl;
    if(pnl > 0) {
        g_strategy_wins[idx]++;
        g_strategy_gross_profit[idx] += pnl;
        g_strategy_current_dd_seq[idx] = 0; // Reset consecutive losses
    } else {
        g_strategy_gross_loss[idx] += MathAbs(pnl);
        g_strategy_current_dd_seq[idx]++;
        if(g_strategy_current_dd_seq[idx] > g_strategy_max_dd_seq[idx]) {
            g_strategy_max_dd_seq[idx] = g_strategy_current_dd_seq[idx];
        }
    }

    // Update derived metrics
    g_strategy_total_rr[idx] += rr_ratio;
    g_strategy_total_holding_time[idx] += holding_time_sec;

    if(Inp_LogVerbose) {
        Print("Strategy Stats Updated: ", GetStrategyShort(sid),
              " | Trades: ", g_strategy_trades[idx],
              " | Wins: ", g_strategy_wins[idx],
              " | Net: ", DoubleToString(g_strategy_net_pnl[idx], 2),
              " | DD Seq: ", g_strategy_current_dd_seq[idx]);
    }
}

// Helper functions to get derived strategy statistics
double GetStrategyWinRate(StrategyId sid) {
    int idx = (int)sid;
    if(idx < 0 || idx >= MAX_STRATEGIES || g_strategy_trades[idx] == 0) return 0.0;
    return (double)g_strategy_wins[idx] / (double)g_strategy_trades[idx] * 100.0;
}

double GetStrategyProfitFactor(StrategyId sid) {
    int idx = (int)sid;
    if(idx < 0 || idx >= MAX_STRATEGIES || g_strategy_gross_loss[idx] == 0) return 0.0;
    return g_strategy_gross_profit[idx] / g_strategy_gross_loss[idx];
}

double GetStrategyAvgRR(StrategyId sid) {
    int idx = (int)sid;
    if(idx < 0 || idx >= MAX_STRATEGIES || g_strategy_trades[idx] == 0) return 0.0;
    return g_strategy_total_rr[idx] / (double)g_strategy_trades[idx];
}

double GetStrategyAvgPayoff(StrategyId sid) {
    int idx = (int)sid;
    if(idx < 0 || idx >= MAX_STRATEGIES || g_strategy_trades[idx] == 0) return 0.0;
    return g_strategy_net_pnl[idx] / (double)g_strategy_trades[idx];
}

double GetStrategyAvgHoldingTimeMin(StrategyId sid) {
    int idx = (int)sid;
    if(idx < 0 || idx >= MAX_STRATEGIES || g_strategy_trades[idx] == 0) return 0.0;
    return (g_strategy_total_holding_time[idx] / (double)g_strategy_trades[idx]) / 60.0; // Convert to minutes
}

void PrintStrategyStatsSummary() {
    Print("=== STRATEGY STATISTICS SUMMARY ===");
    for(int i = 0; i < MAX_STRATEGIES; i++) {
        StrategyId sid = (StrategyId)i;
        if(g_strategy_trades[i] > 0) {
            Print("Strategy: ", GetStrategyShort(sid), " (", GetStrategyName(sid), ")");
            Print("  Trades: ", g_strategy_trades[i],
                  " | Wins: ", g_strategy_wins[i],
                  " | WinRate: ", DoubleToString(GetStrategyWinRate(sid), 1), "%");
            Print("  Net P&L: ", DoubleToString(g_strategy_net_pnl[i], 2),
                  " | Gross Profit: ", DoubleToString(g_strategy_gross_profit[i], 2),
                  " | Gross Loss: ", DoubleToString(g_strategy_gross_loss[i], 2));
            Print("  Profit Factor: ", DoubleToString(GetStrategyProfitFactor(sid), 2),
                  " | Avg RR: ", DoubleToString(GetStrategyAvgRR(sid), 2),
                  " | Avg Payoff: ", DoubleToString(GetStrategyAvgPayoff(sid), 2));
            Print("  Max DD Sequence: ", g_strategy_max_dd_seq[i],
                  " | Avg Hold Time: ", DoubleToString(GetStrategyAvgHoldingTimeMin(sid), 1), " min");
            Print("  ---");
        }
    }
    Print("=== END STRATEGY SUMMARY ===");
}

//--- Structures
struct SessionTimes {
    datetime tokyo_open, tokyo_close, london_open, london_end, ny_open, ny_end;
};

struct ModuleStats {
    long trades;
    long wins;
    double pf;
    double pnl;
    long max_dd_seq;
};



struct RiskLimits {
    double day_loss;
    double week_loss;
    int consec_losses;
    bool locked_day;
    bool locked_week;
    int trades_today;
    datetime last_reset_date;

    // Copy constructor to fix deprecation warning
    RiskLimits(const RiskLimits& other) {
        day_loss = other.day_loss;
        week_loss = other.week_loss;
        consec_losses = other.consec_losses;
        locked_day = other.locked_day;
        locked_week = other.locked_week;
        trades_today = other.trades_today;
        last_reset_date = other.last_reset_date;
    }

    // Default constructor
    RiskLimits() {
        day_loss = 0;
        week_loss = 0;
        consec_losses = 0;
        locked_day = false;
        locked_week = false;
        trades_today = 0;
        last_reset_date = 0;
    }
};



//--- Global variables
StrategyId g_active = S_NONE;
datetime g_last_exit_time;
IndCache g_cache;
double g_slippage_ring[];
int g_slip_index = 0;

//--- Exit reason tracking system
struct ExitReasonTracker {
    ulong ticket;
    string exit_reason;
    datetime timestamp;
};

ExitReasonTracker g_exit_reasons[];
int g_exit_reason_count = 0;
const int MAX_EXIT_REASONS = 100;

//--- Trailing stop tracking
struct TrailingStopTracker {
    ulong ticket;
    double last_sl;
    datetime last_modification;
};

TrailingStopTracker g_trailing_stops[];
int g_trailing_stop_count = 0;
const int MAX_TRAILING_STOPS = 50;

//--- Trade meta lookup system
TradeMeta g_trade_metas[];
ulong g_trade_tickets[];
int g_meta_count = 0;
const int MAX_TRADE_METAS = 1000;  // Maximum number of concurrent trade metas to store

//--- Global Strategy Statistics System
long g_strategy_trades[MAX_STRATEGIES];      // Total trades per strategy
long g_strategy_wins[MAX_STRATEGIES];        // Winning trades per strategy
double g_strategy_gross_profit[MAX_STRATEGIES];  // Total gross profit per strategy
double g_strategy_gross_loss[MAX_STRATEGIES];    // Total gross loss per strategy
double g_strategy_net_pnl[MAX_STRATEGIES];       // Net P&L per strategy
long g_strategy_max_dd_seq[MAX_STRATEGIES];      // Max consecutive losses per strategy
long g_strategy_current_dd_seq[MAX_STRATEGIES];  // Current consecutive losses per strategy
double g_strategy_total_rr[MAX_STRATEGIES];      // Sum of all RR ratios for average calculation
double g_strategy_total_holding_time[MAX_STRATEGIES]; // Sum of holding times in seconds

//--- Priority order (higher number = higher priority)
int GetStrategyPriority(StrategyId sid) {
    switch(sid) {
        case S_SWEEP: return 100;
        case S_ORB: return 90;
        case S_VWAP_TR: return 80;
        case S_KELTNER: return 70;
        case S_VWAP_FADE: return 60;
        case S_ASIA: return 50;
        case S_NEWS: return 40;
        // Experimental modules have lower priority
        case S_DOGWALK: return 30;
        case S_ASIANEARLY: return 25;
        case S_VOLOSC: return 20;
        default: return 0;
    }
}

//--- Forward declarations
datetime GetSessionStartTime(SessionId session);

//--- Helper functions
double Pts(double price_delta) {
    return price_delta / _Point;
}

double PriceFromPts(double pts, bool up) {
    return up ? (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + pts * _Point) :
                (SymbolInfoDouble(_Symbol, SYMBOL_BID) - pts * _Point);
}

bool IsSpreadOK() {
    double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
    return spread <= Inp_MaxSpreadPts;
}

double CalcLotsByRisk(double stop_pts, double risk_pct) {
    return g_risk_manager.CalcLotsByRisk(stop_pts, risk_pct);
}

//--- Welford algorithm for running standard deviation
class WelfordStdDev {
private:
    int count;
    double mean;
    double m2;

public:
    WelfordStdDev() : count(0), mean(0), m2(0) {}

    void Update(double value) {
        count++;
        double delta = value - mean;
        mean += delta / count;
        double delta2 = value - mean;
        m2 += delta * delta2;
    }

    double GetMean() { return mean; }
    double GetVariance() { return count > 1 ? m2 / (count - 1) : 0; }
    double GetStdDev() { return MathSqrt(GetVariance()); }
    int GetCount() { return count; }
    void Reset() { count = 0; mean = 0; m2 = 0; }
};

//--- Enhanced VWAP calculation
struct VWAPData {
    double vwap;
    double std_dev;
    int slope_pts;
    double sum_pv;
    double sum_v;
    WelfordStdDev welford;
    datetime session_start;

    void Reset(datetime start_time) {
        vwap = 0;
        std_dev = 0;
        slope_pts = 0;
        sum_pv = 0;
        sum_v = 0;
        welford.Reset();
        session_start = start_time;
    }

    void Update(double price, double volume) {
        sum_pv += price * volume;
        sum_v += volume;
        vwap = (sum_v > 0) ? sum_pv / sum_v : price;
        welford.Update(price);
        std_dev = welford.GetStdDev();
    }
};

//--- Calculate EMA55 envelope
void CalcEMAEnvelope(double ema_value, double& hi, double& lo) {
    // More sophisticated envelope calculation
    double atr_factor = g_cache.ATR * 0.3; // 30% of ATR as envelope
    hi = ema_value + atr_factor;
    lo = ema_value - atr_factor;
}

//--- Calculate Keltner Channels
void CalcKeltnerChannels(double ema, double atr, double mult, double& upper, double& middle, double& lower) {
    middle = ema;
    upper = middle + mult * atr;
    lower = middle - mult * atr;
}

SessionId GetCurrentSession() {
    return g_session_calendar.CurrentSession();
}

bool CanTrade() {
    if(!g_risk_manager.CanTrade(0)) return false;

    if(TimeCurrent() - g_last_exit_time < Inp_CooldownSec) {
        g_telemetry.IncrementReject("Cooldown");
        return false;
    }

    if(g_spread_guard.TooWide()) {
        g_telemetry.IncrementReject("SpreadTooWide");
        return false;
    }

    if(g_news_guard.IsNewsBlock()) {
        g_telemetry.IncrementReject("NewsBlock");
        return false;
    }

    if(Inp_OnePosAtATime && PositionsTotal() > 0) {
        g_telemetry.IncrementReject("OnePosAtATime");
        return false;
    }

    return true;
}

//--- Indicator cache implementation
void IndCache::Init(string symbol) {
    h_ATR = iATR(symbol, Inp_TF_ATRADX, Inp_ATR_Period);
    h_ADX = iADX(symbol, Inp_TF_ATRADX, Inp_ADX_Period);
    h_RSI = iRSI(symbol, PERIOD_M5, Inp_RSI_Period, PRICE_CLOSE);
    h_EMA = iMA(symbol, PERIOD_M5, Inp_EMA_Trend, 0, MODE_EMA, PRICE_CLOSE);
    h_SMA = iMA(symbol, PERIOD_H1, Inp_SMA_Bias, 0, MODE_SMA, PRICE_CLOSE);
    h_Keltner_EMA = iMA(symbol, Inp_TF_ATRADX, Inp_Keltner_EMA, 0, MODE_EMA, PRICE_CLOSE);
    h_Keltner_ATR = iATR(symbol, Inp_TF_ATRADX, Inp_Keltner_ATR);
    
    Warmed = false;
}

bool IndCache::Update() {
    double atr_buf[], adx_buf[], rsi_buf[], ema_buf[], sma_buf[], kelt_ema_buf[], kelt_atr_buf[];
    
    if(CopyBuffer(h_ATR, 0, 0, 1, atr_buf) <= 0) return false;
    if(CopyBuffer(h_ADX, 0, 0, 1, adx_buf) <= 0) return false;
    if(CopyBuffer(h_RSI, 0, 0, 1, rsi_buf) <= 0) return false;
    if(CopyBuffer(h_EMA, 0, 0, 1, ema_buf) <= 0) return false;
    if(CopyBuffer(h_SMA, 0, 0, 1, sma_buf) <= 0) return false;
    if(CopyBuffer(h_Keltner_EMA, 0, 0, 1, kelt_ema_buf) <= 0) return false;
    if(CopyBuffer(h_Keltner_ATR, 0, 0, 1, kelt_atr_buf) <= 0) return false;
    
    ATR = (double)atr_buf[0];
    ADX = (double)adx_buf[0];
    RSI = (double)rsi_buf[0];
    SMA200 = (double)sma_buf[0];
    
    // Keltner channels
    Keltner_mid = kelt_ema_buf[0];
    Keltner_up = Keltner_mid + Inp_Keltner_Mult * kelt_atr_buf[0];
    Keltner_dn = Keltner_mid - Inp_Keltner_Mult * kelt_atr_buf[0];
    
    // Determine bias
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(current_price > SMA200) bias = B_LONG;
    else if(current_price < SMA200) bias = B_SHORT;
    else bias = B_NONE;
    
    // Determine regime
    if(ADX < 20) regime = REG_RANGE;
    else if(ADX > 35) regime = REG_SPIKE;
    else regime = REG_TREND;
    
    // Calculate EMA envelopes using helper function
    CalcEMAEnvelope(ema_buf[0], EMA_hi, EMA_lo);

    // Calculate session VWAP (simplified - using typical price)
    if(Inp_UseSessionVWAP) {
        CalcSessionVWAP();
    }

    Warmed = true;
    return true;
}

void IndCache::CalcSessionVWAP() {
    // Simplified VWAP calculation for current session
    SessionId current_session = GetCurrentSession();
    datetime session_start = GetSessionStartTime(current_session);

    if(session_start == 0) {
        VWAP_sess = (iHigh(_Symbol, PERIOD_M5, 0) + iLow(_Symbol, PERIOD_M5, 0) + iClose(_Symbol, PERIOD_M5, 0)) / 3.0;
        VWAP_sd = ATR * 0.5;
        return;
    }

    int start_bar = iBarShift(_Symbol, PERIOD_M5, session_start);
    if(start_bar < 0) start_bar = 100; // Fallback

    double sum_pv = 0, sum_v = 0;
    double prices[];
    ArrayResize(prices, start_bar + 1);

    for(int i = 0; i <= start_bar; i++) {
        double typical_price = (iHigh(_Symbol, PERIOD_M5, i) + iLow(_Symbol, PERIOD_M5, i) + iClose(_Symbol, PERIOD_M5, i)) / 3.0;
        double volume = (double)iVolume(_Symbol, PERIOD_M5, i);
        if(volume == 0) volume = 1; // Fallback for tick volume

        sum_pv += typical_price * volume;
        sum_v += volume;
        prices[i] = typical_price;
    }

    VWAP_sess = (sum_v > 0) ? sum_pv / sum_v : prices[0];

    // Calculate standard deviation
    double sum_sq_dev = 0;
    for(int i = 0; i <= start_bar; i++) {
        double dev = prices[i] - VWAP_sess;
        sum_sq_dev += dev * dev;
    }
    VWAP_sd = MathSqrt(sum_sq_dev / (start_bar + 1));

    // Calculate VWAP slope in points
    if(start_bar >= 5) {
        double vwap_5_bars_ago = (iHigh(_Symbol, PERIOD_M5, 5) + iLow(_Symbol, PERIOD_M5, 5) + iClose(_Symbol, PERIOD_M5, 5)) / 3.0;
        VWAP_slope_pts = (int)Pts(VWAP_sess - vwap_5_bars_ago);
    } else {
        VWAP_slope_pts = 0;
    }
}

datetime GetSessionStartTime(SessionId session) {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    switch(session) {
        case SES_TOKYO:
            dt.hour = Inp_TokyoOpen_H;
            dt.min = Inp_TokyoOpen_M;
            break;
        case SES_LONDON:
            dt.hour = Inp_LondonOpen_H;
            dt.min = Inp_LondonOpen_M;
            break;
        case SES_NY:
            dt.hour = Inp_NYOpen_H;
            dt.min = Inp_NYOpen_M;
            break;
        default:
            return 0;
    }

    dt.sec = 0;
    return StructToTime(dt);
}

//--- NewsGuard class
class NewsGuard {
private:
    datetime news_times[];
    bool news_block_active;

public:
    NewsGuard() : news_block_active(false) {}

    bool IsNewsBlock() {
        if(!Inp_UseNewsFilter) return false;

        datetime current_time = TimeCurrent();

        // Check manual news times array
        for(int i = 0; i < ArraySize(news_times); i++) {
            if(MathAbs(current_time - news_times[i]) <= Inp_NewsBlockMin * 60) {
                return true;
            }
        }

        // Try to use MT5 calendar (simplified check)
        MqlCalendarValue values[];
        if(CalendarValueHistory(values, current_time - 3600, current_time + 3600, NULL, NULL) > 0) {
            for(int i = 0; i < ArraySize(values); i++) {
                if((int)values[i].impact_type == 3) { // 3 = High impact
                    if(MathAbs(current_time - values[i].time) <= Inp_NewsBlockMin * 60) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    void AddNewsTime(datetime news_time) {
        int size = ArraySize(news_times);
        ArrayResize(news_times, size + 1);
        news_times[size] = news_time;
    }
};

//--- SessionCalendar class
class SessionCalendar {
private:
    int gmt_offset;

public:
    bool dst_active;
    SessionCalendar() : gmt_offset(Inp_BrokerGMT_Offset), dst_active(false) {
        UpdateDST();
    }

    void UpdateDST() {
        static bool prev = false;

        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);

        datetime march_last_sunday   = GetLastSunday(dt.year, 3);
        datetime october_last_sunday = GetLastSunday(dt.year, 10);

        datetime current = TimeCurrent();
        bool new_dst = (current >= march_last_sunday && current < october_last_sunday);

        if(Inp_LogVerbose && new_dst != prev) {
            Print("DST Status changed: ", new_dst ? "ACTIVE" : "INACTIVE");
        }
        dst_active = new_dst;
        prev = new_dst;
    }

    datetime GetLastSunday(int year, int month) {
        MqlDateTime dt;
        dt.year = year;
        dt.mon = month;
        dt.day = 31; // Start from end of month
        dt.hour = 2; // 2 AM CET
        dt.min = 0;
        dt.sec = 0;

        datetime temp = StructToTime(dt);
        TimeToStruct(temp, dt);

        // Find last Sunday
        while(dt.day_of_week != 0) { // 0 = Sunday
            dt.day--;
            temp = StructToTime(dt);
            TimeToStruct(temp, dt);
        }

        return temp;
    }

    SessionId CurrentSession() {
        UpdateDST();

        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);

        int effective_offset = gmt_offset + (dst_active ? 1 : 0);
        int cet_hour = (dt.hour + effective_offset) % 24;
        int time_minutes = cet_hour * 60 + dt.min;

        int tokyo_start = Inp_TokyoOpen_H * 60 + Inp_TokyoOpen_M;
        int tokyo_end = Inp_TokyoClose_H * 60 + Inp_TokyoClose_M;
        int london_start = Inp_LondonOpen_H * 60 + Inp_LondonOpen_M;
        int london_end = Inp_LondonEnd_H * 60 + Inp_LondonEnd_M;
        int ny_start = Inp_NYOpen_H * 60 + Inp_NYOpen_M;
        int ny_end = Inp_NYEnd_H * 60 + Inp_NYEnd_M;

        if(time_minutes >= tokyo_start && time_minutes < tokyo_end) return SES_TOKYO;
        if(time_minutes >= london_start && time_minutes < london_end) return SES_LONDON;
        if(time_minutes >= ny_start && time_minutes < ny_end) return SES_NY;

        return SES_OFF;
    }

    bool InWindow(int h1, int m1, int h2, int m2) {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);

        int effective_offset = gmt_offset + (dst_active ? 1 : 0);
        int cet_hour = (dt.hour + effective_offset) % 24;
        int current_minutes = cet_hour * 60 + dt.min;
        int start_minutes = h1 * 60 + m1;
        int end_minutes = h2 * 60 + m2;

        return (current_minutes >= start_minutes && current_minutes <= end_minutes);
    }

    void LogSessionSanity() {
        UpdateDST();

        datetime server_time = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(server_time, dt);

        int effective_offset = gmt_offset + (dst_active ? 1 : 0);
        int cet_hour = (dt.hour + effective_offset) % 24;
        int cet_min = dt.min;

        // Calculate CET timestamp
        MqlDateTime cet_dt = dt;
        cet_dt.hour = cet_hour;
        cet_dt.min = cet_min;
        datetime cet_time = StructToTime(cet_dt);

        SessionId current_session = CurrentSession();

        Print("=== SESSION/DST SANITY LOG ===");
        Print("Server Time: ", TimeToString(server_time, TIME_DATE|TIME_MINUTES));
        Print("CET Time: ", TimeToString(cet_time, TIME_DATE|TIME_MINUTES), " (", cet_hour, ":", StringFormat("%02d", cet_min), ")");
        Print("Effective Offset: ", effective_offset, " (GMT+", gmt_offset, " + DST:", (dst_active ? 1 : 0), ")");
        Print("Current Session: ", EnumToString(current_session));
        Print("London: ", Inp_LondonOpen_H, ":", StringFormat("%02d", Inp_LondonOpen_M), "-", Inp_LondonEnd_H, ":", StringFormat("%02d", Inp_LondonEnd_M), " CET");
        Print("NY: ", Inp_NYOpen_H, ":", StringFormat("%02d", Inp_NYOpen_M), "-", Inp_NYEnd_H, ":", StringFormat("%02d", Inp_NYEnd_M), " CET");
        Print("DST Active: ", dst_active ? "YES" : "NO");
    }
};

//--- Enhanced SpreadSlipGuard
class SpreadSlipGuard {
private:
    double slip_history[];
    int slip_index;
    bool slippage_lock_logged;

public:
    SpreadSlipGuard() : slip_index(0), slippage_lock_logged(false) {
        ArrayResize(slip_history, Inp_SlipRingSize);
        ArrayInitialize(slip_history, 0);
    }

    bool TooWide() {
        // Check spread
        double spread_pts = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
        if(spread_pts > Inp_MaxSpreadPts) {
            if(Inp_LogVerbose) Print("*** TRADING BLOCKED *** Reason: Spread too wide (", DoubleToString(spread_pts, 1), " > ", Inp_MaxSpreadPts, " pts)");
            return true;
        }

        // Check median slippage
        double median_slip = GetMedianSlippage();
        if(median_slip > Inp_MaxSlipPts) {
            if(!slippage_lock_logged) {
                Print("*** TRADING LOCKED *** Reason: Median slippage too high (", DoubleToString(median_slip, 1), " > ", Inp_MaxSlipPts, " pts)");
                slippage_lock_logged = true;
            }
            return true;
        } else {
            slippage_lock_logged = false;
        }

        return false;
    }

    void RecordSlippage(double slip_pts) {
        slip_history[slip_index] = slip_pts;
        slip_index = (slip_index + 1) % Inp_SlipRingSize;
    }

    double GetMedianSlippage() {
        double sorted[];
        ArrayCopy(sorted, slip_history);
        ArraySort(sorted);

        int size = ArraySize(sorted);
        if(size == 0) return 0;

        if(size % 2 == 0) {
            return (sorted[size/2 - 1] + sorted[size/2]) / 2.0;
        } else {
            return sorted[size/2];
        }
    }

    bool FreezeLevelOK() {
        double freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

        // Check if we're not too close to freeze level
        return true; // Simplified - always OK for now
    }
};

//--- RiskManager class
class RiskManager {
private:
    RiskLimits limits;
    datetime last_day_reset;
    datetime last_week_reset;
    bool day_lock_logged;
    bool week_lock_logged;

public:
    RiskManager() : last_day_reset(0), last_week_reset(0), day_lock_logged(false), week_lock_logged(false) {
        limits.day_loss = 0;
        limits.week_loss = 0;
        limits.consec_losses = 0;
        limits.locked_day = false;
        limits.locked_week = false;
        limits.trades_today = 0;
        limits.last_reset_date = 0;
    }

    double CalcLotsByRisk(double stop_pts, double risk_pct) {
        double account_balance = EffectiveBalance();
        double risk_amount = account_balance * risk_pct / 100.0;
        double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        double point_value = tick_value * _Point / tick_size;

        double lots = risk_amount / (stop_pts * point_value);

        double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

        lots = MathMax(lots, min_lot);
        lots = MathMin(lots, max_lot);
        lots = NormalizeDouble(lots / lot_step, 0) * lot_step;

        return lots;
    }

    bool CanTrade(double stop_pts) {
        UpdateLimits();
        if(EffectiveBalance() <= 0.0) {
            if(Inp_LogVerbose) Print("RiskManager: baseline <= 0, not enforcing caps.");
            return (limits.consec_losses < Inp_MaxConsecLosses);
        }
        if(limits.locked_day || limits.locked_week) return false;
        if(limits.consec_losses >= Inp_MaxConsecLosses) return false;

        return true;
    }

    void RegisterOutcome(double pnl) {
        limits.trades_today++;

        if(pnl < 0) {
            limits.consec_losses++;
            limits.day_loss += MathAbs(pnl);
            limits.week_loss += MathAbs(pnl);
        } else {
            limits.consec_losses = 0;
        }

        UpdateLimits();
    }

    // Check if we've reached a new day boundary based on ServerDayStart
    bool IsDayBoundaryReached() {
        datetime current_time = TimeCurrent();

        // Calculate server time with DST adjustment (same logic as SessionCalendar)
        MqlDateTime dt;
        TimeToStruct(current_time, dt);

        // Apply GMT offset and DST
        int effective_offset = Inp_BrokerGMT_Offset + (g_session_calendar.dst_active ? 1 : 0);
        int server_hour = (dt.hour + effective_offset) % 24;

        // Create today's day start time in server time
        MqlDateTime day_start_dt = dt;
        day_start_dt.hour = Inp_ServerDayStart;
        day_start_dt.min = 0;
        day_start_dt.sec = 0;
        datetime todays_day_start = StructToTime(day_start_dt);

        // Adjust for timezone offset
        todays_day_start -= effective_offset * 3600;

        // Check if we've passed today's day start and it's a different date than last reset
        if(current_time >= todays_day_start) {
            MqlDateTime reset_dt;
            TimeToStruct(todays_day_start, reset_dt);
            int reset_date = reset_dt.year * 10000 + reset_dt.mon * 100 + reset_dt.day;

            MqlDateTime last_reset_dt;
            TimeToStruct(limits.last_reset_date, last_reset_dt);
            int last_reset_date_int = last_reset_dt.year * 10000 + last_reset_dt.mon * 100 + last_reset_dt.day;

            return (reset_date != last_reset_date_int);
        }

        return false;
    }

    // Perform daily reset of all risk counters
    void DoDailyReset() {
        datetime current_time = TimeCurrent();

        // Calculate server time with DST adjustment
        MqlDateTime dt;
        TimeToStruct(current_time, dt);
        int effective_offset = Inp_BrokerGMT_Offset + (g_session_calendar.dst_active ? 1 : 0);

        // Create today's day start time
        MqlDateTime day_start_dt = dt;
        day_start_dt.hour = Inp_ServerDayStart;
        day_start_dt.min = 0;
        day_start_dt.sec = 0;
        datetime todays_day_start = StructToTime(day_start_dt);
        todays_day_start -= effective_offset * 3600;

        // Write strategy summary before resetting counters (daily summary trigger)
        if(Inp_WriteCSV) {
            g_telemetry.WriteStrategySummary();
        }

        // Reset daily counters
        double prev_day_loss = limits.day_loss;
        int prev_trades = limits.trades_today;
        int prev_consec = limits.consec_losses;
        bool was_locked = limits.locked_day;

        limits.locked_day = false;
        limits.day_loss = 0;
        limits.trades_today = 0;
        limits.consec_losses = 0;
        limits.last_reset_date = todays_day_start;

        // Reset logging flags
        day_lock_logged = false;

        // Check for weekly reset
        TimeToStruct(todays_day_start, dt);
        if(dt.day_of_week == 1) { // Monday
            double prev_week_loss = limits.week_loss;
            bool was_week_locked = limits.locked_week;

            limits.week_loss = 0;
            limits.locked_week = false;
            week_lock_logged = false;

            Print("=== WEEKLY RESET @ ", TimeToString(current_time, TIME_DATE|TIME_MINUTES),
                  " (ServerDayStart ", StringFormat("%02d", Inp_ServerDayStart), ":00) ===");
            Print("Previous week loss: ", DoubleToString(prev_week_loss, 2),
                  " | Was locked: ", was_week_locked ? "YES" : "NO");
        }

        // Log daily reset
        Print("=== DAILY RESET @ ", TimeToString(current_time, TIME_DATE|TIME_MINUTES),
              " (ServerDayStart ", StringFormat("%02d", Inp_ServerDayStart), ":00) ===");
        Print("Previous day loss: ", DoubleToString(prev_day_loss, 2),
              " | Trades: ", prev_trades,
              " | Consec losses: ", prev_consec,
              " | Was locked: ", was_locked ? "YES" : "NO");
        Print("Reset values - Day loss: 0.00 | Trades: 0 | Consec losses: 0 | Locked: NO");
    }

    void UpdateLimits() {
        // Check for daily reset first
        if(IsDayBoundaryReached()) {
            DoDailyReset();
        }

        // Check limits and apply locks
        double account_balance = EffectiveBalance();
        if(account_balance <= 0.0) {
            if(Inp_LogVerbose) Print("RiskManager: baseline <= 0 – skipping day/week caps.");
            return;
        }

        // Check daily loss cap
        if(limits.day_loss >= account_balance * Inp_DailyMaxLossPct / 100.0) {
            if(!limits.locked_day) {
                limits.locked_day = true;
                day_lock_logged = false;
                // Close all open positions due to daily lock
                CloseAllPositionsDueToDailyLock();
            }
            if(!day_lock_logged) {
                Print("*** TRADING LOCKED *** Reason: Daily loss cap reached (",
                      DoubleToString(limits.day_loss, 2), "/",
                      DoubleToString(account_balance * Inp_DailyMaxLossPct / 100.0, 2), ")");
                day_lock_logged = true;
            }
        }

        // Check weekly loss cap
        if(limits.week_loss >= account_balance * Inp_WeeklyMaxLossPct / 100.0) {
            if(!limits.locked_week) {
                limits.locked_week = true;
                week_lock_logged = false;
                // Close all open positions due to weekly lock
                CloseAllPositionsDueToWeeklyLock();
            }
            if(!week_lock_logged) {
                Print("*** TRADING LOCKED *** Reason: Weekly loss cap reached (",
                      DoubleToString(limits.week_loss, 2), "/",
                      DoubleToString(account_balance * Inp_WeeklyMaxLossPct / 100.0, 2), ")");
                week_lock_logged = true;
            }
        }
    }

    RiskLimits GetLimits() { return limits; }
    int GetConsecLosses() { return limits.consec_losses; }
    double GetDayLoss() { return limits.day_loss; }
    double GetWeekLoss() { return limits.week_loss; }
    int GetTradesToday() { return limits.trades_today; }
    bool IsLockedDay() { return limits.locked_day; }
    bool IsLockedWeek() { return limits.locked_week; }

    // Close all positions due to daily/weekly lock
    void CloseAllPositionsDueToDailyLock() {
        for(int i = 0; i < PositionsTotal(); i++) {
            if(PositionSelectByTicket(PositionGetTicket(i))) {
                if(PositionGetInteger(POSITION_MAGIC) == Inp_Magic) {
                    ulong ticket = PositionGetTicket(i);
                    StoreExitReason(ticket, "DAILY_LOCK");
                    g_exec_manager.PositionClose(ticket);
                }
            }
        }
    }

    void CloseAllPositionsDueToWeeklyLock() {
        for(int i = 0; i < PositionsTotal(); i++) {
            if(PositionSelectByTicket(PositionGetTicket(i))) {
                if(PositionGetInteger(POSITION_MAGIC) == Inp_Magic) {
                    ulong ticket = PositionGetTicket(i);
                    StoreExitReason(ticket, "WEEKLY_LOCK");
                    g_exec_manager.PositionClose(ticket);
                }
            }
        }
    }
};

//--- ExecManager class
class ExecManager {
private:
    CTrade trade_obj;

public:
    ExecManager() {
        trade_obj.SetExpertMagicNumber(Inp_Magic);
        trade_obj.SetDeviationInPoints(Inp_MaxSlipPts);
    }

    bool ValidatePrice(double price, bool is_buy) {
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double spread = ask - bid;

        // Basic price validation
        if(is_buy && MathAbs(price - ask) > spread * 2) return false;
        if(!is_buy && MathAbs(price - bid) > spread * 2) return false;

        return true;
    }

    bool Buy(double lots, string symbol, double price, double sl, double tp, string comment = "") {
        if(!ValidatePrice(price == 0 ? SymbolInfoDouble(symbol, SYMBOL_ASK) : price, true)) {
            if(Inp_LogVerbose) Print("Buy order rejected: Invalid price");
            return false;
        }

        // Normalize prices
        sl = NormalizeDouble(sl, _Digits);
        tp = NormalizeDouble(tp, _Digits);

        // Note: Comment functionality not available in CTrade class
        // Comments are handled through trade meta system instead

        bool result = trade_obj.Buy(lots, symbol, price, sl, tp);

        // Retry once on requote/invalid price
        if(!result) {
            uint error = GetLastError();
            if(error == TRADE_RETCODE_REQUOTE || error == TRADE_RETCODE_INVALID_PRICE) {
                Sleep(100);
                result = trade_obj.Buy(lots, symbol, 0, sl, tp); // Market price retry
                if(Inp_LogVerbose) Print("Buy retry after error ", error, ": ", result ? "SUCCESS" : "FAILED");
            }

            // Final fail logging
            if(!result) {
                Print("Buy FINAL FAIL: Symbol=", symbol, " Price=", DoubleToString(price, _Digits),
                      " SL=", DoubleToString(sl, _Digits), " TP=", DoubleToString(tp, _Digits),
                      " Error=", IntegerToString(error));
            }
        }

        return result;
    }

    bool Sell(double lots, string symbol, double price, double sl, double tp, string comment = "") {
        if(!ValidatePrice(price == 0 ? SymbolInfoDouble(symbol, SYMBOL_BID) : price, false)) {
            if(Inp_LogVerbose) Print("Sell order rejected: Invalid price");
            return false;
        }

        // Normalize prices
        sl = NormalizeDouble(sl, _Digits);
        tp = NormalizeDouble(tp, _Digits);

        // Note: Comment functionality not available in CTrade class
        // Comments are handled through trade meta system instead

        bool result = trade_obj.Sell(lots, symbol, price, sl, tp);

        // Retry once on requote/invalid price
        if(!result) {
            uint error = GetLastError();
            if(error == TRADE_RETCODE_REQUOTE || error == TRADE_RETCODE_INVALID_PRICE) {
                Sleep(100);
                result = trade_obj.Sell(lots, symbol, 0, sl, tp); // Market price retry
                if(Inp_LogVerbose) Print("Sell retry after error ", error, ": ", result ? "SUCCESS" : "FAILED");
            }

            // Final fail logging
            if(!result) {
                Print("Sell FINAL FAIL: Symbol=", symbol, " Price=", DoubleToString(price, _Digits),
                      " SL=", DoubleToString(sl, _Digits), " TP=", DoubleToString(tp, _Digits),
                      " Error=", IntegerToString(error));
            }
        }

        return result;
    }

    bool BuyStop(double lots, double price, string symbol, double sl, double tp, string comment = "") {
        sl = NormalizeDouble(sl, _Digits);
        tp = NormalizeDouble(tp, _Digits);
        price = NormalizeDouble(price, _Digits);

        // Note: Comment functionality not available in CTrade class
        // Comments are handled through trade meta system instead

        bool result = trade_obj.BuyStop(lots, price, symbol, sl, tp);
        if(!result) {
            uint error = GetLastError();
            Print("BuyStop FAILED: Symbol=", symbol, " Price=", DoubleToString(price, _Digits),
                  " SL=", DoubleToString(sl, _Digits), " TP=", DoubleToString(tp, _Digits),
                  " Error=", IntegerToString(error));
        }
        return result;
    }

    bool SellStop(double lots, double price, string symbol, double sl, double tp, string comment = "") {
        sl = NormalizeDouble(sl, _Digits);
        tp = NormalizeDouble(tp, _Digits);
        price = NormalizeDouble(price, _Digits);

        // Note: Comment functionality not available in CTrade class
        // Comments are handled through trade meta system instead

        bool result = trade_obj.SellStop(lots, price, symbol, sl, tp);
        if(!result) {
            uint error = GetLastError();
            Print("SellStop FAILED: Symbol=", symbol, " Price=", DoubleToString(price, _Digits),
                  " SL=", DoubleToString(sl, _Digits), " TP=", DoubleToString(tp, _Digits),
                  " Error=", IntegerToString(error));
        }
        return result;
    }

    bool OrderDelete(ulong ticket) {
        return trade_obj.OrderDelete(ticket);
    }

    bool PositionClose(ulong ticket) {
        return trade_obj.PositionClose(ticket);
    }

    ulong ResultOrder() { return trade_obj.ResultOrder(); }
    double ResultPrice() { return trade_obj.ResultPrice(); }
};

//--- Telemetry class
class Telemetry {
private:
    int csv_handle;
    int session_csv_handle;
    int strategy_csv_handle;
    string csv_filename;
    string session_csv_filename;
    string strategy_csv_filename;

    // Daily rejection counters
    int reject_spread_too_wide;
    int reject_slippage_lock;
    int reject_news_block;
    int reject_one_pos_busy;
    int reject_adx_out_of_band;
    int reject_session_off;
    int reject_cooldown;
    int reject_arm_failed;
    datetime last_reset_date;

public:
    Telemetry() : csv_handle(INVALID_HANDLE), session_csv_handle(INVALID_HANDLE), strategy_csv_handle(INVALID_HANDLE) {
        ResetDailyCounters();
    }

    bool InitCSV() {
        if(!Inp_WriteCSV) return true;

        csv_filename = Inp_EA_Tag + "_trades_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
        session_csv_filename = Inp_EA_Tag + "_sessions_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
        strategy_csv_filename = Inp_EA_Tag + "_strategy_summary_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";

        csv_handle = FileOpen(csv_filename, FILE_WRITE | FILE_CSV);
        session_csv_handle = FileOpen(session_csv_filename, FILE_WRITE | FILE_CSV);
        strategy_csv_handle = FileOpen(strategy_csv_filename, FILE_WRITE | FILE_CSV);

        if(csv_handle != INVALID_HANDLE) {
            // Comprehensive CSV header with all trade metrics including partial close support
            FileWrite(csv_handle,
                "ts", "ord_id", "sid", "strategy_name", "strategy_short", "dir",
                "entry", "sl", "tp", "exit", "pnl", "pnl_pct", "rr_ratio",
                "spread", "slip", "mae", "mfe", "mae_pct", "mfe_pct",
                "atr", "adx", "rsi", "vwap_dev", "vwap_slope",
                "session", "regime", "bias", "holding_sec", "exit_reason",
                "entry_time", "exit_time", "lots", "commission",
                "parent_ticket", "partial_sequence", "original_lots", "remaining_lots"
            );
            Print("Trades CSV file created: ", csv_filename);
        } else {
            Print("ERROR: Failed to create trades CSV file: ", csv_filename);
            return false;
        }

        if(session_csv_handle != INVALID_HANDLE) {
            FileWrite(session_csv_handle, "date", "session", "trades", "wins", "pf", "pnl", "max_dd_seq", "median_spread", "median_slip",
                     "reject_spread", "reject_slip", "reject_news", "reject_onepos", "reject_adx", "reject_session", "reject_cooldown", "reject_arm");
            Print("Session CSV file created: ", session_csv_filename);
        } else {
            Print("ERROR: Failed to create session CSV file: ", session_csv_filename);
        }

        if(strategy_csv_handle != INVALID_HANDLE) {
            FileWrite(strategy_csv_handle, "timestamp", "strategy_id", "strategy_name", "strategy_short", "trades", "wins", "win_rate_pct",
                     "profit_factor", "net_pnl", "gross_profit", "gross_loss", "avg_rr_ratio", "avg_payoff", "max_dd_sequence", "avg_holding_time_min");
            Print("Strategy Summary CSV file created: ", strategy_csv_filename);
        } else {
            Print("ERROR: Failed to create strategy summary CSV file: ", strategy_csv_filename);
        }

        return true;
    }

    void WriteTrade(const TradeMeta& meta, double exit_price, double pnl, datetime exit_time, string exit_reason = "NORMAL") {
        if(csv_handle == INVALID_HANDLE) return;

        // Calculate derived metrics
        double lots = meta.lots;
        double entry = meta.entry_price;
        double sl = meta.planned_sl;
        double tp = meta.planned_tp;

        // Calculate percentage PnL
        double pnl_pct = (lots > 0) ? (pnl / (lots * entry * 100)) * 100 : 0;

        // Calculate Risk/Reward ratio
        double risk_pts = MathAbs(entry - sl) / _Point;
        double reward_pts = MathAbs(exit_price - entry) / _Point;
        double rr_ratio = (risk_pts > 0) ? reward_pts / risk_pts : 0;

        // Calculate MAE/MFE (simplified - would need tick data for accuracy)
        double mae = 0, mfe = 0, mae_pct = 0, mfe_pct = 0;
        // TODO: Implement proper MAE/MFE calculation with position monitoring

        // Calculate holding time in seconds
        int holding_sec = (int)(exit_time - meta.entry_time);

        // Determine direction based on trade type
        string direction = "UNKNOWN";
        if(sl > 0 && tp > 0) {
            if(entry < sl) direction = "BUY";   // SL above entry = long position
            else direction = "SELL";            // SL below entry = short position
        }

        FileWrite(csv_handle,
            TimeToString(exit_time, TIME_DATE|TIME_SECONDS),
            meta.ticket,
            EnumToString(meta.sid),
            meta.strategy_name,
            meta.strategy_short,
            direction,
            DoubleToString(entry, _Digits),
            DoubleToString(sl, _Digits),
            DoubleToString(tp, _Digits),
            DoubleToString(exit_price, _Digits),
            DoubleToString(pnl, 2),
            DoubleToString(pnl_pct, 2),
            DoubleToString(rr_ratio, 2),
            DoubleToString(meta.entry_spread, 1),
            DoubleToString(meta.entry_slip, 1),
            DoubleToString(mae, _Digits),
            DoubleToString(mfe, _Digits),
            DoubleToString(mae_pct, 2),
            DoubleToString(mfe_pct, 2),
            DoubleToString(meta.entry_atr, _Digits),
            DoubleToString(meta.entry_adx, 1),
            "0", // RSI placeholder - not in meta
            DoubleToString(meta.entry_vwap_dev, 2),
            "0", // VWAP slope placeholder
            EnumToString(meta.session),
            EnumToString(meta.regime),
            EnumToString(meta.bias),
            holding_sec,
            exit_reason,
            TimeToString(meta.entry_time, TIME_DATE|TIME_SECONDS),
            TimeToString(exit_time, TIME_DATE|TIME_SECONDS),
            DoubleToString(lots, 2),
            "0", // Commission placeholder
            IntegerToString(meta.parent_ticket),
            IntegerToString(meta.partial_sequence),
            DoubleToString(meta.original_lots, 2),
            DoubleToString(meta.remaining_lots, 2)
        );
        FileFlush(csv_handle);
    }

    // Legacy WriteTrade method for backward compatibility
    void WriteTrade(string strategy, string direction, double entry, double sl, double tp, double exit, double pnl, ulong order_id, datetime open_time) {
        // Create a minimal TradeMeta for legacy calls
        TradeMeta legacy_meta;
        legacy_meta.ticket = order_id;
        legacy_meta.strategy_name = strategy;
        legacy_meta.strategy_short = strategy;
        legacy_meta.entry_price = entry;
        legacy_meta.planned_sl = sl;
        legacy_meta.planned_tp = tp;
        legacy_meta.entry_time = open_time;
        legacy_meta.lots = 0.1; // Default lot size
        legacy_meta.session = g_session_calendar.CurrentSession();
        legacy_meta.regime = g_cache.regime;
        legacy_meta.bias = B_NONE;
        legacy_meta.entry_spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
        legacy_meta.entry_slip = 0;
        legacy_meta.entry_atr = g_cache.ATR;
        legacy_meta.entry_adx = g_cache.ADX;
        legacy_meta.entry_vwap_dev = 0;

        WriteTrade(legacy_meta, exit, pnl, TimeCurrent(), "LEGACY");
    }

    void WriteSessionSummary(SessionId session, int trades, int wins, double pf, double pnl, int max_dd_seq) {
        if(session_csv_handle == INVALID_HANDLE) return;

        double median_spread = 0; // Could be calculated from recent data
        double median_slip = g_spread_guard.GetMedianSlippage();

        FileWrite(session_csv_handle,
            TimeToString(TimeCurrent(), TIME_DATE),
            EnumToString(session),
            trades,
            wins,
            DoubleToString(pf, 2),
            DoubleToString(pnl, 2),
            max_dd_seq,
            DoubleToString(median_spread, 1),
            DoubleToString(median_slip, 1),
            reject_spread_too_wide,
            reject_slippage_lock,
            reject_news_block,
            reject_one_pos_busy,
            reject_adx_out_of_band,
            reject_session_off,
            reject_cooldown,
            reject_arm_failed
        );
        FileFlush(session_csv_handle);
    }

    void WriteStrategySummary() {
        if(strategy_csv_handle == INVALID_HANDLE) return;

        string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);

        // Write summary for each strategy that has trades
        for(int i = 0; i < MAX_STRATEGIES; i++) {
            StrategyId sid = (StrategyId)i;

            // Skip strategies with no trades
            if(g_strategy_trades[i] == 0) continue;

            // Calculate derived metrics
            double win_rate = GetStrategyWinRate(sid);
            double profit_factor = GetStrategyProfitFactor(sid);
            double avg_rr = GetStrategyAvgRR(sid);
            double avg_payoff = GetStrategyAvgPayoff(sid);
            double avg_holding_time_min = GetStrategyAvgHoldingTimeMin(sid);

            FileWrite(strategy_csv_handle,
                timestamp,
                (int)sid,
                GetStrategyName(sid),
                GetStrategyShort(sid),
                g_strategy_trades[i],
                g_strategy_wins[i],
                DoubleToString(win_rate, 2),
                DoubleToString(profit_factor, 2),
                DoubleToString(g_strategy_net_pnl[i], 2),
                DoubleToString(g_strategy_gross_profit[i], 2),
                DoubleToString(g_strategy_gross_loss[i], 2),
                DoubleToString(avg_rr, 3),
                DoubleToString(avg_payoff, 2),
                g_strategy_max_dd_seq[i],
                DoubleToString(avg_holding_time_min, 1)
            );
        }
        FileFlush(strategy_csv_handle);

        if(Inp_LogVerbose) {
            Print("Strategy summary written to CSV: ", strategy_csv_filename);
        }
    }

    void CloseCSV() {
        if(csv_handle != INVALID_HANDLE) {
            FileClose(csv_handle);
            csv_handle = INVALID_HANDLE;
        }
        if(session_csv_handle != INVALID_HANDLE) {
            FileClose(session_csv_handle);
            session_csv_handle = INVALID_HANDLE;
        }
        if(strategy_csv_handle != INVALID_HANDLE) {
            FileClose(strategy_csv_handle);
            strategy_csv_handle = INVALID_HANDLE;
        }
    }

    void LogVerbose(string module, string message) {
        if(Inp_LogVerbose) {
            Print("[", module, "] ", message);
        }
    }

    void ResetDailyCounters() {
        reject_spread_too_wide = 0;
        reject_slippage_lock = 0;
        reject_news_block = 0;
        reject_one_pos_busy = 0;
        reject_adx_out_of_band = 0;
        reject_session_off = 0;
        reject_cooldown = 0;
        reject_arm_failed = 0;

        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        last_reset_date = TimeCurrent() - dt.hour * 3600 - dt.min * 60 - dt.sec;
    }

    void CheckDailyReset() {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        datetime current_day = TimeCurrent() - dt.hour * 3600 - dt.min * 60 - dt.sec;

        if(current_day != last_reset_date) {
            ResetDailyCounters();
        }
    }

    void IncrementReject(string reason) {
        CheckDailyReset();

        if(reason == "SpreadTooWide") reject_spread_too_wide++;
        else if(reason == "SlippageLock") reject_slippage_lock++;
        else if(reason == "NewsBlock") reject_news_block++;
        else if(reason == "OnePosAtATime") reject_one_pos_busy++;
        else if(reason == "ADX_OutOfBand") reject_adx_out_of_band++;
        else if(reason == "SessionOff") reject_session_off++;
        else if(reason == "Cooldown") reject_cooldown++;
        else if(reason == "ArmFailed") reject_arm_failed++;

        if(Inp_LogVerbose) Print("REJECT: ", reason, " (Total today: ", GetRejectCount(reason), ")");
    }

    int GetRejectCount(string reason) {
        if(reason == "SpreadTooWide") return reject_spread_too_wide;
        else if(reason == "SlippageLock") return reject_slippage_lock;
        else if(reason == "NewsBlock") return reject_news_block;
        else if(reason == "OnePosAtATime") return reject_one_pos_busy;
        else if(reason == "ADX_OutOfBand") return reject_adx_out_of_band;
        else if(reason == "SessionOff") return reject_session_off;
        else if(reason == "Cooldown") return reject_cooldown;
        else if(reason == "ArmFailed") return reject_arm_failed;
        return 0;
    }
};

//--- Baseline function for robust balance calculation
double EffectiveBalance() {
    double b = AccountInfoDouble(ACCOUNT_BALANCE);
    if(b <= 0.0) b = AccountInfoDouble(ACCOUNT_EQUITY);
    if(b <= 0.0 && MQLInfoInteger(MQL_TESTER)) {
        double init = TesterStatistics(STAT_INITIAL_DEPOSIT);
        if(init > 0.0) b = init;
    }
    return b;
}

//--- Global service instances
NewsGuard g_news_guard;
SpreadSlipGuard g_spread_guard;
SessionCalendar g_session_calendar;
RiskManager g_risk_manager;
ExecManager g_exec_manager;
Telemetry g_telemetry;

//--- Module Base Class
class ModuleBase {
protected:
    ModState state;
    datetime next_arm_time;
    bool partial_done;
    ulong pend_buy, pend_sell;
    TradeMeta meta;
    ModuleStats stats;

public:
    ModuleBase() : state(M_IDLE), next_arm_time(0), partial_done(false), pend_buy(0), pend_sell(0) {}
    virtual ~ModuleBase() {}

    virtual bool Eligible(const IndCache& cache, SessionId session) = 0;
    virtual bool Arm(const IndCache& cache, SessionId session) = 0;
    virtual void OnTick(const IndCache& cache) = 0;
    virtual void OnExit(bool profit) = 0;
    virtual StrategyId GetId() = 0;

    ModState GetState() { return state; }
    void SetState(ModState s) { state = s; }
};

//--- ORB Module
class ORBModule : public ModuleBase {
private:
    double range_high, range_low;
    datetime range_start, range_end;
    datetime arm_time;
    SessionId armed_session;

public:
    StrategyId GetId() override { return S_ORB; }

    bool Eligible(const IndCache& cache, SessionId session) override {
        if(!Enable_ORB) return false;
        if(session != SES_LONDON && session != SES_NY) {
            g_telemetry.IncrementReject("SessionOff");
            return false;
        }
        if(!cache.Warmed) return false;
        if(cache.ADX < Inp_ORB_ADX_Min || cache.ADX > Inp_ORB_ADX_Max) {
            g_telemetry.IncrementReject("ADX_OutOfBand");
            return false;
        }
        if(TimeCurrent() < next_arm_time) return false;
        if(state != M_IDLE) return false;

        return true;
    }

    bool Arm(const IndCache& cache, SessionId session) override {
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

        // Get range high/low
        int start_bar = iBarShift(_Symbol, PERIOD_M1, session_start);
        if(start_bar < Inp_ORB_RangeMin) {
            next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
            return false;
        }

        range_high = iHigh(_Symbol, PERIOD_M1, iHighest(_Symbol, PERIOD_M1, MODE_HIGH, Inp_ORB_RangeMin, start_bar - Inp_ORB_RangeMin + 1));
        range_low = iLow(_Symbol, PERIOD_M1, iLowest(_Symbol, PERIOD_M1, MODE_LOW, Inp_ORB_RangeMin, start_bar - Inp_ORB_RangeMin + 1));

        double range_pts = Pts(range_high - range_low);
        if(range_pts < 10) {
            next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
            return false; // Minimum range
        }

        // Set pending orders with buffer
        double buffer = cache.ATR * Inp_ORB_BufferATR;
        double buy_price = range_high + buffer;
        double sell_price = range_low - buffer;

        double sl_pts = cache.ATR * Inp_ORB_SL_ATR / _Point;
        double tp1_pts = cache.ATR * Inp_ORB_TP1_ATR / _Point;

        double lots = CalcLotsByRisk(sl_pts, Inp_RiskPerTradePct);

        // Create strategy comment
        string strategy_comment = GetStrategyComment(S_ORB);

        // Reset tickets
        pend_buy = 0;
        pend_sell = 0;

        // Place buy stop with strategy comment
        if(g_exec_manager.BuyStop(lots, buy_price, _Symbol, buy_price - sl_pts * _Point, buy_price + tp1_pts * _Point, strategy_comment)) {
            pend_buy = g_exec_manager.ResultOrder();

            // Create and store trade meta for buy order
            TradeMeta buy_meta = CreateTradeMeta(S_ORB, cache, session, lots, buy_price,
                                               buy_price - sl_pts * _Point, buy_price + tp1_pts * _Point);
            StoreTradeMeta(pend_buy, buy_meta);
        }

        // Place sell stop with strategy comment
        if(g_exec_manager.SellStop(lots, sell_price, _Symbol, sell_price + sl_pts * _Point, sell_price - tp1_pts * _Point, strategy_comment)) {
            pend_sell = g_exec_manager.ResultOrder();

            // Create and store trade meta for sell order
            TradeMeta sell_meta = CreateTradeMeta(S_ORB, cache, session, lots, sell_price,
                                                sell_price + sl_pts * _Point, sell_price - tp1_pts * _Point);
            StoreTradeMeta(pend_sell, sell_meta);
        }

        // Only set M_ARMED if at least one pending order was created
        if(pend_buy > 0 || pend_sell > 0) {
            state = M_ARMED;
            arm_time = TimeCurrent();
            armed_session = GetCurrentSession();
            if(Inp_LogVerbose) Print("ORB Armed: Range ", range_low, "-", range_high, " ATR:", cache.ATR, " Tickets: Buy=", pend_buy, " Sell=", pend_sell);
            return true;
        } else {
            // No tickets created - set short recalc time and return false
            next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;
            if(Inp_LogVerbose) Print("ORB Arm FAILED: No pending orders created");
            return false;
        }
    }

    void OnTick(const IndCache& cache) override {
        if(state == M_ARMED) {
            SessionId cur = GetCurrentSession();

            bool expire_hit = (TimeCurrent() - arm_time) > Inp_ORB_ExpireMin * 60;
            bool session_mismatch = (Inp_ORB_CancelOutOfSession && cur != armed_session);
            bool adx_out_of_band = (g_cache.ADX < Inp_ORB_ADX_Min || g_cache.ADX > Inp_ORB_ADX_Max);

            if(expire_hit || session_mismatch || adx_out_of_band) {
                if(pend_buy > 0)  g_exec_manager.OrderDelete(pend_buy);
                if(pend_sell > 0) g_exec_manager.OrderDelete(pend_sell);
                pend_buy = 0; pend_sell = 0;
                state = M_DONE;
                if(Inp_LogVerbose) Print("ORB disarmed (expire/session/ADX).");
                return;
            }

            // Check if any pending order was filled
            if(pend_buy > 0 && !OrderSelect(pend_buy)) {
                // Buy order was filled, cancel sell order
                if(pend_sell > 0) g_exec_manager.OrderDelete(pend_sell);
                pend_sell = 0;
                state = M_ACTIVE;
                meta.open_time = TimeCurrent();
            }
            else if(pend_sell > 0 && !OrderSelect(pend_sell)) {
                // Sell order was filled, cancel buy order
                if(pend_buy > 0) g_exec_manager.OrderDelete(pend_buy);
                pend_buy = 0;
                state = M_ACTIVE;
                meta.open_time = TimeCurrent();
            }
        }
        else if(state == M_ACTIVE) {
            // Manage active position
            if(PositionsTotal() == 0) {
                state = M_DONE;
                return;
            }

            // Time stop after 20 minutes
            if(TimeCurrent() - meta.open_time > 20 * 60) {
                for(int i = 0; i < PositionsTotal(); i++) {
                    if(PositionSelectByTicket(PositionGetTicket(i))) {
                        if(PositionGetInteger(POSITION_MAGIC) == Inp_Magic) {
                            ulong ticket = PositionGetTicket(i);
                            StoreExitReason(ticket, "TIME_STOP");
                            g_exec_manager.PositionClose(ticket);
                        }
                    }
                }
            }
        }
    }

    void OnExit(bool profit) override {
        stats.trades++;
        if(profit) stats.wins++;

        // Cancel any remaining pending orders
        if(pend_buy > 0) { g_exec_manager.OrderDelete(pend_buy); pend_buy = 0; }
        if(pend_sell > 0) { g_exec_manager.OrderDelete(pend_sell); pend_sell = 0; }

        state = M_DONE;
        next_arm_time = TimeCurrent() + Inp_ORB_RecalcMin * 60;

        if(Inp_LogVerbose) Print("ORB Exit: ", profit ? "Profit" : "Loss", " Stats: ", stats.wins, "/", stats.trades);
    }
};

//--- VWAP Fade Module
class VWAPFadeModule : public ModuleBase {
private:
    double vwap_session;
    double vwap_sd;

public:
    StrategyId GetId() override { return S_VWAP_FADE; }

    bool Eligible(const IndCache& cache, SessionId session) override {
        if(!Enable_VWAP_Fade) return false;
        if(!cache.Warmed) return false;
        if(cache.ADX > Inp_ADX_Max_Fade) return false;
        if(state != M_IDLE) return false;

        // Calculate session VWAP (simplified)
        vwap_session = (iHigh(_Symbol, PERIOD_M5, 0) + iLow(_Symbol, PERIOD_M5, 0) + iClose(_Symbol, PERIOD_M5, 0)) / 3.0;
        vwap_sd = cache.ATR * 0.5; // Simplified SD calculation

        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double deviation = MathAbs(current_price - vwap_session) / vwap_sd;

        if(deviation < Inp_VWAP_FadeZ) return false;

        // RSI filter
        if(current_price > vwap_session && cache.RSI > Inp_RSI_SellMin) return true;
        if(current_price < vwap_session && cache.RSI < Inp_RSI_BuyMax) return true;

        return false;
    }

    bool Arm(const IndCache& cache, SessionId session) override {
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl_pts = cache.ATR * Inp_Fade_SL_ATR / _Point;
        double lots = CalcLotsByRisk(sl_pts, Inp_RiskPerTradePct);

        // Create strategy comment
        string strategy_comment = GetStrategyComment(S_VWAP_FADE);

        bool success = false;
        ulong ticket = 0;

        if(current_price > vwap_session) {
            // Fade high - sell
            double sl_price = current_price + sl_pts * _Point;
            double tp_price = vwap_session;

            if(g_exec_manager.Sell(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_VWAP_FADE, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        } else {
            // Fade low - buy
            double sl_price = current_price - sl_pts * _Point;
            double tp_price = vwap_session;

            if(g_exec_manager.Buy(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_VWAP_FADE, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }

        if(success && Inp_LogVerbose) Print("VWAP Fade Armed: Price ", current_price, " VWAP ", vwap_session, " Ticket: ", ticket);
        return success;
    }

    void OnTick(const IndCache& cache) override {
        if(state == M_ACTIVE) {
            if(PositionsTotal() == 0) {
                state = M_DONE;
                return;
            }

            // Check if ADX breaks threshold - abort trade
            if(cache.ADX > Inp_ADX_Max_Fade + 5) {
                for(int i = 0; i < PositionsTotal(); i++) {
                    if(PositionSelectByTicket(PositionGetTicket(i))) {
                        if(PositionGetInteger(POSITION_MAGIC) == Inp_Magic) {
                            ulong ticket = PositionGetTicket(i);
                            StoreExitReason(ticket, "ADX_BREAK");
                            g_exec_manager.PositionClose(ticket);
                        }
                    }
                }
            }
        }
    }

    void OnExit(bool profit) override {
        stats.trades++;
        if(profit) stats.wins++;

        state = M_DONE;
        if(Inp_LogVerbose) Print("VWAP Fade Exit: ", profit ? "Profit" : "Loss");
    }
};

//--- Keltner Mean Reversion Module
class KeltnerModule : public ModuleBase {
public:
    StrategyId GetId() override { return S_KELTNER; }

    bool Eligible(const IndCache& cache, SessionId session) override {
        if(!Enable_Keltner) return false;
        if(!cache.Warmed) return false;
        if(cache.ADX > Inp_K_ADX_Max) return false;
        if(state != M_IDLE) return false;

        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

        // Check if price touches outer Keltner channel
        if(current_price >= cache.Keltner_up || current_price <= cache.Keltner_dn) {
            return true;
        }

        return false;
    }

    bool Arm(const IndCache& cache, SessionId session) override {
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl_pts = cache.ATR * Inp_K_SL_FactorATR / _Point;
        double lots = CalcLotsByRisk(sl_pts, Inp_RiskPerTradePct);

        // Create strategy comment
        string strategy_comment = GetStrategyComment(S_KELTNER);

        bool success = false;
        ulong ticket = 0;

        if(current_price >= cache.Keltner_up) {
            // Sell at upper band
            double sl_price = cache.Keltner_up + sl_pts * _Point;
            double tp_price = cache.Keltner_mid;

            if(g_exec_manager.Sell(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_KELTNER, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        } else if(current_price <= cache.Keltner_dn) {
            // Buy at lower band
            double sl_price = cache.Keltner_dn - sl_pts * _Point;
            double tp_price = cache.Keltner_mid;

            if(g_exec_manager.Buy(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_KELTNER, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }

        if(success && Inp_LogVerbose) Print("Keltner MR Armed: Price ", current_price, " Bands ", cache.Keltner_dn, "-", cache.Keltner_up, " Ticket: ", ticket);
        return success;
    }

    void OnTick(const IndCache& cache) override {
        if(state == M_ACTIVE && PositionsTotal() == 0) {
            state = M_DONE;
        }
    }

    void OnExit(bool profit) override {
        stats.trades++;
        if(profit) stats.wins++;
        state = M_DONE;
        if(Inp_LogVerbose) Print("Keltner Exit: ", profit ? "Profit" : "Loss");
    }
};

//--- VWAP Trend Re-entry Module
class VWAPTrendModule : public ModuleBase {
public:
    StrategyId GetId() override { return S_VWAP_TR; }

    bool Eligible(const IndCache& cache, SessionId session) override {
        if(!Enable_VWAP_TR) return false;
        if(!cache.Warmed) return false;
        if(cache.ADX < Inp_TR_ADX_Min) return false;
        if(cache.bias == B_NONE) return false;
        if(state != M_IDLE) return false;

        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

        // Check for pullback to EMA in trend direction
        if(cache.bias == B_LONG && current_price > cache.SMA200) {
            // Look for pullback to EMA55 in uptrend
            if(current_price <= cache.EMA_lo && current_price > cache.EMA_lo * 0.999) {
                return true;
            }
        }
        else if(cache.bias == B_SHORT && current_price < cache.SMA200) {
            // Look for pullback to EMA55 in downtrend
            if(current_price >= cache.EMA_hi && current_price < cache.EMA_hi * 1.001) {
                return true;
            }
        }

        return false;
    }

    bool Arm(const IndCache& cache, SessionId session) override {
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl_pts = cache.ATR * Inp_TR_SL_ATR / _Point;
        double lots = CalcLotsByRisk(sl_pts, Inp_RiskPerTradePct);

        // Create strategy comment
        string strategy_comment = GetStrategyComment(S_VWAP_TR);

        bool success = false;
        ulong ticket = 0;

        if(cache.bias == B_LONG) {
            // Buy on pullback in uptrend
            double sl_price = current_price - sl_pts * _Point;
            double tp_price = 0; // No fixed TP for trend following

            if(g_exec_manager.Buy(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_VWAP_TR, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }
        else if(cache.bias == B_SHORT) {
            // Sell on pullback in downtrend
            double sl_price = current_price + sl_pts * _Point;
            double tp_price = 0; // No fixed TP for trend following

            if(g_exec_manager.Sell(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_VWAP_TR, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }

        if(success && Inp_LogVerbose) Print("VWAP TR Armed: Bias ", EnumToString(cache.bias), " Price ", current_price, " Ticket: ", ticket);
        return success;
    }

    void OnTick(const IndCache& cache) override {
        if(state == M_ACTIVE) {
            if(PositionsTotal() == 0) {
                state = M_DONE;
                return;
            }

            // Time stop
            if(TimeCurrent() - meta.open_time > Inp_TR_TimeStopMin * 60) {
                for(int i = 0; i < PositionsTotal(); i++) {
                    if(PositionSelectByTicket(PositionGetTicket(i))) {
                        if(PositionGetInteger(POSITION_MAGIC) == Inp_Magic) {
                            ulong ticket = PositionGetTicket(i);
                            StoreExitReason(ticket, "TIME_STOP");
                            g_exec_manager.PositionClose(ticket);
                        }
                    }
                }
            }
        }
    }

    void OnExit(bool profit) override {
        stats.trades++;
        if(profit) stats.wins++;
        state = M_DONE;
        if(Inp_LogVerbose) Print("VWAP TR Exit: ", profit ? "Profit" : "Loss");
    }
};

//--- Liquidity Sweep Module
class LiquiditySweepModule : public ModuleBase {
private:
    double sweep_level;
    bool sweep_detected;

public:
    StrategyId GetId() override { return S_SWEEP; }

    bool Eligible(const IndCache& cache, SessionId session) override {
        if(!Enable_Sweep) return false;
        if(!cache.Warmed) return false;
        if(state != M_IDLE) return false;

        // Look for liquidity sweep pattern
        double current_high = iHigh(_Symbol, PERIOD_M1, 0);
        double current_low = iLow(_Symbol, PERIOD_M1, 0);
        double current_close = iClose(_Symbol, PERIOD_M1, 0);

        // Find recent swing high/low
        int highest_bar = iHighest(_Symbol, PERIOD_M1, MODE_HIGH, Inp_Sweep_Lookback, 1);
        int lowest_bar = iLowest(_Symbol, PERIOD_M1, MODE_LOW, Inp_Sweep_Lookback, 1);

        if(highest_bar < 0 || lowest_bar < 0) return false;

        double swing_high = iHigh(_Symbol, PERIOD_M1, highest_bar);
        double swing_low = iLow(_Symbol, PERIOD_M1, lowest_bar);

        // Check for sweep above swing high
        if(current_high > swing_high) {
            double wick_size = Pts(current_high - current_close);
            if(wick_size >= Inp_Sweep_MinWickPts && current_close < swing_high) {
                sweep_level = swing_high;
                sweep_detected = true;
                return true;
            }
        }

        // Check for sweep below swing low
        if(current_low < swing_low) {
            double wick_size = Pts(current_close - current_low);
            if(wick_size >= Inp_Sweep_MinWickPts && current_close > swing_low) {
                sweep_level = swing_low;
                sweep_detected = true;
                return true;
            }
        }

        return false;
    }

    bool Arm(const IndCache& cache, SessionId session) override {
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double current_close = iClose(_Symbol, PERIOD_M1, 0);
        double sl_pts = cache.ATR * 0.8 / _Point; // Fixed SL for sweep
        double lots = CalcLotsByRisk(sl_pts + Inp_Sweep_SL_Buffer, Inp_RiskPerTradePct);

        // Create strategy comment
        string strategy_comment = GetStrategyComment(S_SWEEP);

        bool success = false;
        ulong ticket = 0;

        if(current_close < sweep_level) {
            // Sweep above - sell the reversion
            double sl_price = sweep_level + (sl_pts + Inp_Sweep_SL_Buffer) * _Point;
            double tp_price = sweep_level - cache.ATR;

            if(g_exec_manager.Sell(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_SWEEP, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }
        else if(current_close > sweep_level) {
            // Sweep below - buy the reversion
            double sl_price = sweep_level - (sl_pts + Inp_Sweep_SL_Buffer) * _Point;
            double tp_price = sweep_level + cache.ATR;

            if(g_exec_manager.Buy(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_SWEEP, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }

        if(success && Inp_LogVerbose) Print("Liquidity Sweep Armed: Level ", sweep_level, " Current ", current_price, " Ticket: ", ticket);
        return success;
    }

    void OnTick(const IndCache& cache) override {
        if(state == M_ACTIVE && PositionsTotal() == 0) {
            state = M_DONE;
            sweep_detected = false;
        }
    }

    void OnExit(bool profit) override {
        stats.trades++;
        if(profit) stats.wins++;
        state = M_DONE;
        sweep_detected = false;
        if(Inp_LogVerbose) Print("Liquidity Sweep Exit: ", profit ? "Profit" : "Loss");
    }
};

//--- Asian Range Module
class AsianRangeModule : public ModuleBase {
private:
    double asia_high, asia_low;
    bool range_calculated;

public:
    StrategyId GetId() override { return S_ASIA; }

    bool Eligible(const IndCache& cache, SessionId session) override {
        if(!Enable_AsiaRange) return false;
        if(!cache.Warmed) return false;
        if(state != M_IDLE) return false;

        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);

        // Check if we're in the breakout window
        if(dt.hour >= Inp_Asia_Break_H1 && dt.hour <= Inp_Asia_Break_H2) {
            if(!range_calculated) {
                // Calculate Asian session range (00:00-07:00 CET)
                datetime asia_start = TimeCurrent() - dt.hour * 3600 - dt.min * 60 - dt.sec;
                datetime asia_end = asia_start + 7 * 3600;

                int start_bar = iBarShift(_Symbol, PERIOD_M5, asia_start);
                int end_bar = iBarShift(_Symbol, PERIOD_M5, asia_end);

                if(start_bar > 0 && end_bar >= 0) {
                    int bars_count = start_bar - end_bar + 1;
                    asia_high = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, bars_count, end_bar));
                    asia_low = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, bars_count, end_bar));

                    double range_pts = Pts(asia_high - asia_low);
                    if(range_pts >= Inp_Asia_MinRangePts) {
                        range_calculated = true;
                        return true;
                    }
                }
            } else {
                return true; // Range already calculated, ready for breakout
            }
        } else {
            range_calculated = false; // Reset for next day
        }

        return false;
    }

    bool Arm(const IndCache& cache, SessionId session) override {
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double range_mid = (asia_high + asia_low) / 2.0;
        double sl_pts = cache.ATR * 0.8 / _Point;
        double lots = CalcLotsByRisk(sl_pts, Inp_RiskPerTradePct);

        // Create strategy comment
        string strategy_comment = GetStrategyComment(S_ASIA);

        // Check for breakout
        bool success = false;
        ulong ticket = 0;

        if(current_price > asia_high) {
            // Breakout above - buy
            double sl_price = asia_low - sl_pts * _Point;
            double tp_price = range_mid + (asia_high - asia_low);

            if(g_exec_manager.Buy(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_ASIA, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }
        else if(current_price < asia_low) {
            // Breakout below - sell
            double sl_price = asia_high + sl_pts * _Point;
            double tp_price = range_mid - (asia_high - asia_low);

            if(g_exec_manager.Sell(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_ASIA, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }

        if(success && Inp_LogVerbose) Print("Asian Range Armed: Range ", asia_low, "-", asia_high, " Current ", current_price, " Ticket: ", ticket);
        return success;
    }

    void OnTick(const IndCache& cache) override {
        if(state == M_ACTIVE && PositionsTotal() == 0) {
            state = M_DONE;
        }
    }

    void OnExit(bool profit) override {
        stats.trades++;
        if(profit) stats.wins++;
        state = M_DONE;
        if(Inp_LogVerbose) Print("Asian Range Exit: ", profit ? "Profit" : "Loss");
    }
};

//--- News Fade Module
class NewsFadeModule : public ModuleBase {
private:
    datetime last_news_time;
    double spike_start_price;

public:
    StrategyId GetId() override { return S_NEWS; }

    bool Eligible(const IndCache& cache, SessionId session) override {
        if(!Enable_NewsFade) return false;
        if(!cache.Warmed) return false;
        if(state != M_IDLE) return false;

        // Simplified news detection - look for large price moves
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double price_5min_ago = iClose(_Symbol, PERIOD_M1, 5);

        if(price_5min_ago > 0) {
            double move_pts = MathAbs(Pts(current_price - price_5min_ago));

            // If move is > 2*ATR, consider it a news spike
            if(move_pts > 2.0 * cache.ATR / _Point) {
                // Wait for the delay period
                if(TimeCurrent() - last_news_time > Inp_News_FadeDelaySec) {
                    spike_start_price = price_5min_ago;
                    last_news_time = TimeCurrent();
                    return true;
                }
            }
        }

        return false;
    }

    bool Arm(const IndCache& cache, SessionId session) override {
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl_pts = cache.ATR * Inp_News_SL_ATR / _Point;
        double lots = CalcLotsByRisk(sl_pts, Inp_RiskPerTradePct);

        // Create strategy comment
        string strategy_comment = GetStrategyComment(S_NEWS);

        // Fade the spike - trade back towards the starting price
        bool success = false;
        ulong ticket = 0;

        if(current_price > spike_start_price) {
            // Price spiked up - sell
            double sl_price = current_price + sl_pts * _Point;
            double tp_price = spike_start_price + (spike_start_price - current_price) * 0.5;

            if(g_exec_manager.Sell(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_NEWS, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }
        else if(current_price < spike_start_price) {
            // Price spiked down - buy
            double sl_price = current_price - sl_pts * _Point;
            double tp_price = spike_start_price - (current_price - spike_start_price) * 0.5;

            if(g_exec_manager.Buy(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_NEWS, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }

        if(success && Inp_LogVerbose) Print("News Fade Armed: Spike from ", spike_start_price, " to ", current_price, " Ticket: ", ticket);
        return success;
    }

    void OnTick(const IndCache& cache) override {
        if(state == M_ACTIVE) {
            if(PositionsTotal() == 0) {
                state = M_DONE;
                return;
            }

            // Tight time stop for news trades
            if(TimeCurrent() - meta.open_time > 300) { // 5 minutes
                for(int i = 0; i < PositionsTotal(); i++) {
                    if(PositionSelectByTicket(PositionGetTicket(i))) {
                        if(PositionGetInteger(POSITION_MAGIC) == Inp_Magic) {
                            ulong ticket = PositionGetTicket(i);
                            StoreExitReason(ticket, "TIME_STOP");
                            g_exec_manager.PositionClose(ticket);
                        }
                    }
                }
            }
        }
    }

    void OnExit(bool profit) override {
        stats.trades++;
        if(profit) stats.wins++;
        state = M_DONE;
        if(Inp_LogVerbose) Print("News Fade Exit: ", profit ? "Profit" : "Loss");
    }
};

//--- Experimental DogWalk Module (simplified implementation)
class DogWalkModule : public ModuleBase {
private:
    double last_high, last_low;
    int sideways_bars;

public:
    StrategyId GetId() override { return S_DOGWALK; }

    bool Eligible(const IndCache& cache, SessionId session) override {
        if(!Enable_Experimental_DogWalk) return false;
        if(!cache.Warmed) return false;
        if(state != M_IDLE) return false;

        // Look for sideways movement (low ADX) followed by small breakout
        if(cache.ADX < 15) {
            sideways_bars++;
            if(sideways_bars > 10) {
                double current_high = iHigh(_Symbol, PERIOD_M5, 0);
                double current_low = iLow(_Symbol, PERIOD_M5, 0);

                // Check for small breakout after consolidation
                if(current_high > last_high || current_low < last_low) {
                    return true;
                }
            }
        } else {
            sideways_bars = 0;
        }

        last_high = iHigh(_Symbol, PERIOD_M5, 0);
        last_low = iLow(_Symbol, PERIOD_M5, 0);

        return false;
    }

    bool Arm(const IndCache& cache, SessionId session) override {
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl_pts = cache.ATR * 0.6 / _Point;
        double lots = CalcLotsByRisk(sl_pts, Inp_RiskPerTradePct * 0.5); // Reduced risk for experimental

        // Create strategy comment
        string strategy_comment = GetStrategyComment(S_DOGWALK);

        // Simple momentum trade
        bool success = false;
        ulong ticket = 0;

        if(current_price > last_high) {
            double sl_price = current_price - sl_pts * _Point;
            double tp_price = current_price + sl_pts * _Point;

            if(g_exec_manager.Buy(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_DOGWALK, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        } else if(current_price < last_low) {
            double sl_price = current_price + sl_pts * _Point;
            double tp_price = current_price - sl_pts * _Point;

            if(g_exec_manager.Sell(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_DOGWALK, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }

        if(success) g_telemetry.LogVerbose("DogWalk", "Armed at price " + DoubleToString(current_price, _Digits) + " Ticket: " + IntegerToString(ticket));
        return success;
    }

    void OnTick(const IndCache& cache) override {
        if(state == M_ACTIVE) {
            if(PositionsTotal() == 0) {
                state = M_DONE;
                return;
            }

            // Time stop after 15 minutes
            if(TimeCurrent() - meta.open_time > 15 * 60) {
                for(int i = 0; i < PositionsTotal(); i++) {
                    if(PositionSelectByTicket(PositionGetTicket(i))) {
                        if(PositionGetInteger(POSITION_MAGIC) == Inp_Magic) {
                            ulong ticket = PositionGetTicket(i);
                            StoreExitReason(ticket, "TIME_STOP");
                            g_exec_manager.PositionClose(ticket);
                        }
                    }
                }
            }
        }
    }

    void OnExit(bool profit) override {
        stats.trades++;
        if(profit) stats.wins++;
        state = M_DONE;
        sideways_bars = 0;
        g_telemetry.LogVerbose("DogWalk", "Exit: " + (profit ? "Profit" : "Loss"));
    }
};

//--- Experimental AsianEarly Module (simplified implementation)
class AsianEarlyModule : public ModuleBase {
public:
    StrategyId GetId() override { return S_ASIANEARLY; }

    bool Eligible(const IndCache& cache, SessionId session) override {
        if(!Enable_Experimental_AsianEarly) return false;
        if(!cache.Warmed) return false;
        if(state != M_IDLE) return false;
        if(session != SES_TOKYO) return false;

        // Early Asian session scalping - look for small ranges
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);

        // Only first 2 hours of Asian session
        if(dt.hour >= 2) return false;

        // Look for tight range and small breakout
        double range_5m = iHigh(_Symbol, PERIOD_M5, 0) - iLow(_Symbol, PERIOD_M5, 0);
        if(Pts(range_5m) < cache.ATR / _Point * 0.3) {
            return true;
        }

        return false;
    }

    bool Arm(const IndCache& cache, SessionId session) override {
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl_pts = cache.ATR * 0.4 / _Point;
        double lots = CalcLotsByRisk(sl_pts, Inp_RiskPerTradePct * 0.3); // Very reduced risk

        // Create strategy comment
        string strategy_comment = GetStrategyComment(S_ASIANEARLY);

        // Scalp based on bias
        bool success = false;
        ulong ticket = 0;

        if(cache.bias == B_LONG) {
            double sl_price = current_price - sl_pts * _Point;
            double tp_price = current_price + sl_pts * 0.5 * _Point;

            if(g_exec_manager.Buy(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_ASIANEARLY, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        } else if(cache.bias == B_SHORT) {
            double sl_price = current_price + sl_pts * _Point;
            double tp_price = current_price - sl_pts * 0.5 * _Point;

            if(g_exec_manager.Sell(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_ASIANEARLY, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }

        if(success) g_telemetry.LogVerbose("AsianEarly", "Armed for early Asian scalp, Ticket: " + IntegerToString(ticket));
        return success;
    }

    void OnTick(const IndCache& cache) override {
        if(state == M_ACTIVE && PositionsTotal() == 0) {
            state = M_DONE;
        }
    }

    void OnExit(bool profit) override {
        stats.trades++;
        if(profit) stats.wins++;
        state = M_DONE;
        g_telemetry.LogVerbose("AsianEarly", "Exit: " + (profit ? "Profit" : "Loss"));
    }
};

//--- Experimental VolumeOsc Module (simplified implementation)
class VolumeOscModule : public ModuleBase {
private:
    double volume_ma;

public:
    StrategyId GetId() override { return S_VOLOSC; }

    bool Eligible(const IndCache& cache, SessionId session) override {
        if(!Enable_Experimental_VolOsc) return false;
        if(!cache.Warmed) return false;
        if(state != M_IDLE) return false;

        // Calculate simple volume moving average
        double vol_sum = 0;
        for(int i = 0; i < 10; i++) {
            vol_sum += (double)iVolume(_Symbol, PERIOD_M5, i);
        }
        volume_ma = vol_sum / 10.0;

        // Look for volume spike with price divergence
        double current_vol = (double)iVolume(_Symbol, PERIOD_M5, 0);
        if(current_vol > volume_ma * 1.5) {
            // Volume spike detected
            return true;
        }

        return false;
    }

    bool Arm(const IndCache& cache, SessionId session) override {
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl_pts = cache.ATR * 0.5 / _Point;
        double lots = CalcLotsByRisk(sl_pts, Inp_RiskPerTradePct * 0.4); // Reduced risk

        // Create strategy comment
        string strategy_comment = GetStrategyComment(S_VOLOSC);

        // Trade in direction of volume spike
        double price_change = iClose(_Symbol, PERIOD_M5, 0) - iClose(_Symbol, PERIOD_M5, 1);

        bool success = false;
        ulong ticket = 0;

        if(price_change > 0) {
            double sl_price = current_price - sl_pts * _Point;
            double tp_price = current_price + sl_pts * _Point;

            if(g_exec_manager.Buy(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_VOLOSC, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        } else {
            double sl_price = current_price + sl_pts * _Point;
            double tp_price = current_price - sl_pts * _Point;

            if(g_exec_manager.Sell(lots, _Symbol, 0, sl_price, tp_price, strategy_comment)) {
                ticket = g_exec_manager.ResultOrder();

                // Create and store trade meta
                TradeMeta trade_meta = CreateTradeMeta(S_VOLOSC, cache, session, lots, current_price, sl_price, tp_price);
                StoreTradeMeta(ticket, trade_meta);

                meta.ticket = ticket;
                meta.open_time = TimeCurrent();
                state = M_ACTIVE;
                success = true;
            }
        }

        if(success) g_telemetry.LogVerbose("VolumeOsc", "Armed on volume spike, Ticket: " + IntegerToString(ticket));
        return success;
    }

    void OnTick(const IndCache& cache) override {
        if(state == M_ACTIVE && PositionsTotal() == 0) {
            state = M_DONE;
        }
    }

    void OnExit(bool profit) override {
        stats.trades++;
        if(profit) stats.wins++;
        state = M_DONE;
        g_telemetry.LogVerbose("VolumeOsc", "Exit: " + (profit ? "Profit" : "Loss"));
    }
};

//--- Global module instances
ORBModule* g_orb_module;
VWAPFadeModule* g_vwap_fade_module;
VWAPTrendModule* g_vwap_trend_module;
KeltnerModule* g_keltner_module;
LiquiditySweepModule* g_sweep_module;
AsianRangeModule* g_asia_module;
NewsFadeModule* g_news_module;
DogWalkModule* g_dogwalk_module;
AsianEarlyModule* g_asianearly_module;
VolumeOscModule* g_volosc_module;
ModuleBase* g_modules[];

//--- Scheduler class
class Scheduler {
public:
    static StrategyId SelectModule() {
        if(!CanTrade()) return S_NONE;

        SessionId current_session = GetCurrentSession();

        // Create array of eligible modules sorted by priority
        ModuleBase* eligible_modules[];
        int priorities[];

        for(int i=0; i<ArraySize(g_modules); ++i) {
            ModuleBase* m = g_modules[i];
            if(m == NULL) continue;

            if(m.Eligible(g_cache, current_session)) {
                int pr = GetStrategyPriority(m.GetId());
                int size = ArraySize(eligible_modules);
                ArrayResize(eligible_modules, size + 1);
                ArrayResize(priorities, size + 1);
                eligible_modules[size] = m;
                priorities[size] = pr;
            }
        }

        // Sort by priority (highest first)
        for(int i = 0; i < ArraySize(eligible_modules) - 1; i++) {
            for(int j = i + 1; j < ArraySize(eligible_modules); j++) {
                if(priorities[j] > priorities[i]) {
                    // Swap modules
                    ModuleBase* temp_mod = eligible_modules[i];
                    eligible_modules[i] = eligible_modules[j];
                    eligible_modules[j] = temp_mod;
                    // Swap priorities
                    int temp_pri = priorities[i];
                    priorities[i] = priorities[j];
                    priorities[j] = temp_pri;
                }
            }
        }

        // Try to arm modules in priority order
        for(int i = 0; i < ArraySize(eligible_modules); i++) {
            ModuleBase* candidate = eligible_modules[i];

            // Disarm other M_ARMED modules
            for(int j=0; j<ArraySize(g_modules); ++j) {
                ModuleBase* m = g_modules[j];
                if(m != NULL && m != candidate && m.GetState() == M_ARMED) {
                    m.SetState(M_IDLE);
                }
            }

            // Try to arm this candidate
            if(candidate.Arm(g_cache, current_session)) {
                return candidate.GetId();
            } else {
                g_telemetry.IncrementReject("ArmFailed");
            }
        }

        return S_NONE;
    }
};



//--- EA Event Handlers
int OnInit() {
    // Validate symbol
    if(!SymbolSelect(_Symbol, true)) {
        Print("ERROR: Failed to select symbol ", _Symbol);
        return INIT_FAILED;
    }

    // Check symbol properties
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);

    if(digits == 0 || tick_size == 0 || tick_value == 0 || contract_size == 0) {
        Print("ERROR: Invalid symbol properties for ", _Symbol);
        return INIT_FAILED;
    }

    Print("Symbol validation: ", _Symbol, " Digits:", digits, " TickSize:", tick_size, " TickValue:", tick_value);

    // Initialize services
    g_cache.Init(_Symbol);
    g_telemetry.InitCSV();

    // Initialize slippage ring buffer
    ArrayResize(g_slippage_ring, Inp_SlipRingSize);
    ArrayInitialize(g_slippage_ring, 0);

    // Initialize trade meta lookup system
    InitTradeMetaSystem();

    // Initialize dynamic arrays with proper sizing
    ArrayResize(g_exit_reasons, MAX_EXIT_REASONS);
    ArrayResize(g_trailing_stops, MAX_TRAILING_STOPS);

    // Initialize global strategy statistics
    InitStrategyStats();

    // Initialize all modules
    g_orb_module = new ORBModule();
    g_vwap_fade_module = new VWAPFadeModule();
    g_vwap_trend_module = new VWAPTrendModule();
    g_keltner_module = new KeltnerModule();
    g_sweep_module = new LiquiditySweepModule();
    g_asia_module = new AsianRangeModule();
    g_news_module = new NewsFadeModule();
    g_dogwalk_module = new DogWalkModule();
    g_asianearly_module = new AsianEarlyModule();
    g_volosc_module = new VolumeOscModule();

    ArrayResize(g_modules, 10);
    g_modules[0] = g_sweep_module;      // Highest priority
    g_modules[1] = g_orb_module;
    g_modules[2] = g_vwap_trend_module;
    g_modules[3] = g_keltner_module;
    g_modules[4] = g_vwap_fade_module;
    g_modules[5] = g_asia_module;
    g_modules[6] = g_news_module;
    g_modules[7] = g_dogwalk_module;    // Experimental modules
    g_modules[8] = g_asianearly_module;
    g_modules[9] = g_volosc_module;     // Lowest priority

    // Reset global state
    g_active = S_NONE;
    g_last_exit_time = 0;

    // Initialize daily reset system
    g_risk_manager.DoDailyReset();

    // Wait for indicators to warm up
    Print("Waiting for indicators to warm up...");
    int warmup_attempts = 0;
    while(!g_cache.Update() && warmup_attempts < 100) {
        Sleep(100);
        warmup_attempts++;
    }

    if(!g_cache.Warmed) {
        Print("WARNING: Indicators not fully warmed up after initialization");
    }

    Print("XAUUSD Multi-Strategy EA initialized successfully with ", ArraySize(g_modules), " modules");
    return INIT_SUCCEEDED;
}

void OnTick() {
    // Periodic session/DST sanity logging
    static datetime last_session_log = 0;
    static SessionId last_logged_session = SES_OFF;
    SessionId current_session = GetCurrentSession();

    // Log at session changes or every hour
    if(current_session != last_logged_session || TimeCurrent() - last_session_log > 3600) {
        g_session_calendar.LogSessionSanity();
        last_session_log = TimeCurrent();
        last_logged_session = current_session;
    }

    // Update indicator cache
    if(!g_cache.Update()) {
        if(Inp_LogVerbose) Print("Failed to update indicator cache");
        return;
    }

    // Check for daily reset (must be called on every tick)
    g_risk_manager.UpdateLimits();

    // Periodic cleanup of tracking systems (every 10 minutes)
    static datetime last_cleanup = 0;
    if(TimeCurrent() - last_cleanup > 600) {
        CleanupOldExitReasons();
        CleanupTrailingStops();
        last_cleanup = TimeCurrent();
    }

    // If no active strategy, try to select one
    if(g_active == S_NONE) {
        g_active = Scheduler::SelectModule();
        if(g_active != S_NONE) {
            // Enhanced logging for first entry per module/day as per README
            static StrategyId last_logged_strategies[];
            static datetime last_log_day = 0;

            MqlDateTime dt;
            TimeToStruct(TimeCurrent(), dt);
            datetime current_day = TimeCurrent() - dt.hour * 3600 - dt.min * 60 - dt.sec;

            if(current_day != last_log_day) {
                ArrayResize(last_logged_strategies, 0);
                last_log_day = current_day;
            }

            bool already_logged = false;
            for(int i = 0; i < ArraySize(last_logged_strategies); i++) {
                if(last_logged_strategies[i] == g_active) {
                    already_logged = true;
                    break;
                }
            }

            if(!already_logged) {
                int size = ArraySize(last_logged_strategies);
                ArrayResize(last_logged_strategies, size + 1);
                last_logged_strategies[size] = g_active;

                // Print detailed entry diagnostics
                double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
                double vwap_dev = 0;
                if(g_cache.VWAP_sd > 0) {
                    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    vwap_dev = (current_price - g_cache.VWAP_sess) / g_cache.VWAP_sd;
                }

                Print("=== FIRST ENTRY TODAY ===");
                Print("Strategy: ", EnumToString(g_active));
                Print("Session: ", EnumToString(GetCurrentSession()));
                Print("ATR: ", DoubleToString(g_cache.ATR, _Digits));
                Print("ADX: ", DoubleToString(g_cache.ADX, 1));
                Print("VWAP Dev: ", DoubleToString(vwap_dev, 2), " SD");
                Print("Spread: ", DoubleToString(spread, 1), " pts");
                Print("Regime: ", EnumToString(g_cache.regime));
                Print("Bias: ", EnumToString(g_cache.bias));
            } else if(Inp_LogVerbose) {
                Print("Strategy activated: ", EnumToString(g_active));
            }
        }
    }

    // Update active module
    if(g_active != S_NONE) {
        for(int i=0; i<ArraySize(g_modules); ++i) {
            ModuleBase* m = g_modules[i];
            if(m != NULL && m.GetId() == g_active) {
                // Failsafe: If module is in M_IDLE (arm failed), reset g_active
                if(m.GetState() == M_IDLE) {
                    g_active = S_NONE;
                    if(Inp_LogVerbose) Print("FAILSAFE: Module ", EnumToString(m.GetId()), " in M_IDLE, resetting g_active");
                    break;
                }

                m.OnTick(g_cache);

                if(m.GetState() == M_DONE) {
                    m.SetState(M_IDLE);
                    g_active = S_NONE;
                    if(Inp_LogVerbose) Print("Strategy completed: ", EnumToString(m.GetId()));
                }
                break;
            }
        }
    }
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult&  result)
{
    // Track position modifications for trailing stop detection
    if(trans.type == TRADE_TRANSACTION_REQUEST && request.action == TRADE_ACTION_SLTP) {
        if(request.magic == Inp_Magic) {
            TrackPositionModification(request.position, request.sl);
        }
    }

    if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
    if(!HistoryDealSelect(trans.deal)) return;

    long deal_magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
    if(deal_magic != Inp_Magic) return;

    // Korrekt klassifikation: kun registrér udfald ved exit
    int entry_type = (int)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
    if(entry_type != DEAL_ENTRY_OUT && entry_type != DEAL_ENTRY_INOUT) {
        // Åbnende deal – log slippage, men ingen OnExit/udfald
        if(request.action == TRADE_ACTION_DEAL) {
            double slippage_pts = 0;
            if(request.type == ORDER_TYPE_BUY)
                slippage_pts = Pts(result.price - request.price);
            else if(request.type == ORDER_TYPE_SELL)
                slippage_pts = Pts(request.price - result.price);

            // Ensure slippage ring is properly sized and bounds checked
            if(ArraySize(g_slippage_ring) < Inp_SlipRingSize) {
                ArrayResize(g_slippage_ring, Inp_SlipRingSize);
            }
            if(g_slip_index < ArraySize(g_slippage_ring)) {
                g_slippage_ring[g_slip_index] = slippage_pts;
            }
            g_slip_index = (g_slip_index + 1) % Inp_SlipRingSize;
            g_spread_guard.RecordSlippage(MathAbs(slippage_pts));
        }
        return;
    }

    // Exit-deal: registrér udfald og frigiv strategi
    double deal_profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
    double exit_price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
    double deal_volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
    datetime exit_time = TimeCurrent();
    ulong position_ticket = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);

    // Check if this is a partial close
    bool is_partial_close = IsPartialClose(position_ticket, deal_volume);

    g_risk_manager.RegisterOutcome(deal_profit);
    g_last_exit_time = exit_time;

    bool is_profit = (deal_profit > 0);
    StrategyId closing_sid = g_active; // Declare closing_sid at function scope

    // Write comprehensive telemetry using trade meta lookup
    if(Inp_WriteCSV) {
        TradeMeta trade_meta;
        bool meta_found = GetTradeMeta(position_ticket, trade_meta);

        if(meta_found) {
            // Enhanced exit reason determination
            string exit_reason = GetStoredExitReason(position_ticket);

            if(exit_reason == "") {
                // No stored exit reason, determine from price analysis
                if(MathAbs(exit_price - trade_meta.planned_sl) < _Point * 2) {
                    exit_reason = "STOP_LOSS";
                } else if(MathAbs(exit_price - trade_meta.planned_tp) < _Point * 2) {
                    exit_reason = "TAKE_PROFIT";
                } else if(IsTrailingStopExit(position_ticket, exit_price)) {
                    exit_reason = "TSL";
                } else if(g_risk_manager.IsLockedDay() || g_risk_manager.IsLockedWeek()) {
                    exit_reason = "DAILY_LOCK";
                } else if(!is_profit) {
                    exit_reason = "MANUAL_LOSS";
                } else {
                    exit_reason = "MANUAL_PROFIT";
                }
            }

            // Handle partial close vs full close
            if(is_partial_close) {
                // Create partial close meta with closed volume
                static int partial_counter = 1;
                TradeMeta partial_meta = CreatePartialCloseMeta(trade_meta, deal_volume, partial_counter++);

                // Add "PARTIAL" prefix to exit reason
                exit_reason = "PARTIAL_" + exit_reason;

                // Write partial close data
                g_telemetry.WriteTrade(partial_meta, exit_price, deal_profit, exit_time, exit_reason);

                // Update remaining lots in the original meta
                UpdateRemainingLots(position_ticket, deal_volume);

                if(Inp_LogVerbose) {
                    Print("Partial close recorded: Ticket ", position_ticket,
                          " | Closed: ", DoubleToString(deal_volume, 2),
                          " | Remaining: ", DoubleToString(trade_meta.remaining_lots - deal_volume, 2));
                }
            } else {
                // Full close - write final trade data
                g_telemetry.WriteTrade(trade_meta, exit_price, deal_profit, exit_time, exit_reason);

                // Remove from meta lookup to free memory
                RemoveTradeMeta(position_ticket);
            }

            // Calculate metrics for strategy statistics (always update for any close)
            double risk_pts = MathAbs(trade_meta.entry_price - trade_meta.planned_sl) / _Point;
            double reward_pts = MathAbs(exit_price - trade_meta.entry_price) / _Point;
            double rr_ratio = (risk_pts > 0) ? reward_pts / risk_pts : 0;
            double holding_time_sec = (double)(exit_time - trade_meta.entry_time);

            // Update global strategy statistics
            UpdateStrategyStats(trade_meta.sid, deal_profit, rr_ratio, holding_time_sec);

            if(Inp_LogVerbose) {
                Print("Trade CSV written: ", trade_meta.strategy_short, " | Ticket: ", position_ticket,
                      " | PnL: ", DoubleToString(deal_profit, 2), " | Reason: ", exit_reason);
            }
        } else {
            // Fallback for trades without meta (shouldn't happen in normal operation)
            closing_sid = g_active; // Use already declared variable
            string strategy_name = EnumToString(closing_sid);
            string direction = (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_BUY) ? "SELL" : "BUY"; // Exit direction is opposite
            ulong order_id = HistoryDealGetInteger(trans.deal, DEAL_ORDER);

            g_telemetry.WriteTrade(strategy_name, direction, exit_price, 0, 0, exit_price, deal_profit, order_id, exit_time - 300);

            // Update strategy statistics with fallback values (no RR ratio or holding time available)
            UpdateStrategyStats(closing_sid, deal_profit, 0.0, 300.0); // Assume 5 min holding time

            if(Inp_LogVerbose) {
                Print("WARNING: Trade meta not found for ticket ", position_ticket, " - using fallback CSV write");
            }
        }
    }

    // Notificér aktivt modul og sæt state → M_DONE (only on full close)
    if(closing_sid != S_NONE && !is_partial_close) {
        for(int i=0; i<ArraySize(g_modules); ++i) {
            ModuleBase* m = g_modules[i];
            if(m != NULL && m.GetId() == closing_sid) {
                m.OnExit(is_profit);
                break;
            }
        }

        // CRITICAL: frigiv EA til nye handler (only on full close)
        g_active = S_NONE;
    }

    if(Inp_LogVerbose) {
        Print("Trade closed: ", is_profit ? "PROFIT" : "LOSS",
              " Amount: ", DoubleToString(deal_profit,2),
              " Consecutive losses: ", g_risk_manager.GetConsecLosses());
    }
}

void OnDeinit(const int reason) {
    // Print session/risk summary først
    Print("=== EA DEINITIALIZATION SUMMARY ===");
    Print("Day loss: ", DoubleToString(g_risk_manager.GetDayLoss(), 2),
          " | Week loss: ", DoubleToString(g_risk_manager.GetWeekLoss(), 2));
    Print("Consecutive losses: ", g_risk_manager.GetConsecLosses());
    RiskLimits limits = g_risk_manager.GetLimits();
    Print("Risk locks - Day: ", limits.locked_day ? "YES" : "NO",
          " | Week: ", limits.locked_week ? "YES" : "NO");

    // Print strategy statistics summary
    PrintStrategyStatsSummary();

    // Write strategy summary to CSV before cleanup
    if(Inp_WriteCSV) {
        g_telemetry.WriteStrategySummary();
    }

    // Print modulstatistik FØR delete og med -> på pointere
    for(int i=0; i<ArraySize(g_modules); ++i) {
        ModuleBase* m = g_modules[i];
        if(m != NULL) {
            Print("Module ", EnumToString(m.GetId()),
                  " - State: ", EnumToString(m.GetState()));
        }
    }

    // Slet ALLE moduler via g_modules[] og nulstil entries
    for(int i=0; i<ArraySize(g_modules); ++i) {
        if(g_modules[i] != NULL) { delete g_modules[i]; g_modules[i] = NULL; }
    }

    // Nulstil også de navngivne pointere (forsigtighed)
    g_orb_module = NULL; g_vwap_fade_module = NULL; g_vwap_trend_module = NULL;
    g_keltner_module = NULL; g_sweep_module = NULL; g_asia_module = NULL;
    g_news_module = NULL; g_dogwalk_module = NULL; g_asianearly_module = NULL; g_volosc_module = NULL;

    // Luk CSV til sidst
    g_telemetry.CloseCSV();
    Print("XAUUSD Multi-Strategy EA deinitialized (Reason: ", reason, ")");
}

//--- Tester functions (optional)
double OnTester() {
    double profit_factor = 0;
    double total_trades = 0;

    // Calculate basic performance metrics
    if(TesterStatistics(STAT_TRADES) > 0) {
        total_trades = TesterStatistics(STAT_TRADES);
        double gross_profit = TesterStatistics(STAT_GROSS_PROFIT);
        double gross_loss = TesterStatistics(STAT_GROSS_LOSS);

        if(gross_loss > 0) {
            profit_factor = gross_profit / gross_loss;
        }
    }

    // Return custom metric (profit factor weighted by trade count)
    return profit_factor * MathMin(total_trades / 100.0, 1.0);
}


