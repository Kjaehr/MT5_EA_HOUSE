# Daily Reset - Brugseksempel

## Scenario: EA rammer Daily Loss Cap og bliver automatisk frigivet næste dag

### Dag 1 - Tirsdag 16. Januar 2024

**Kl. 14:30** - EA starter handel
```
=== DAILY RESET @ 2024-01-16 00:00 (ServerDayStart 00:00) ===
Previous day loss: 0.00 | Trades: 0 | Consec losses: 0 | Was locked: NO
Reset values - Day loss: 0.00 | Trades: 0 | Consec losses: 0 | Locked: NO
```

**Kl. 15:45** - Første tab
```
Trade closed: Loss -75.50
Day loss: 75.50 | Trades today: 1 | Consecutive losses: 1
```

**Kl. 16:20** - Andet tab
```
Trade closed: Loss -85.25
Day loss: 160.75 | Trades today: 2 | Consecutive losses: 2
```

**Kl. 17:10** - Daily Loss Cap ramt (2% af balance = 200.00)
```
*** TRADING LOCKED *** Reason: Daily loss cap reached (201.25/200.00)
```

**Resten af dagen** - Ingen nye handler tilladt
```
REJECT: Daily loss cap reached (Total today: 15)
```

### Dag 2 - Onsdag 17. Januar 2024

**Kl. 00:00** - Automatisk daglig reset
```
=== DAILY RESET @ 2024-01-17 00:00 (ServerDayStart 00:00) ===
Previous day loss: 201.25 | Trades: 2 | Consec losses: 2 | Was locked: YES
Reset values - Day loss: 0.00 | Trades: 0 | Consec losses: 0 | Locked: NO
```

**Kl. 08:30** - Handel genoptaget
```
Strategy activated: S_ORB
=== FIRST ENTRY TODAY ===
Strategy: S_ORB
Session: SES_LONDON
```

## Scenario: Weekly Reset på Mandag

### Mandag 22. Januar 2024

**Kl. 00:00** - Både daglig og ugentlig reset
```
=== WEEKLY RESET @ 2024-01-22 00:00 (ServerDayStart 00:00) ===
Previous week loss: 450.75 | Was locked: NO

=== DAILY RESET @ 2024-01-22 00:00 (ServerDayStart 00:00) ===
Previous day loss: 125.50 | Trades: 3 | Consec losses: 1 | Was locked: NO
Reset values - Day loss: 0.00 | Trades: 0 | Consec losses: 0 | Locked: NO
```

## Scenario: DST Transition

### Sommer (DST aktiv)
```
=== SESSION/DST SANITY LOG ===
Server Time: 2024-06-15 22:00
CET Time: 2024-06-16 00:00 (00:00)
Effective Offset: 3 (GMT+2 + DST:1)
DST Active: YES

=== DAILY RESET @ 2024-06-16 00:00 (ServerDayStart 00:00) ===
```

### Vinter (DST inaktiv)
```
=== SESSION/DST SANITY LOG ===
Server Time: 2024-12-15 23:00
CET Time: 2024-12-16 00:00 (00:00)
Effective Offset: 2 (GMT+2 + DST:0)
DST Active: NO

=== DAILY RESET @ 2024-12-16 00:00 (ServerDayStart 00:00) ===
```

## Input Parameter Eksempler

### Standard (Midnat reset)
```cpp
input int Inp_ServerDayStart = 0;  // Reset kl. 00:00 server tid
```

### Forex Market Open (Sydney)
```cpp
input int Inp_ServerDayStart = 22;  // Reset kl. 22:00 server tid (Sydney open)
```

### Custom Business Day
```cpp
input int Inp_ServerDayStart = 6;   // Reset kl. 06:00 server tid
```

## Monitoring og Debugging

### Tjek nuværende status
```cpp
Print("Day loss: ", g_risk_manager.GetDayLoss());
Print("Trades today: ", g_risk_manager.GetTradesToday());
Print("Locked day: ", g_risk_manager.IsLockedDay() ? "YES" : "NO");
Print("Consecutive losses: ", g_risk_manager.GetConsecLosses());
```

### Verbose logging
Sæt `Inp_LogVerbose = true` for detaljeret logging af:
- Reset-operationer
- Lock/unlock events
- Daglige statistikker
- DST-ændringer
