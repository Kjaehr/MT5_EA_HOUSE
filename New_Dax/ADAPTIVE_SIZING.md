# 🎯 **ADAPTIVE POSITION SIZING SYSTEM**

## 📊 **OVERSIGT**

Det adaptive position sizing system er en avanceret risikostyringsfunktion der automatisk justerer position størrelser baseret på:

1. **Drawdown-Adaptive Sizing** - Reducerer position størrelse under drawdown
2. **Performance-Adaptive Sizing** - Justerer baseret på recent trading performance  
3. **Seasonal Integration** - Kombinerer med eksisterende sæsonale multipliers
4. **Volatility Integration** - Kombinerer med volatilitet-adaptive sizing

## 🔧 **TEKNISK IMPLEMENTERING**

### **Nye Input Parametre:**
```cpp
input bool InpUseDrawdownAdaptive = true;              // Enable drawdown-adaptive sizing
input double InpDrawdownThreshold = 5.0;               // Drawdown threshold (%) to start reducing size
input double InpMaxDrawdownReduction = 0.5;            // Maximum size reduction at high drawdown (50%)
input bool InpUsePerformanceAdaptive = true;           // Enable performance-adaptive sizing
input int InpPerformanceLookback = 20;                 // Number of trades to analyze for performance
input double InpMinPerformanceMultiplier = 0.7;       // Minimum multiplier for poor performance
input double InpMaxPerformanceMultiplier = 1.3;       // Maximum multiplier for good performance
```

### **Nye Globale Variabler:**
```cpp
double g_recent_trades_pnl[];      // Array til at tracke recent trades
double g_peak_equity = 0.0;        // Peak equity for drawdown calculation
double g_current_drawdown = 0.0;   // Current drawdown percentage
double g_performance_multiplier = 1.0;  // Performance-based multiplier
double g_drawdown_multiplier = 1.0;     // Drawdown-based multiplier
```

## 📈 **DRAWDOWN-ADAPTIVE SIZING**

### **Funktionalitet:**
- Tracker peak equity og beregner current drawdown
- Starter position size reduktion når drawdown > threshold (default 5%)
- Maksimal reduktion ved 20% drawdown (configurerbar)

### **Beregning:**
```cpp
if(drawdown > InpDrawdownThreshold)
{
    double drawdown_factor = (drawdown - threshold) / (20.0 - threshold);
    drawdown_factor = MathMin(drawdown_factor, 1.0);
    multiplier = 1.0 - (drawdown_factor * (1.0 - InpMaxDrawdownReduction));
    multiplier = MathMax(multiplier, InpMaxDrawdownReduction);
}
```

### **Eksempel Scenarier:**
- **0% drawdown**: 1.0x multiplier (normal size)
- **5% drawdown**: 1.0x multiplier (threshold ikke nået)
- **10% drawdown**: ~0.83x multiplier (17% reduktion)
- **15% drawdown**: ~0.67x multiplier (33% reduktion)
- **20% drawdown**: 0.5x multiplier (50% reduktion - maksimum)

## 🎯 **PERFORMANCE-ADAPTIVE SIZING**

### **Funktionalitet:**
- Analyserer de sidste N trades (default 20)
- Beregner average P&L og win rate
- Justerer position størrelse baseret på performance score

### **Performance Score Beregning:**
```cpp
double performance_score = (avg_pnl > 0 ? 1.0 : 0.5) + (win_rate - 0.5);
```

### **Multiplier Konvertering:**
- **Excellent performance** (score > 1.0): Op til 1.3x multiplier
- **Poor performance** (score < 1.0): Ned til 0.7x multiplier
- **Neutral performance** (score = 1.0): 1.0x multiplier

### **Eksempel Scenarier:**
- **70% win rate, positive avg P&L**: ~1.2x multiplier
- **50% win rate, positive avg P&L**: 1.0x multiplier  
- **30% win rate, negative avg P&L**: ~0.8x multiplier
- **20% win rate, negative avg P&L**: 0.7x multiplier (minimum)

## 🔄 **KOMBINERET SIZING SYSTEM**

