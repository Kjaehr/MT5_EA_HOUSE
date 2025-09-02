//+------------------------------------------------------------------+
//|                             ORB_FVG_Enhanced_M5.mq5              |
//|     NY ORB + FVG (5m) med R/R, ATR filter, sessions, MM m.m.     |
//+------------------------------------------------------------------+
#property strict
#property version   "1.20"
#property description "NY ORB (9:30–9:45, server-tid konfigurerbar) + FVG entry på 3. bar. R/R, ATR-filter, sessions og money management."

#include <Trade/Trade.mqh>

//=============================== INPUTS ===============================

// Generelt
input string Inp_EA_Tag              = "ORB_FVG_M5";
input long   Inp_Magic               = 55330011;
input bool   Inp_VerboseLog          = true;

// Udførsel / Spread
input int    Inp_MaxSpreadPoints     = 200;   // Hårdt loft på spread (points)
input bool   Inp_UseSpreadEMAFilter  = true;  // Ekstra filter: undgå entries når spread >> gennemsnit
input int    Inp_SpreadEMAPeriod     = 200;   // EMA på ticks
input double Inp_SpreadEMAMaxMult    = 1.7;   // Tillad aktuelt spread op til X * EMA

// ORB vindue (server-tid)
input int    Inp_ORB_StartHour       = 9;     // typisk 9:30
input int    Inp_ORB_StartMinute     = 30;
input int    Inp_ORB_DurationMin     = 15;    // typisk 15
input double Inp_MinORBRangePoints   = 20.0;  // Minimum ORB range in points
input double Inp_MaxORBRangePoints   = 500.0; // Maximum ORB range in points

// Sessions (server-tid) – finjusteret til 12–16 og 22–23 som default
input bool   Inp_EnableSessions      = true;
input int    Inp_S1_StartHour        = 12;
input int    Inp_S1_StartMinute      = 0;
input int    Inp_S1_EndHour          = 16;
input int    Inp_S1_EndMinute        = 0;
input int    Inp_S2_StartHour        = 22;
input int    Inp_S2_StartMinute      = 0;
input int    Inp_S2_EndHour          = 23;
input int    Inp_S2_EndMinute        = 0;

// Volatilitetsfilter (ATR på M5)
input bool   Inp_EnableATRVolFilter  = true;
input int    Inp_ATR_Filter_Period   = 14;    // ATR(14) på M5
input double Inp_ATR_MinPoints       = 50.0;  // kun lav-vol stop
input bool   Inp_ATR_IgnoreHigh      = true;  // ignorér for høj ATR (tillad høj vol)


// FVG-strenghed
input double Inp_MinFVGPoints        = 3.0;   // Minimum FVG-gap (points)
input double Inp_MinBreakoutBodyPct  = 0.50;  // Breakout bar body >= X af hele bar-range (0..1)

// Market Structure Filter
input bool   Inp_UseMarketStructure  = true;  // Enable market structure filter
input int    Inp_StructureLookback   = 20;    // Bars to look back for structure

// Volume Filter
input bool   Inp_UseVolumeFilter     = true;  // Enable volume filter
input double Inp_MinVolumeMultiplier = 1.5;   // Minimum volume vs average
input int    Inp_VolumeAvgPeriod     = 20;    // Period for volume average

// Trend Filter (H1)
input bool   Inp_UseTrendFilter      = true;  // Enable H1 trend filter
input int    Inp_TrendMAPeriod       = 50;    // MA period for trend
input int    Inp_TrendLookback       = 5;     // Bars to confirm trend

// Entry-mode
input bool   Inp_EnterAtCandleClose  = true;  // Entry ved 3. bars close (market på næste bar)
input double Inp_BufferPoints        = 0.0;   // Alternativ: 1 tick/buffer fra 3. bar

// Multi-breakout styring
enum TRADE_LIMIT_MODE { FIRST_ONLY=0, ONE_EACH_DIR=1, UNLIMITED=2 };
input TRADE_LIMIT_MODE Inp_TradeLimitMode = FIRST_ONLY;
input int    Inp_MaxTradesPerDay     = 10;    // Sikkerhedsloft (udover ovenstående)

// Money Management
input bool   Inp_UseFixedLots        = false; // false => brug procent-risiko
input double Inp_FixedLots           = 0.10;
input double Inp_RiskPercent         = 1.0;   // fx 1% pr. trade
input double Inp_MaxDailyLoss        = 5.0;   // Max daily loss %
input double Inp_MaxDailyProfit      = 10.0;  // Stop trading at daily profit %
input bool   Inp_UseEquityRisk       = true;  // Use equity instead of balance for risk calc

// SL-Mode
enum SL_MODE { SL_BREAKOUT_EXTREME=0, SL_BREAKOUT_MINUS_ATR=1, SL_BREAKOUT_MINUS_BUFFER=2 };
input SL_MODE Inp_SL_Mode            = SL_BREAKOUT_MINUS_ATR;
input int    Inp_SL_ATR_Period       = 1;     // ATR(1) som foreslået
input double Inp_SL_ATR_Mult         = 1.0;   // fx 1.0 * ATR
input double Inp_SL_BufferPoints     = 20.0;  // alternativ buffer i points

