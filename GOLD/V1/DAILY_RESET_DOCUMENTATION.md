# Daily Reset Functionality - Implementation Documentation

## Overview
Implementeret daglig reset af risikostyring, så "Daily Loss Cap" kun låser handel resten af den aktuelle dag og automatisk frigives ved næste dagsskifte baseret på `Inp_ServerDayStart`.

## Nye Features

### 1. Daggrænse baseret på ServerDayStart
- **Input**: `Inp_ServerDayStart` (timer 0-23) definerer hvornår "dagen starter"
- **Logik**: Bruger samme DST/offset beregning som "SESSION/DST SANITY LOG"
- **Dagsskifte**: Første tick hvor `now >= dagens_start` og `DateOf(now) != g_lastResetDate`

### 2. Automatisk Daily Reset
Ved registreret dagsskifte nulstilles følgende i `DoDailyReset()`:
- `g_dayLocked = false` (frigiver daglig lock)
- `g_dayLossAmt = 0` (nulstiller dagstab)
- `g_trades_today = 0` (nulstiller dagstællere)
- `g_consec_losses = 0` (nulstiller konsekutive tab)
- `g_lastResetDate = DateOf(nu_dagens_start)` (opdaterer reset-dato)

### 3. Weekly Reset (bonus feature)
- Hvis dagsskifte sker på mandag (ISO uge-start), nulstilles også:
  - `g_weekLossPct = 0`
  - `g_locked_week = false`

### 4. Robuste Logs
```
=== DAILY RESET @ 2024-01-16 00:00 (ServerDayStart 00:00) ===
Previous day loss: 150.25 | Trades: 8 | Consec losses: 2 | Was locked: YES
Reset values - Day loss: 0.00 | Trades: 0 | Consec losses: 0 | Locked: NO
```

## Teknisk Implementation

### Nye Variabler i RiskLimits struct:
```cpp
struct RiskLimits {
    // Eksisterende...
    int trades_today;           // Antal handler i dag
    datetime last_reset_date;   // Dato for seneste reset
};
```

### Nye Metoder i RiskManager:
```cpp
bool IsDayBoundaryReached()  // Checker om vi har nået dagsskifte
void DoDailyReset()          // Udfører den faktiske reset
int GetTradesToday()         // Getter for dagens handler
bool IsLockedDay()           // Checker daglig lock status
bool IsLockedWeek()          // Checker ugentlig lock status
```

### Integration Points:
1. **OnInit()**: Kalder `DoDailyReset()` for korrekt initialisering
2. **OnTick()**: Kalder `UpdateLimits()` som checker for dagsskifte
3. **RegisterOutcome()**: Opdaterer `trades_today` counter

## DST og Timezone Handling
Bruger samme logik som SessionCalendar:
```cpp
int effective_offset = Inp_BrokerGMT_Offset + (g_session_calendar.dst_active ? 1 : 0);
```

## Test Scenarios

### Scenario 1: Daily Loss Cap Hit
1. **Dag 1**: EA rammer Daily Loss Cap → `g_dayLocked = true`
2. **Dag 2 ved ServerDayStart**: Automatisk reset → `g_dayLocked = false`
3. **Resultat**: Nye handler tilladt igen

### Scenario 2: Backtest over flere måneder
- Ingen permanente locks
- Daglige resets fungerer konsistent
- Weekly resets hver mandag

### Scenario 3: DST Transition
- Reset-tidspunkt justeres automatisk for DST
- Konsistent med session-tider
- Logs viser korrekte tidspunkter

## Acceptkriterier ✅

- [x] Daily Loss Cap låser kun for resten af dagen
- [x] Automatisk frigivelse ved næste dagsskifte
- [x] Korrekt DST/timezone håndtering
- [x] Konsistent med SESSION/DST SANITY LOG
- [x] Robuste logs med reset-information
- [x] Ingen side-effekter på åbne positioner
- [x] CSV/fil-håndtering fortsætter uændret
- [x] Initialisering i OnInit() forhindrer forkert lock-tilstand
- [x] Maks 1 reset pr. dag (guard mod multiple triggers)

## Brug
Ingen ændringer i input-parametre nødvendige. Eksisterende `Inp_ServerDayStart` bruges nu til daglig reset-timing i stedet for kun session-logik.
