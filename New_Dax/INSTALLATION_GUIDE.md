# Admiral Pivot Points DAX EA - Installation Guide

## 📋 Oversigt

Admiral Pivot Points DAX EA er en avanceret Expert Advisor designet specifikt til DAX trading baseret på Admiral Pivot Points strategien. EA'en kombinerer:

- **Admiral Pivot Points** (H1/D1 timeframes)
- **MACD** (12,26,1) 
- **Stochastic** (14,3,3) med 50 trigger niveau
- **Moving Averages** (4 EMA på close, 6 SMMA på HLCC/4)
- **Swing Point Detection** for dynamisk stop loss

## 🏗️ Arkitektur

```
New_Dax/
├── New_Dax.mq5                    # Hovedfil (Expert Advisor)
├── Test_Admiral_EA.mq5             # Test script
├── Include/
│   ├── AdmiralPivotPoints.mqh      # Pivot points beregninger
│   ├── MACDSignal.mqh              # MACD signal detection
│   ├── StochasticSignal.mqh        # Stochastic oscillator
│   ├── MovingAverageSignal.mqh     # EMA/SMMA crossover
│   ├── SwingPointDetector.mqh      # Swing high/low detection
│   └── AdmiralStrategy.mqh         # Hovedstrategi klasse
└── README.md                       # Strategi beskrivelse
```

## 📦 Installation

### 1. Kopier filer til MT5
```
MT5_Data_Folder/
└── MQL5/
    └── Experts/
        └── New_Dax/
            ├── New_Dax.mq5
            ├── Test_Admiral_EA.mq5
            └── Include/
                ├── AdmiralPivotPoints.mqh
                ├── MACDSignal.mqh
                ├── StochasticSignal.mqh
                ├── MovingAverageSignal.mqh
                ├── SwingPointDetector.mqh
                └── AdmiralStrategy.mqh
```

### 2. Kompiler EA'en
1. Åbn MetaEditor
2. Åbn `New_Dax.mq5`
3. Tryk F7 eller klik "Compile"
4. Kontroller at der ikke er fejl

### 3. Test komponenter
1. Åbn `Test_Admiral_EA.mq5`
2. Kompiler og kør som script
3. Kontroller output i Expert tab

## ⚙️ Konfiguration

### Strategi Indstillinger
- **InpTimeframe**: M5 eller M15 (anbefalet: M15)
- **InpPivotTimeframe**: H1 eller D1 (anbefalet: H1)
- **InpMinSignalStrength**: 0.7 (70% af indikatorer skal være enige)
- **InpStopLossBuffer**: 7 pips buffer fra swing points
- **InpUseDynamicStops**: true (brug swing-baserede stops)
- **InpUsePivotTargets**: true (brug pivot levels som targets)

### Risk Management
- **InpLotSize**: 0.1 (fast lot størrelse)
- **InpRiskPercent**: 2.0% (risiko per trade hvis dynamic)
- **InpUseFixedLots**: true (false = risk-baseret)
- **InpMaxDailyTrades**: 5 (maksimum trades per dag)
- **InpMaxDailyLoss**: 500 (maksimum dagligt tab)

### Trading Timer
- **InpStartHour**: 8 (start trading kl. 08:00)
- **InpEndHour**: 16 (stop trading kl. 16:00)
- **InpTradeOnFriday**: false (undgå fredag trading)

## 📊 Strategi Logic

### Long Entry Betingelser
1. **Stochastic > 50**
2. **4 EMA > 6 SMMA** (blå linje over rød linje)
3. **MACD > 0** (histogram over nul-linjen)

### Short Entry Betingelser
1. **Stochastic < 50**
2. **4 EMA < 6 SMMA** (blå linje under rød linje)
3. **MACD < 0** (histogram under nul-linjen)

### Exit Betingelser
- **Target**: Næste Admiral pivot level
- **Stop Loss**: 5-10 pips fra sidste swing point
- **Early Exit**: Hvis prisudvikling er sløv nær pivot levels
- **Signal Reversal**: Hvis indikatorer skifter retning

## 🧪 Testing

### Backtest Indstillinger
- **Symbol**: DAX (DE40)
- **Timeframe**: M15
- **Period**: Minimum 3 måneder
- **Spread**: 1-2 points (realistisk)
- **Commission**: Inkluder broker kommission

### Forventede Resultater
- **Win Rate**: 60-70%
- **Risk/Reward**: 1:1.5 til 1:2
- **Max Drawdown**: <15%
- **Profit Factor**: >1.3

## 🔧 Optimering

### Parametre til optimering
1. **Signal Strength**: 0.6-0.8
2. **Stop Loss Buffer**: 5-10 pips
3. **Timeframes**: M5 vs M15
4. **Pivot Timeframe**: H1 vs D1

### Performance Monitoring
- Overvåg daily P&L
- Kontroller signal kvalitet
- Juster parametre baseret på markedsforhold

## ⚠️ Vigtige Noter

1. **Kun DAX**: EA'en er optimeret til DAX karakteristika
2. **Markedstimer**: Undgå tidlige/sene timer med lav likviditet
3. **Nyhedshændelser**: Vær forsigtig omkring store økonomiske begivenheder
4. **Spread**: Kontroller spread før trading
5. **Slippage**: Indstil realistisk slippage tolerance

## 🐛 Troubleshooting

### Almindelige Problemer
1. **"Strategy not initialized"**: Kontroller symbol og timeframe
2. **"Invalid signal strength"**: Juster MinSignalStrength parameter
3. **"No trades executed"**: Kontroller trading timer og daily limits
4. **"Invalid lot size"**: Kontroller account balance og risk settings

### Debug Mode
Sæt `InpVerboseLogging = true` for detaljeret logging.

## 📈 Yderligere Forbedringer

### Mulige Udvidelser
1. **News Filter**: Undgå trading omkring vigtige nyheder
2. **Volatility Filter**: Juster position størrelse baseret på volatilitet
3. **Multi-Timeframe**: Tilføj højere timeframe trend filter
4. **Machine Learning**: Implementer adaptive parametre

## 📞 Support

For spørgsmål eller problemer, kontakt udvikler med:
- EA version
- MT5 build nummer
- Detaljeret fejlbeskrivelse
- Log output fra Expert tab