### **Total Multiplier Beregning:**
```cpp
double total_multiplier = seasonal_mult * volatility_mult * 
                         performance_mult * drawdown_mult;

// Safety limits
total_multiplier = MathMax(0.2, MathMin(3.0, total_multiplier));
```

### **Eksempel Kombinationer:**

#### **Optimale Forhold:**
- Seasonal: 1.2x (gode måneder)
- Volatility: 1.1x (lav volatilitet)
- Performance: 1.3x (excellent performance)
- Drawdown: 1.0x (ingen drawdown)
- **Total: 1.72x** (72% større positions)

#### **Udfordrende Forhold:**
- Seasonal: 0.8x (dårlige måneder)
- Volatility: 0.7x (høj volatilitet)
- Performance: 0.7x (poor performance)
- Drawdown: 0.6x (høj drawdown)
- **Total: 0.23x** (77% mindre positions)

## 📊 **TRACKING & MONITORING**

### **OnTrade Integration:**
- Automatisk tracking af alle completed trades
- Real-time opdatering af performance metrics
- Logging af adaptive adjustments

### **Statistics Display:**
```cpp
Print("Current drawdown: ", g_current_drawdown, "%");
Print("Performance multiplier: ", g_performance_multiplier);
Print("Drawdown multiplier: ", g_drawdown_multiplier);
Print("Combined risk multiplier: ", total_multiplier);
```

## 🎛️ **KONFIGURATION**

### **Konservativ Setup:**
```cpp
InpDrawdownThreshold = 3.0;           // Start reduktion ved 3% drawdown
InpMaxDrawdownReduction = 0.3;        // Maksimal 70% af normal size
InpPerformanceLookback = 30;          // Analysér 30 trades
InpMinPerformanceMultiplier = 0.8;    // Minimum 80% af normal size
InpMaxPerformanceMultiplier = 1.2;    // Maksimum 120% af normal size
```

### **Aggressiv Setup:**
```cpp
InpDrawdownThreshold = 7.0;           // Start reduktion ved 7% drawdown
InpMaxDrawdownReduction = 0.5;        // Maksimal 50% af normal size
InpPerformanceLookback = 15;          // Analysér 15 trades
InpMinPerformanceMultiplier = 0.6;    // Minimum 60% af normal size
InpMaxPerformanceMultiplier = 1.5;    // Maksimum 150% af normal size
```

## 🔍 **TESTING**

### **Test Script:**
Brug `Test_Adaptive_Sizing.mq5` til at teste:
- Drawdown scenarios
- Performance scenarios  
- Combined multiplier effects
- Seasonal integration

### **Backtest Anbefalinger:**
1. Test med forskellige drawdown thresholds
2. Analysér impact på Sharpe ratio
3. Verificér at max drawdown reduceres
4. Kontrollér at profitable perioder udnyttes bedre

## ⚠️ **SIKKERHEDSFORANSTALTNINGER**

### **Hard Limits:**
- Total multiplier: 0.2x - 3.0x (aldrig under 20% eller over 300%)
- Drawdown multiplier: Minimum 50% af normal size
- Performance multiplier: 0.7x - 1.3x range

### **Fail-safes:**
- Kræver minimum 5 trades for performance analysis
- Gradual adjustments (ikke pludselige spring)
- Integration med eksisterende risk management

## 📈 **FORVENTEDE RESULTATER**

### **Forbedringer:**
- **Reduceret maksimal drawdown** (15-25% reduktion)
- **Forbedret risk-adjusted returns** (højere Sharpe ratio)
- **Bedre capital preservation** under dårlige perioder
- **Øget profit** under gode perioder

### **Trade-offs:**
- Mindre positions under recovery perioder
- Potentielt lavere absolute returns i nogle perioder
- Øget kompleksitet i position sizing

## 🚀 **NÆSTE SKRIDT**

1. **Backtest** med adaptive sizing enabled
2. **Sammenlign** resultater med original EA
3. **Fine-tune** parametre baseret på resultater
4. **Monitor** real-time performance
5. **Overvej** yderligere forbedringer (f.eks. volatility-adjusted thresholds)