// TP-Mode (hæv RR en smule)
enum TP_MODE { TP_RR_MULTIPLE=0, TP_ATR_MULTIPLE=1 };
input TP_MODE Inp_TP_Mode            = TP_RR_MULTIPLE;
input double  Inp_RR_Multiple        = 2.00;  // 2R for bedre PF
input int     Inp_TP_ATR_Period      = 14;    // ATR period for TP calculation
input double  Inp_TP_ATR_Mult        = 2.0;   // ATR multiplier for TP

// Trailing Stop
input bool    Inp_UseTrailingStop    = true;  // Enable trailing stop
input double  Inp_TrailingStartRR    = 1.0;   // Start trailing at 1R profit
input double  Inp_TrailingStepRR     = 0.5;   // Trail by 0.5R steps
input double  Inp_TrailingStopRR     = 0.5;   // Keep 0.5R profit minimum

// Partial Profit Taking
input bool    Inp_UsePartialTP       = true;  // Enable partial profit taking
input double  Inp_PartialTP1_RR      = 1.0;   // First partial TP at 1R
input double  Inp_PartialTP1_Percent = 50.0;  // Close 50% at first TP
input double  Inp_PartialTP2_RR      = 1.5;   // Second partial TP at 1.5R
input double  Inp_PartialTP2_Percent = 30.0;  // Close 30% at second TP

// Andre
input bool    Inp_OnePositionAtATime = true;
input int     Inp_MaxSlippagePoints  = 50;

//=============================== GLOBALS ===============================
CTrade       trade;

datetime     g_lastBarTime = 0;

datetime     g_orbStart = 0;
datetime     g_orbEnd   = 0;
double       g_orbHigh  = 0.0;
double       g_orbLow   = 0.0;
bool         g_orbReady = false;

int          g_dayOfYear = -1;
int          g_tradesToday = 0;
bool         g_tradedLongToday  = false;
bool         g_tradedShortToday = false;

datetime     g_lastSignalTimeLong = 0;
datetime     g_lastSignalTimeShort = 0;

// ATR handles
int          g_hATR_Filter = INVALID_HANDLE;
int          g_hATR_SL     = INVALID_HANDLE;
int          g_hATR_TP     = INVALID_HANDLE;

// MA handle for trend filter
int          g_hMA_Trend   = INVALID_HANDLE;

// Spread EMA
bool         g_spreadEMAInit = false;
double       g_spreadEMA = 0.0;

// Daily P&L tracking
double       g_dailyStartBalance = 0.0;
double       g_dailyProfit = 0.0;
bool         g_dailyLimitReached = false;

//=============================== UTILS ================================
int  DigitsForSymbol() { return (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS); }
double Norm(double price){ return NormalizeDouble(price, DigitsForSymbol()); }

bool GetBidAsk(double &bid, double &ask)
{
   if(!SymbolInfoDouble(_Symbol, SYMBOL_BID, bid)) return false;
   if(!SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask)) return false;
   return true;
}

double CurrentSpreadPoints()
{
   double bid, ask;
   if(!GetBidAsk(bid,ask)) return 1e9;
   return (ask - bid)/_Point;
}

bool SpreadOK()
{
   double spr = CurrentSpreadPoints();
   if(spr > Inp_MaxSpreadPoints) return false;

   if(Inp_UseSpreadEMAFilter && g_spreadEMAInit)
   {
      if(spr > Inp_SpreadEMAMaxMult * g_spreadEMA) return false;
   }
   return true;
}

void UpdateSpreadEMA()
{
   double spr = CurrentSpreadPoints();
   if(!g_spreadEMAInit)
   {
      g_spreadEMA = spr;
      g_spreadEMAInit = true;
      return;
   }
   double k = 2.0/(Inp_SpreadEMAPeriod+1.0);
   g_spreadEMA = k*spr + (1.0-k)*g_spreadEMA;
}

void ResetDayCounters()
{
   g_tradesToday = 0;
   g_tradedLongToday  = false;
   g_tradedShortToday = false;
   g_lastSignalTimeLong = 0;
   g_lastSignalTimeShort = 0;
   g_orbReady = false;
   g_orbHigh = 0.0;
   g_orbLow  = 0.0;
   g_orbStart = 0;
   g_orbEnd   = 0;

   // Reset daily P&L tracking
   g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyProfit = 0.0;
   g_dailyLimitReached = false;
}

void BuildORBWindow(datetime refTime)
{
   MqlDateTime dt;
   TimeToStruct(refTime, dt);
   dt.hour = Inp_ORB_StartHour;
   dt.min  = Inp_ORB_StartMinute;
   dt.sec  = 0;
   g_orbStart = StructToTime(dt);
   g_orbEnd   = g_orbStart + (Inp_ORB_DurationMin * 60) - 1;
}

