# Admiral Pivot Points DAX EA - Komplet Strategiguide

## 📋 Oversigt

Admiral Pivot Points DAX EA er en avanceret Expert Advisor designet specifikt til DAX trading. EA'en implementerer en sofistikeret multi-indikator strategi baseret på Admiral Pivot Points kombineret med teknisk analyse og intelligent risikostyring.

### 🎯 Strategiens Kerneelementer

**Primære Indikatorer:**
- **Admiral Pivot Points** (H1/D1 timeframes) - Støtte/modstandsniveauer
- **MACD** (12,26,1) - Trend og momentum
- **Stochastic** (14,3,3) - Overkøbt/oversolgt niveauer
- **Moving Averages** - 4 EMA (close) vs 6 SMMA (HLCC/4)
- **Swing Point Detection** - Dynamisk stop loss placering

**Avancerede Features:**
- Multi-timeframe analyse
- Intelligent risikostyring med dynamiske stop loss
- Pivot-baserede take profit targets
- Swing-baserede stop loss beregninger
- Omfattende markedsvalidering

## 🏗️ Arkitektur og Komponenter

### Hovedfiler
```
New_Dax/
├── New_Dax.mq5                    # Hovedfil (Expert Advisor)
├── Test_Admiral_EA.mq5             # Komplet test suite
├── Debug_Indicators.mq5            # Indikator debug værktøj
├── INSTALLATION_GUIDE.md           # Installations guide
├── Include/
│   ├── AdmiralStrategy.mqh         # Hovedstrategi klasse
│   ├── AdmiralPivotPoints.mqh      # Pivot points beregninger
│   ├── MACDSignal.mqh              # MACD signal detection
│   ├── StochasticSignal.mqh        # Stochastic oscillator
│   ├── MovingAverageSignal.mqh     # EMA/SMMA crossover
│   └── SwingPointDetector.mqh      # Swing high/low detection
└── README.md                       # Denne fil
```

### Klasse Hierarki

**CAdmiralStrategy** (Hovedklasse)
- Koordinerer alle indikatorer og signaler
- Implementerer entry/exit logik
- Håndterer risikostyring og position management

**CAdmiralPivotPoints**
- Beregner traditionelle pivot points: P, R1-R3, S1-S3
- Multi-timeframe support (H1, D1)
- Automatisk opdatering ved nye perioder

**CMACDSignal**
- MACD(12,26,1) beregninger
- Trend detection (bullish/bearish)
- Signal strength analyse

**CStochasticSignal**
- Stochastic(14,3,3) oscillator
- Overkøbt/oversolgt detection
- 50-niveau crossover signaler

**CMovingAverageSignal**
- 4 EMA på close price
- 6 SMMA på HLCC/4 (High+Low+Close+Close)/4
- Crossover og momentum analyse

**CSwingPointDetector**
- Automatisk swing high/low detection
- Dynamisk stop loss beregning
- Historisk swing point tracking

## 📊 Handelsstrategi i Detaljer

### Long Entry Kriterier
```mql5
✅ Stochastic > 50 (bullish momentum)
✅ 4 EMA > 6 SMMA (trend confirmation)
✅ MACD > 0 (positive momentum)
✅ Signal strength > minimum threshold (0.7)
✅ Markedsvalidering (spread, volatilitet)
```

### Short Entry Kriterier
```mql5
✅ Stochastic < 50 (bearish momentum)
✅ 4 EMA < 6 SMMA (downtrend confirmation)
✅ MACD < 0 (negative momentum)
✅ Signal strength > minimum threshold (0.7)
✅ Markedsvalidering (spread, volatilitet)
```

### Stop Loss Beregning
EA'en bruger en intelligent 3-lags stop loss strategi:

1. **Swing-baseret SL** (primær)
   - Placeres ved seneste swing low/high
   - Buffer: 7 pips (konfigurerbar)
   - Dynamisk justering baseret på volatilitet

2. **Default SL** (backup)
   - Fast 10 pips distance
   - Bruges hvis swing detection fejler
   - Minimum broker requirements respekteret

3. **Maximum SL** (sikkerhed)
   - Maksimum 50 pips distance
   - Automatisk begrænsning af risiko
   - Overskrides aldrig

### Take Profit Strategi
```mql5
🎯 Primær: Næste Admiral Pivot Level
   - Long: Næste resistance (R1, R2, R3)
   - Short: Næste support (S1, S2, S3)

🎯 Backup: Risk/Reward baseret
   - Minimum 2:1 risk/reward ratio
   - Dynamisk justering baseret på markedsforhold
```

## ⚙️ Konfiguration og Parametre

