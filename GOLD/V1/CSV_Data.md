🔴 Mangler at Implementere:
1. Global Per-Strategi Akkumulatorer ❌
Ingen central tracking af statistik på tværs af alle strategier
Mangler arrays til at akkumulere:  gross_profit,  gross_loss, net_pnl, max_dd, avg_RR, PF
2. Strategy Summary CSV ❌
Ingen strategy_summary.csv funktionalitet
Mangler WriteStrategySummary() funktion
Ingen implementation i OnDeinit()
3. Robust Exit Reason Detection ❌
Mangler detection af: TSL (Trailing Stop), TIME_STOP, DAILY_LOCK
Kun basis exit reasons implementeret
4. Partial Close Handling ❌
Ingen håndtering af partial closes
Mangler parent_ticket felt for del-lukninger
5. Daglig Summary Writing ❌
Ingen dagsskifte detection
Mangler automatisk strategy summary ved dag-end
📋 IMPLEMENTATIONSPLAN
Fase 1: Global Strategy Statistics System
Opret global strategy statistics arrays
Implementer UpdateStrategyStats() funktion
Kald fra OnTradeTransaction() ved exit
Fase 2: Strategy Summary CSV
Implementer WriteStrategySummary() funktion
Tilføj til OnDeinit()
Tilføj daglig summary trigger
Fase 3: Enhanced Exit Reason Detection
Udvid exit reason logic
Tilføj trailing stop detection
Tilføj time-based exit detection
Fase 4: Partial Close Support
Udvid TradeMeta med parent_ticket
Modificer exit handling for partials
Test med partial close scenarios
Fase 5: Daily Summary Automation
Implementer dagsskifte detection
Automatisk strategy summary ved dag-end
Reset daily counters