bool ComputeORBRange()
{
   MqlRates rr[];
   int copied = CopyRates(_Symbol, PERIOD_M5, g_orbStart, g_orbEnd, rr);
   if(copied <= 0) return false;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int i=0; i<copied; ++i)
   {
      if(rr[i].high > hi) hi = rr[i].high;
      if(rr[i].low  < lo) lo = rr[i].low;
   }
   if(hi == -DBL_MAX || lo == DBL_MAX) return false;

   // Validate ORB range
   double orbRangePoints = (hi - lo) / _Point;
   if(orbRangePoints < Inp_MinORBRangePoints || orbRangePoints > Inp_MaxORBRangePoints)
   {
      if(Inp_VerboseLog)
         PrintFormat("[%s] ORB range invalid: %.1f points (min=%.1f, max=%.1f)",
                     Inp_EA_Tag, orbRangePoints, Inp_MinORBRangePoints, Inp_MaxORBRangePoints);
      return false;
   }

   g_orbHigh = hi;
   g_orbLow  = lo;
   g_orbReady = true;

   if(Inp_VerboseLog)
      PrintFormat("[%s] ORB ready: High=%.5f Low=%.5f Range=%.1f points (bars=%d)",
                  Inp_EA_Tag, g_orbHigh, g_orbLow, orbRangePoints, copied);

   return true;
}

bool CopyRecentRates(MqlRates &b1, MqlRates &b2, MqlRates &b3)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, 5, rates);
   if(copied < 4) return false;
   b1 = rates[1];   // seneste lukkede
   b2 = rates[2];
   b3 = rates[3];
   return true;
}

// --- ATR helpers (returns ATR in points) ---
double GetATRPointsFromHandle(int handle, int shift)
{
   if(handle==INVALID_HANDLE) return -1.0;
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) <= 0) return -1.0;
   return buf[0] / _Point;
}

// --- Sessions ---
int MinutesSinceMidnight(datetime t)
{
   MqlDateTime dt; TimeToStruct(t, dt);
   return dt.hour*60 + dt.min;
}

bool TimeInWindow(int tMin, int sHour, int sMin, int eHour, int eMin)
{
   int s = sHour*60 + sMin;
   int e = eHour*60 + eMin;
   if(s == e) return true;
   if(s < e)  return (tMin >= s && tMin < e);
   return (tMin >= s || tMin < e); // overnight
}

bool IsWithinSessions(datetime t)
{
   if(!Inp_EnableSessions) return true;
   int tm = MinutesSinceMidnight(t);
   bool inS1 = TimeInWindow(tm, Inp_S1_StartHour, Inp_S1_StartMinute, Inp_S1_EndHour, Inp_S1_EndMinute);
   bool inS2 = TimeInWindow(tm, Inp_S2_StartHour, Inp_S2_StartMinute, Inp_S2_EndHour, Inp_S2_EndMinute);
   return (inS1 || inS2);
}

// --- FVG + breakout checks ---
bool IsBullishFVG(const MqlRates &b3, const MqlRates &b1) { return (b1.low  > b3.high); }
bool IsBearishFVG(const MqlRates &b3, const MqlRates &b1) { return (b1.high < b3.low ); }

bool BreakoutBodyStrong(const MqlRates &b3)
{
   double range = b3.high - b3.low;
   if(range <= 0) return false;
   double body  = MathAbs(b3.close - b3.open);
   return (body / range) >= Inp_MinBreakoutBodyPct;
}

bool IsBullBreakout(const MqlRates &b3) { return (b3.time >= g_orbEnd && b3.high > g_orbHigh); }
bool IsBearBreakout(const MqlRates &b3) { return (b3.time >= g_orbEnd && b3.low  < g_orbLow ); }

bool ThirdClosesBeyondORB_Long(const MqlRates &b1) { return (b1.close > g_orbHigh); }
bool ThirdClosesBeyondORB_Short(const MqlRates &b1){ return (b1.close < g_orbLow ); }

bool FVGStrictEnough_Bull(const MqlRates &b3, const MqlRates &b1)
{
   if(!IsBullishFVG(b3,b1)) return false;
   double gapPts = (b1.low - b3.high) / _Point;
   if(gapPts < Inp_MinFVGPoints) return false;
   return true;
}

bool FVGStrictEnough_Bear(const MqlRates &b3, const MqlRates &b1)
{
   if(!IsBearishFVG(b3,b1)) return false;
   double gapPts = (b3.low - b1.high) / _Point;
   if(gapPts < Inp_MinFVGPoints) return false;
   return true;
}

// --- Market Structure Analysis ---
bool IsMarketStructureBullish()
{
   if(!Inp_UseMarketStructure) return true;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, Inp_StructureLookback + 5, rates);
   if(copied < Inp_StructureLookback) return true; // Default to allow if insufficient data

   int higherHighs = 0;
   int lowerLows = 0;

   for(int i = 1; i < Inp_StructureLookback; i++)
   {
      if(rates[i].high > rates[i+1].high) higherHighs++;
      if(rates[i].low < rates[i+1].low) lowerLows++;
   }

   // Bullish if more higher highs than lower lows
   return higherHighs > lowerLows;
}