### Risikostyring
```mql5
input double InpLotSize = 0.01;                    // Fast lot størrelse
input double InpRiskPercent = 1.0;                 // Risiko per handel (%)
input bool InpUseFixedLots = true;                 // Brug fast lots
input double InpMinSLDistance = 10.0;              // Min SL distance (pips)
input double InpMaxSLDistance = 50.0;              // Max SL distance (pips)
input int InpMaxDailyTrades = 5;                   // Max handler per dag
input double InpMaxDailyLoss = 500.0;              // Max dagligt tab
```

### Strategi Parametre
```mql5
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15;   // Handel timeframe
input ENUM_TIMEFRAMES InpPivotTimeframe = PERIOD_H1; // Pivot timeframe
input double InpMinSignalStrength = 0.7;           // Min signal styrke
input int InpStopLossBuffer = 7;                   // SL buffer (pips)
input bool InpUseDynamicStops = true;              // Dynamiske stops
input bool InpUsePivotTargets = true;              // Pivot targets
```

### Handelstider
```mql5
input int InpStartHour = 8;                        // Start time (CET)
input int InpEndHour = 22;                         // Slut time (CET)
input bool InpTradeOnFriday = false;               // Handel fredag
```

## 🔍 Admiral Pivot Points Formler

EA'en implementerer de klassiske Admiral Pivot Points formler:

```mql5
// Basis Pivot Point
P = (High + Low + Close) / 3

// Resistance Levels
R1 = (2 × P) - Low
R2 = P + (High - Low)
R3 = High + 2 × (P - Low)

// Support Levels
S1 = (2 × P) - High
S2 = P - (High - Low)
S3 = Low - 2 × (High - P)
```

### Multi-Timeframe Support
- **H1 Pivots**: Til intraday scalping (hurtige targets)
- **D1 Pivots**: Til swing trading (større targets)
- Automatisk opdatering ved nye perioder
- Intelligent level selection baseret på markedsforhold

## 🧠 Signal Strength Beregning

EA'en beregner signal styrke baseret på alle indikatorer:

```mql5
Signal Strength = (MACD_Score + Stochastic_Score + MA_Score) / 3

MACD_Score:
- 1.0: Stærk bullish/bearish
- 0.5: Svag trend
- 0.0: Neutral

Stochastic_Score:
- 1.0: Klar over/under 50
- 0.5: Nær 50 niveau
- 0.0: Modsat signal

MA_Score:
- 1.0: Klar crossover + momentum
- 0.5: Crossover uden momentum
- 0.0: Ingen crossover
```

## 🛡️ Risikostyring og Sikkerhed

### Automatiske Sikkerhedsforanstaltninger
1. **Daglige Limits**
   - Maksimum antal handler per dag
   - Maksimum dagligt tab
   - Automatisk stop ved limits

2. **Position Sizing**
   - Risk-baseret lot beregning
   - Maksimum lot size begrænsning
   - Account balance protection

3. **Market Validation**
   - Spread kontrol
   - Volatilitet checks
   - Markedsåbningstider
   - Weekend/helligdag beskyttelse

4. **Error Handling**
   - Automatisk genoprettelse
   - Logging af alle fejl
   - Graceful degradation mode

### Stop Loss Validering
```mql5
// DAX-specifik validering (1 pip = 0.1 price units)
Minimum SL: 10 pips (1.0 price units)
Maximum SL: 50 pips (5.0 price units)
Broker minimum: Automatisk respekteret
```

## 📈 Performance Monitoring

### Indbygget Statistik
- Win rate tracking
- Average profit/loss
- Maximum drawdown
- Sharpe ratio beregning
- Daily/weekly performance

### Logging System
```mql5
[TIMESTAMP] SIGNAL: Direction | Strength | Entry | SL | TP
[TIMESTAMP] TRADE: Executed | Ticket | Result
[TIMESTAMP] ERROR: Description | Recovery Action
[TIMESTAMP] STATS: Daily P&L | Win Rate | Drawdown
```

## 🚀 Installation og Opsætning

### Trin 1: Installation
1. Kopier alle filer til `MQL5/Experts/New_Dax/`
2. Kompiler `New_Dax.mq5` i MetaEditor
3. Genstart MetaTrader 5

### Trin 2: Konfiguration
1. Åbn EA på DAX chart (M15 anbefalet)
2. Juster risiko parametre efter din konto
3. Vælg passende handelstider
4. Aktiver auto-trading

### Trin 3: Testing
1. Kør `Test_Admiral_EA.mq5` for komponent test
2. Backtest på historiske data
3. Forward test på demo konto
4. Gradvis øg position størrelse

## ⚠️ Vigtige Bemærkninger

### DAX-Specifik Konfiguration
- **Pip Size**: 1 pip = 0.1 price units for DAX
- **Minimum Distance**: 10 pips (respekterer broker krav)
- **Optimal Timeframe**: M15 for balance mellem signaler og støj
- **Handelstider**: 08:00-22:00 CET (DAX åbningstider)