bool IsMarketStructureBearish()
{
   if(!Inp_UseMarketStructure) return true;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, Inp_StructureLookback + 5, rates);
   if(copied < Inp_StructureLookback) return true; // Default to allow if insufficient data

   int higherHighs = 0;
   int lowerLows = 0;

   for(int i = 1; i < Inp_StructureLookback; i++)
   {
      if(rates[i].high > rates[i+1].high) higherHighs++;
      if(rates[i].low < rates[i+1].low) lowerLows++;
   }

   // Bearish if more lower lows than higher highs
   return lowerLows > higherHighs;
}

// --- Daily P&L Management ---
void UpdateDailyPnL()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyProfit = ((currentBalance - g_dailyStartBalance) / g_dailyStartBalance) * 100.0;
}

bool CheckDailyLimits()
{
   if(g_dailyLimitReached) return false;

   UpdateDailyPnL();

   // Check daily loss limit
   if(g_dailyProfit <= -Inp_MaxDailyLoss)
   {
      g_dailyLimitReached = true;
      if(Inp_VerboseLog)
         PrintFormat("[%s] Daily loss limit reached: %.2f%% (limit: %.2f%%)",
                     Inp_EA_Tag, g_dailyProfit, -Inp_MaxDailyLoss);
      return false;
   }

   // Check daily profit limit
   if(g_dailyProfit >= Inp_MaxDailyProfit)
   {
      g_dailyLimitReached = true;
      if(Inp_VerboseLog)
         PrintFormat("[%s] Daily profit target reached: %.2f%% (target: %.2f%%)",
                     Inp_EA_Tag, g_dailyProfit, Inp_MaxDailyProfit);
      return false;
   }

   return true;
}

// --- Volume Filter ---
bool IsVolumeConfirmed(const MqlRates &breakoutBar)
{
   if(!Inp_UseVolumeFilter) return true;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, Inp_VolumeAvgPeriod + 5, rates);
   if(copied < Inp_VolumeAvgPeriod) return true; // Default to allow if insufficient data

   // Calculate average volume
   long totalVolume = 0;
   for(int i = 1; i <= Inp_VolumeAvgPeriod; i++)
   {
      totalVolume += rates[i].tick_volume;
   }
   double avgVolume = (double)totalVolume / Inp_VolumeAvgPeriod;

   // Check if breakout bar volume is above threshold
   bool volumeOK = breakoutBar.tick_volume >= (avgVolume * Inp_MinVolumeMultiplier);

   if(Inp_VerboseLog && !volumeOK)
      PrintFormat("[%s] Volume filter failed: %I64d vs avg %.0f (min: %.0f)",
                  Inp_EA_Tag, breakoutBar.tick_volume, avgVolume, avgVolume * Inp_MinVolumeMultiplier);

   return volumeOK;
}

// --- Trend Filter (H1) ---
bool IsTrendBullish()
{
   if(!Inp_UseTrendFilter) return true;

   double ma[];
   ArraySetAsSeries(ma, true);
   int copied = CopyBuffer(g_hMA_Trend, 0, 0, Inp_TrendLookback + 2, ma);
   if(copied < Inp_TrendLookback + 2) return true; // Default to allow if insufficient data

   // Check if price is above MA and MA is rising
   double currentPrice = iClose(_Symbol, PERIOD_H1, 0);
   bool aboveMA = currentPrice > ma[0];
   bool maRising = ma[0] > ma[Inp_TrendLookback];

   return aboveMA && maRising;
}

bool IsTrendBearish()
{
   if(!Inp_UseTrendFilter) return true;

   double ma[];
   ArraySetAsSeries(ma, true);
   int copied = CopyBuffer(g_hMA_Trend, 0, 0, Inp_TrendLookback + 2, ma);
   if(copied < Inp_TrendLookback + 2) return true; // Default to allow if insufficient data

   // Check if price is below MA and MA is falling
   double currentPrice = iClose(_Symbol, PERIOD_H1, 0);
   bool belowMA = currentPrice < ma[0];
   bool maFalling = ma[0] < ma[Inp_TrendLookback];

   return belowMA && maFalling;
}

// --- Trailing Stop Management ---
void ManageTrailingStops()
{
   if(!Inp_UseTrailingStop) return;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(magic != Inp_Magic || symbol != _Symbol) continue;

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double volume = PositionGetDouble(POSITION_VOLUME);

      double bid, ask;
      if(!GetBidAsk(bid, ask)) continue;

      double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;
      double initialRisk = MathAbs(openPrice - currentSL);

      if(posType == POSITION_TYPE_BUY)
      {
         double profit = currentPrice - openPrice;
         double profitInR = profit / initialRisk;

         if(profitInR >= Inp_TrailingStartRR)
         {
            double newSL = openPrice + (profitInR - Inp_TrailingStopRR) * initialRisk;
            newSL = Norm(newSL);

            if(newSL > currentSL + Inp_TrailingStepRR * initialRisk)
            {
               trade.PositionModify(ticket, newSL, currentTP);
               if(Inp_VerboseLog)
                  PrintFormat("[%s] Trailing SL updated for LONG #%I64u: %.5f -> %.5f (%.1fR profit)",
                              Inp_EA_Tag, ticket, currentSL, newSL, profitInR);
            }
         }
      }
      else // SHORT
      {
         double profit = openPrice - currentPrice;
         double profitInR = profit / initialRisk;

         if(profitInR >= Inp_TrailingStartRR)
         {
            double newSL = openPrice - (profitInR - Inp_TrailingStopRR) * initialRisk;
            newSL = Norm(newSL);

            if(newSL < currentSL - Inp_TrailingStepRR * initialRisk)
            {
               trade.PositionModify(ticket, newSL, currentTP);
               if(Inp_VerboseLog)
                  PrintFormat("[%s] Trailing SL updated for SHORT #%I64u: %.5f -> %.5f (%.1fR profit)",
                              Inp_EA_Tag, ticket, currentSL, newSL, profitInR);
            }
         }
      }
   }
}