### Risiko Advarsler
⚠️ **Aldrig handel med penge du ikke har råd til at tabe**
⚠️ **Test altid på demo konto først**
⚠️ **Overvåg EA'en regelmæssigt**
⚠️ **Juster parametre baseret på markedsforhold**

## 🔧 Fejlfinding

### Almindelige Problemer
1. **"TRADE REJECTED: Stop loss too far"**
   - Løsning: Justér InpMaxSLDistance parameter

2. **Ingen signaler genereret**
   - Check: Markedstider, spread, signal strength threshold

3. **For mange handler**
   - Løsning: Øg InpMinSignalStrength eller reducer InpMaxDailyTrades

### Debug Mode
Aktiver `InpVerboseLogging = true` for detaljeret logging af:
- Signal beregninger
- Indikator værdier
- Entry/exit beslutninger
- Risk management actions

## 📞 Support og Videreudvikling

### Test Suite
Brug `Test_Admiral_EA.mq5` til at verificere:
- Alle komponenter fungerer korrekt
- Signal generation virker
- Risk management er aktiv
- Performance metrics opdateres

### Tilpasning
EA'en er designet til nem tilpasning:
- Juster indikator parametre i konstruktørerne
- Modificer signal strength beregning
- Tilføj nye indikatorer til strategien
- Implementer alternative exit strategier

## 🔬 Teknisk Implementation

### Signal Generation Flow
```mql5
1. OnTick() → Ny bar check
2. UpdateSignals() → Opdater alle indikatorer
3. CheckEntrySignal() → Evaluer entry kriterier
4. CalculateSignalStrength() → Beregn signal styrke
5. ValidateSignal() → Markedsvalidering
6. ExecuteTrade() → Udfør handel hvis godkendt
```

### Indikator Beregninger

**MACD Signal (12,26,1)**
```mql5
Fast EMA = EMA(Close, 12)
Slow EMA = EMA(Close, 26)
MACD Line = Fast EMA - Slow EMA
Signal Line = EMA(MACD Line, 1)

Bullish: MACD > 0 && MACD > Signal
Bearish: MACD < 0 && MACD < Signal
```

**Stochastic (14,3,3)**
```mql5
%K = 100 * (Close - Lowest Low) / (Highest High - Lowest Low)
%D = SMA(%K, 3)
Slow %D = SMA(%D, 3)

Bullish: %D > 50
Bearish: %D < 50
```

**Moving Averages**
```mql5
Fast MA = EMA(Close, 4)
Slow MA = SMMA(HLCC/4, 6)
HLCC/4 = (High + Low + Close + Close) / 4

Bullish: Fast MA > Slow MA
Bearish: Fast MA < Slow MA
```

### Swing Point Detection Algorithm
```mql5
Swing High:
- Current High > Previous N Highs
- Current High > Next N Highs
- Minimum distance between swings

Swing Low:
- Current Low < Previous N Lows
- Current Low < Next N Lows
- Minimum distance between swings

Dynamic SL = Swing Point ± Buffer
```

## 📋 Detaljeret Kode Struktur

### AdmiralStrategy.mqh - Hovedklasse
```mql5
class CAdmiralStrategy
{
private:
    // Komponenter
    CAdmiralPivotPoints* m_pivot_points;
    CMACDSignal* m_macd_signal;
    CStochasticSignal* m_stoch_signal;
    CMovingAverageSignal* m_ma_signal;
    CSwingPointDetector* m_swing_detector;

    // Parametre
    double m_min_signal_strength;
    int m_stop_loss_buffer_pips;
    bool m_use_dynamic_stops;
    bool m_use_pivot_targets;

public:
    // Hovedmetoder
    bool Initialize();
    bool UpdateSignals();
    SAdmiralSignal CheckEntrySignal();
    bool ShouldExit(bool is_long_position);

    // Signal analyse
    bool CheckLongEntry();
    bool CheckShortEntry();
    double CalculateSignalStrength(bool is_long);

    // Position management
    double CalculateStopLoss(bool is_long, double entry_price);
    double CalculateTakeProfit(bool is_long, double entry_price);
};
```

### Signal Struktur
```mql5
struct SAdmiralSignal
{
    bool is_valid;              // Signal gyldighed
    bool is_long;               // Retning (true=long, false=short)
    double entry_price;         // Entry pris
    double stop_loss;           // Stop loss niveau
    double take_profit;         // Take profit niveau
    double signal_strength;     // Signal styrke (0.0-1.0)
    string signal_description;  // Beskrivelse
};
```

## 🎛️ Avancerede Konfigurationer