// --- Partial Profit Taking ---
void ManagePartialProfits()
{
   if(!Inp_UsePartialTP) return;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(magic != Inp_Magic || symbol != _Symbol) continue;

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      string comment = PositionGetString(POSITION_COMMENT);

      // Skip if already partially closed
      if(StringFind(comment, "PartialTP") >= 0) continue;

      double bid, ask;
      if(!GetBidAsk(bid, ask)) continue;

      double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;
      double initialRisk = MathAbs(openPrice - currentSL);

      if(posType == POSITION_TYPE_BUY)
      {
         double profit = currentPrice - openPrice;
         double profitInR = profit / initialRisk;

         // First partial TP
         if(profitInR >= Inp_PartialTP1_RR && StringFind(comment, "TP1") < 0)
         {
            double closeVolume = NormalizeDouble(volume * Inp_PartialTP1_Percent / 100.0, 2);
            if(closeVolume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
            {
               trade.PositionClosePartial(ticket, closeVolume);
               if(Inp_VerboseLog)
                  PrintFormat("[%s] Partial TP1 executed for #%I64u: %.2f lots at %.1fR",
                              Inp_EA_Tag, ticket, closeVolume, profitInR);
            }
         }

         // Second partial TP
         if(profitInR >= Inp_PartialTP2_RR && StringFind(comment, "TP2") < 0)
         {
            double remainingVolume = PositionGetDouble(POSITION_VOLUME);
            double closeVolume = NormalizeDouble(remainingVolume * Inp_PartialTP2_Percent / 100.0, 2);
            if(closeVolume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
            {
               trade.PositionClosePartial(ticket, closeVolume);
               if(Inp_VerboseLog)
                  PrintFormat("[%s] Partial TP2 executed for #%I64u: %.2f lots at %.1fR",
                              Inp_EA_Tag, ticket, closeVolume, profitInR);
            }
         }
      }
      else // SHORT
      {
         double profit = openPrice - currentPrice;
         double profitInR = profit / initialRisk;

         // First partial TP
         if(profitInR >= Inp_PartialTP1_RR && StringFind(comment, "TP1") < 0)
         {
            double closeVolume = NormalizeDouble(volume * Inp_PartialTP1_Percent / 100.0, 2);
            if(closeVolume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
            {
               trade.PositionClosePartial(ticket, closeVolume);
               if(Inp_VerboseLog)
                  PrintFormat("[%s] Partial TP1 executed for SHORT #%I64u: %.2f lots at %.1fR",
                              Inp_EA_Tag, ticket, closeVolume, profitInR);
            }
         }

         // Second partial TP
         if(profitInR >= Inp_PartialTP2_RR && StringFind(comment, "TP2") < 0)
         {
            double remainingVolume = PositionGetDouble(POSITION_VOLUME);
            double closeVolume = NormalizeDouble(remainingVolume * Inp_PartialTP2_Percent / 100.0, 2);
            if(closeVolume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
            {
               trade.PositionClosePartial(ticket, closeVolume);
               if(Inp_VerboseLog)
                  PrintFormat("[%s] Partial TP2 executed for SHORT #%I64u: %.2f lots at %.1fR",
                              Inp_EA_Tag, ticket, closeVolume, profitInR);
            }
         }
      }
   }
}

// --- Volume digits helper (robust if SYMBOL_VOLUME_DIGITS is unavailable) ---
int VolumeDigitsFromStep()
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) return 2;
   int d = 0;
   double v = step;
   while(MathAbs(v - MathRound(v)) > 1e-8 && d < 8)
   {
      v *= 10.0;
      d++;
   }
   return d;
}

// --- Money management ---
double ClampToStep(double vol)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   int    volDigits = VolumeDigitsFromStep();

   if(vol < minLot) vol = minLot;
   if(vol > maxLot) vol = maxLot;

   if(stepLot > 0.0)
   {
      // quantize til nærmeste step fra minLot
      double steps = MathFloor((vol - minLot)/stepLot + 1e-8);
      vol = minLot + steps*stepLot;
   }
   return NormalizeDouble(vol, volDigits);
}

double CalcVolumeForRisk(double entry, double sl)
{
   if(Inp_UseFixedLots) return ClampToStep(Inp_FixedLots);

   // Use equity or balance based on setting
   double accountValue = Inp_UseEquityRisk ?
                        AccountInfoDouble(ACCOUNT_EQUITY) :
                        AccountInfoDouble(ACCOUNT_BALANCE);

   double riskMoney = accountValue * (Inp_RiskPercent/100.0);

   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal<=0.0 || tickSize<=0.0) return ClampToStep(Inp_FixedLots);

   double valuePerPriceUnitPerLot = tickVal / tickSize; // værdi pr. 1.0 pris-enhed pr. 1 lot
   double priceRisk      = MathAbs(entry - sl);         // pris-enheder
   if(priceRisk <= 0) return ClampToStep(Inp_FixedLots);

   double vol = riskMoney / (priceRisk * valuePerPriceUnitPerLot);
   return ClampToStep(vol);
}

// --- SL/TP calculation ---
void ComputeSLTP_Long(const MqlRates &b3, double entry, double &sl, double &tp)
{
   double baseSL = b3.low;

   if(Inp_SL_Mode == SL_BREAKOUT_MINUS_ATR)
   {
      double atrPts = GetATRPointsFromHandle(g_hATR_SL, 1);
      if(atrPts > 0)
         baseSL = baseSL - (atrPts * Inp_SL_ATR_Mult) * _Point;
   }
   else if(Inp_SL_Mode == SL_BREAKOUT_MINUS_BUFFER)
   {
      baseSL = baseSL - Inp_SL_BufferPoints * _Point;
   }
   sl = baseSL;

   if(Inp_TP_Mode == TP_RR_MULTIPLE)
   {
      double risk = entry - sl;
      tp = entry + Inp_RR_Multiple * risk;
   }
   else // TP_ATR_MULTIPLE
   {
      double atrPts = GetATRPointsFromHandle(g_hATR_TP, 1);
      if(atrPts <= 0) atrPts = (entry - sl)/_Point; // fallback
      tp = entry + (atrPts * Inp_TP_ATR_Mult) * _Point;
   }
}

void ComputeSLTP_Short(const MqlRates &b3, double entry, double &sl, double &tp)
{
   double baseSL = b3.high;

   if(Inp_SL_Mode == SL_BREAKOUT_MINUS_ATR)
   {
      double atrPts = GetATRPointsFromHandle(g_hATR_SL, 1);
      if(atrPts > 0)
         baseSL = baseSL + (atrPts * Inp_SL_ATR_Mult) * _Point;
   }
   else if(Inp_SL_Mode == SL_BREAKOUT_MINUS_BUFFER)
   {
      baseSL = baseSL + Inp_SL_BufferPoints * _Point;
   }
   sl = baseSL;

   if(Inp_TP_Mode == TP_RR_MULTIPLE)
   {
      double risk = sl - entry;
      tp = entry - Inp_RR_Multiple * risk;
   }
   else
   {
      double atrPts = GetATRPointsFromHandle(g_hATR_TP, 1);
      if(atrPts <= 0) atrPts = (sl - entry)/_Point; // fallback
      tp = entry - (atrPts * Inp_TP_ATR_Mult) * _Point;
   }
}

// --- Position count by magic/symbol (uden PositionSelectByIndex) ---
int PositionsCountByMagicSymbol()
{
   int total = 0;
   int cnt = PositionsTotal();
   for(int idx=0; idx<cnt; ++idx)
   {
      ulong ticket = PositionGetTicket(idx);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      long   magic = (long)PositionGetInteger(POSITION_MAGIC);
      string sym   = PositionGetString(POSITION_SYMBOL);
      if(magic == Inp_Magic && sym == _Symbol)
         total++;
   }
   return total;
}