### Custom Indikator Parametre
```mql5
// I AdmiralStrategy konstruktør
m_macd_signal = new CMACDSignal(symbol, timeframe, 12, 26, 1);
m_stoch_signal = new CStochasticSignal(symbol, timeframe, 14, 3, 3);
m_ma_signal = new CMovingAverageSignal(symbol, timeframe, 4, 6);
m_swing_detector = new CSwingPointDetector(symbol, timeframe, 5, 50);
```

### Risk Management Formler
```mql5
// Position sizing
Risk Amount = Account Balance × Risk Percent / 100
Lot Size = Risk Amount / (SL Distance × Point Value)

// Maximum risk check
Max Risk = Account Balance × 5% // Aldrig mere end 5%
if (Trade Risk > Max Risk) → Reject Trade

// Daily limits
if (Daily Trades >= Max Daily Trades) → Stop Trading
if (Daily Loss >= Max Daily Loss) → Stop Trading
```

### Market Validation Checks
```mql5
// Spread kontrol
Current Spread = Ask - Bid
if (Current Spread > Max Allowed Spread) → Skip Signal

// Volatilitet check
ATR = Average True Range(14)
if (ATR < Min Volatility || ATR > Max Volatility) → Skip Signal

// Handelstider
Current Hour = Hour(TimeCurrent())
if (Current Hour < Start Hour || Current Hour > End Hour) → Skip Signal
```

## 🧪 Testing og Validering

### Unit Tests (Test_Admiral_EA.mq5)
```mql5
void TestPivotPoints()
{
    // Test pivot beregninger
    // Verificer R1, R2, R3, S1, S2, S3
    // Check multi-timeframe support
}

void TestMACDSignal()
{
    // Test MACD beregninger
    // Verificer bullish/bearish detection
    // Check signal strength
}

void TestCompleteStrategy()
{
    // Test fuld signal generation
    // Verificer entry/exit logik
    // Check risk management
}
```

### Performance Metrics
```mql5
// Automatisk beregnet statistik
Win Rate = Winning Trades / Total Trades × 100
Average Win = Sum(Winning Trades) / Number of Wins
Average Loss = Sum(Losing Trades) / Number of Losses
Profit Factor = Gross Profit / Gross Loss
Maximum Drawdown = Largest Peak-to-Trough Decline
Sharpe Ratio = (Return - Risk Free Rate) / Standard Deviation
```

### Backtest Anbefalinger
```mql5
// Optimal test periode
Minimum: 3 måneder historiske data
Anbefalet: 12 måneder for sæsonalitet
Spread: Realistisk spread (2-5 points for DAX)
Slippage: 1-2 points
Commission: Inkluder broker kommission
```

## 🔄 Maintenance og Opdateringer

### Regelmæssig Vedligeholdelse
1. **Ugentlig**: Check performance metrics
2. **Månedlig**: Juster parametre baseret på markedsforhold
3. **Kvartalsvis**: Fuld backtest på nye data
4. **Årligt**: Strategireview og optimering

### Parameter Optimering
```mql5
// Optimerbare parametre
Signal Strength Threshold: 0.5 - 0.9 (step 0.1)
Stop Loss Buffer: 5 - 15 pips (step 2)
MACD Periods: Fast(8-16), Slow(20-30), Signal(1-3)
Stochastic Periods: K(10-20), D(3-5), Slow(3-5)
MA Periods: Fast(3-6), Slow(5-10)
```

### Version Control
```
v1.00 - Initial release
v1.01 - Fixed SL validation bug
v1.02 - Enhanced signal strength calculation
v1.03 - Added market validation
v1.04 - Improved risk management
```

## 📚 Uddybende Ressourcer

### Admiral Pivot Points Teori
- Baseret på klassiske pivot point formler
- Udviklet til intraday trading
- Effektive på volatile markeder som DAX
- Kombinerer godt med momentum indikatorer

### DAX Markedskarakteristika
- **Handelstider**: 09:00-17:30 CET (XETRA)
- **Volatilitet**: Høj under europæiske timer
- **Typisk spread**: 1-3 points
- **Minimum tick**: 0.5 points
- **Pip værdi**: 1 pip = 0.1 price units

### Risiko Disclaimer
⚠️ **VIGTIG**: Denne EA er et værktøj til automatiseret trading og garanterer ikke profit. Alle investeringer indebærer risiko for tab. Test altid grundigt på demo konto før live trading. Overvåg EA'en regelmæssigt og juster parametre efter markedsforhold.

---

**Version**: 1.00
**Sidste opdatering**: August 2025
**Kompatibilitet**: MetaTrader 5 Build 3815+
**Symbol**: DAX (DE30, GER30, etc.)
**Licens**: Proprietær - Kun til personlig brug