//=========================== SIGNAL EVALUERING =========================
void EvaluateSignals()
{
   if(Period() != PERIOD_M5)
   {
      static bool warned=false;
      if(!warned) { Print("WARNING: Attach EA to M5 chart for korrekt logik."); warned=true; }
   }

   // Ny handelsdag?
   MqlDateTime now; TimeToStruct(TimeCurrent(), now);
   if(now.day_of_year != g_dayOfYear)
   {
      g_dayOfYear = now.day_of_year;
      ResetDayCounters();
      BuildORBWindow(TimeCurrent());
      if(Inp_VerboseLog)
         PrintFormat("[%s] Ny handelsdag. ORB %02d:%02d i %d min (server).",
                     Inp_EA_Tag, Inp_ORB_StartHour, Inp_ORB_StartMinute, Inp_ORB_DurationMin);
   }

   // ORB klar?
   if(!g_orbReady && TimeCurrent() >= g_orbEnd)
      g_orbReady = ComputeORBRange();
   if(!g_orbReady) return;

   // Hårde limits
   if(Inp_OnePositionAtATime && PositionsCountByMagicSymbol() > 0) return;
   if(g_tradesToday >= Inp_MaxTradesPerDay) return;

   // Daily P&L limits
   if(!CheckDailyLimits()) return;

   // Volatilitetsfilter (ATR på M5) — kun low-vol cut; high-vol er tilladt hvis ønsket
if(Inp_EnableATRVolFilter)
{
   double atrPts = GetATRPointsFromHandle(g_hATR_Filter, 1);
   if(atrPts <= 0) return;

   // Bloker KUN hvis ATR er under minimum (stille regime)
   if(atrPts < Inp_ATR_MinPoints)
   {
      if(Inp_VerboseLog)
         PrintFormat("ATR filter: %.2f < min %.2f – skip (for lav vol).", atrPts, Inp_ATR_MinPoints);
      return;
   }

   // Hvis ikke vi ignorerer høj ATR, kan du let aktivere en øvre vagt her:
   if(!Inp_ATR_IgnoreHigh)
   {
      // eksempel: blød øvre vagt, kommentér ind hvis du vil bruge den
      // double softMax = Inp_ATR_MinPoints * 10.0; // vilkårligt loft
      // if(atrPts > softMax && Inp_VerboseLog)
      //    PrintFormat("ATR høj (%.2f), men tilladt.", atrPts);
   }
 }



   // Få barer
   MqlRates b1,b2,b3;
   if(!CopyRecentRates(b1,b2,b3)) return;

   // Session filter – brug b1.time (3. bars close)
   if(Inp_EnableSessions && !IsWithinSessions(b1.time))
   {
      if(Inp_VerboseLog) PrintFormat("Uden for session: %s", TimeToString(b1.time));
      return;
   }

   // Spread filter
   if(!SpreadOK()) { if(Inp_VerboseLog) Print("Spread filter – skip."); return; }

   // Multi-breakout styring
   bool firstOnlyBlock = (Inp_TradeLimitMode == FIRST_ONLY) && (g_tradedLongToday || g_tradedShortToday);

   // === LONG ===
   if(!firstOnlyBlock && !(Inp_TradeLimitMode==ONE_EACH_DIR && g_tradedLongToday))
   {
      if(IsBullBreakout(b3) && BreakoutBodyStrong(b3) && FVGStrictEnough_Bull(b3,b1) &&
         ThirdClosesBeyondORB_Long(b1) && IsMarketStructureBullish() &&
         IsVolumeConfirmed(b3) && IsTrendBullish())
      {
         if(g_lastSignalTimeLong != b1.time)
         {
            double entry = Inp_EnterAtCandleClose ? b1.close : (b1.high + Inp_BufferPoints*_Point);
            double sl,tp; ComputeSLTP_Long(b3, entry, sl, tp);

            // Stops level check
            int stops = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            if(stops > 0)
            {
               double minDist = stops * _Point;
               if( (entry - sl) < minDist || (tp - entry) < minDist )
               {
                  if(Inp_VerboseLog) Print("Stops level for tight (long) – skip.");
               }
               else
               {
                  double vol = CalcVolumeForRisk(entry, sl);
                  trade.SetExpertMagicNumber(Inp_Magic);
                  trade.SetDeviationInPoints(Inp_MaxSlippagePoints);
                  bool ok = trade.Buy(vol, _Symbol, 0.0, Norm(sl), Norm(tp), Inp_EA_Tag);
                  if(ok)
                  {
                     g_tradesToday++;
                     g_tradedLongToday = true;
                     g_lastSignalTimeLong = b1.time;
                     if(Inp_VerboseLog)
                        PrintFormat("LONG: vol=%.2f entry~%.5f SL=%.5f TP=%.5f ORB[H=%.5f L=%.5f]",
                                    vol, entry, sl, tp, g_orbHigh, g_orbLow);
                     if(Inp_TradeLimitMode==FIRST_ONLY) return;
                  }
                  else if(Inp_VerboseLog)
                     PrintFormat("LONG FAILED: retcode=%d err=%d", (int)trade.ResultRetcode(), (int)GetLastError());
               }
            }
         }
      }
   }

   // === SHORT ===
   if(!firstOnlyBlock && !(Inp_TradeLimitMode==ONE_EACH_DIR && g_tradedShortToday))
   {
      if(IsBearBreakout(b3) && BreakoutBodyStrong(b3) && FVGStrictEnough_Bear(b3,b1) &&
         ThirdClosesBeyondORB_Short(b1) && IsMarketStructureBearish() &&
         IsVolumeConfirmed(b3) && IsTrendBearish())
      {
         if(g_lastSignalTimeShort != b1.time)
         {
            double entry = Inp_EnterAtCandleClose ? b1.close : (b1.low - Inp_BufferPoints*_Point);
            double sl,tp; ComputeSLTP_Short(b3, entry, sl, tp);

            int stops = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            if(stops > 0)
            {
               double minDist = stops * _Point;
               if( (sl - entry) < minDist || (entry - tp) < minDist )
               {
                  if(Inp_VerboseLog) Print("Stops level for tight (short) – skip.");
               }
               else
               {
                  double vol = CalcVolumeForRisk(entry, sl);
                  trade.SetExpertMagicNumber(Inp_Magic);
                  trade.SetDeviationInPoints(Inp_MaxSlippagePoints);
                  bool ok = trade.Sell(vol, _Symbol, 0.0, Norm(sl), Norm(tp), Inp_EA_Tag);
                  if(ok)
                  {
                     g_tradesToday++;
                     g_tradedShortToday = true;
                     g_lastSignalTimeShort = b1.time;
                     if(Inp_VerboseLog)
                        PrintFormat("SHORT: vol=%.2f entry~%.5f SL=%.5f TP=%.5f ORB[H=%.5f L=%.5f]",
                                    vol, entry, sl, tp, g_orbHigh, g_orbLow);
                  }
                  else if(Inp_VerboseLog)
                     PrintFormat("SHORT FAILED: retcode=%d err=%d", (int)trade.ResultRetcode(), (int)GetLastError());
               }
            }
         }
      }
   }
}

//=============================== EVENTS ===============================
int OnInit()
{
   trade.SetExpertMagicNumber(Inp_Magic);
   trade.SetDeviationInPoints(Inp_MaxSlippagePoints);

   // ATR handles
   g_hATR_Filter = iATR(_Symbol, PERIOD_M5, Inp_ATR_Filter_Period);
   g_hATR_SL     = iATR(_Symbol, PERIOD_M5, Inp_SL_ATR_Period);
   g_hATR_TP     = iATR(_Symbol, PERIOD_M5, Inp_TP_ATR_Period);

   // MA handle for trend filter
   if(Inp_UseTrendFilter)
      g_hMA_Trend = iMA(_Symbol, PERIOD_H1, Inp_TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE);

   if(Inp_EnableATRVolFilter && g_hATR_Filter==INVALID_HANDLE)
      { Print("Failed to create ATR filter handle."); return(INIT_FAILED); }
   if(Inp_SL_Mode==SL_BREAKOUT_MINUS_ATR && g_hATR_SL==INVALID_HANDLE)
      { Print("Failed to create ATR SL handle."); return(INIT_FAILED); }
   if(Inp_TP_Mode==TP_ATR_MULTIPLE && g_hATR_TP==INVALID_HANDLE)
      { Print("Failed to create ATR TP handle."); return(INIT_FAILED); }
   if(Inp_UseTrendFilter && g_hMA_Trend==INVALID_HANDLE)
      { Print("Failed to create MA trend filter handle."); return(INIT_FAILED); }

   // Init dag & ORB
   MqlDateTime now; TimeToStruct(TimeCurrent(), now);
   g_dayOfYear = now.day_of_year;
   ResetDayCounters();
   BuildORBWindow(TimeCurrent());

   if(Inp_VerboseLog)
   {
      PrintFormat("[%s] Init %s. Symbol=%s, Digits=%d, Point=%.10f",
                  Inp_EA_Tag, TimeToString(TimeCurrent()), _Symbol, DigitsForSymbol(), _Point);
      if(Inp_EnableSessions)
      {
         PrintFormat("Session1 %02d:%02d-%02d:%02d | Session2 %02d:%02d-%02d:%02d (server).",
                     Inp_S1_StartHour, Inp_S1_StartMinute, Inp_S1_EndHour, Inp_S1_EndMinute,
                     Inp_S2_StartHour, Inp_S2_StartMinute, Inp_S2_EndHour, Inp_S2_EndMinute);
      }
      PrintFormat("Enhanced Features: TrailingStop=%s, PartialTP=%s, MarketStructure=%s, Volume=%s, Trend=%s",
                  Inp_UseTrailingStop ? "ON" : "OFF",
                  Inp_UsePartialTP ? "ON" : "OFF",
                  Inp_UseMarketStructure ? "ON" : "OFF",
                  Inp_UseVolumeFilter ? "ON" : "OFF",
                  Inp_UseTrendFilter ? "ON" : "OFF");
      PrintFormat("Risk Management: MaxDailyLoss=%.1f%%, MaxDailyProfit=%.1f%%, EquityRisk=%s",
                  Inp_MaxDailyLoss, Inp_MaxDailyProfit, Inp_UseEquityRisk ? "ON" : "OFF");
   }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(g_hATR_Filter!=INVALID_HANDLE) IndicatorRelease(g_hATR_Filter);
   if(g_hATR_SL    !=INVALID_HANDLE) IndicatorRelease(g_hATR_SL);
   if(g_hATR_TP    !=INVALID_HANDLE) IndicatorRelease(g_hATR_TP);
   if(g_hMA_Trend  !=INVALID_HANDLE) IndicatorRelease(g_hMA_Trend);

   if(Inp_VerboseLog)
      PrintFormat("[%s] Deinit. Reason=%d", Inp_EA_Tag, reason);
}

void OnTick()
{
   UpdateSpreadEMA();

   // Manage existing positions
   ManageTrailingStops();
   ManagePartialProfits();

   datetime curBarTime = iTime(_Symbol, PERIOD_M5, 0);
   if(curBarTime != g_lastBarTime)
   {
      g_lastBarTime = curBarTime;
      EvaluateSignals();
   }
}
//+------------------------------------------------------------------+
