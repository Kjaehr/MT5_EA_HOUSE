//+------------------------------------------------------------------+
//|                                            SignalStructures.mqh |
//|                           Common Signal Structures              |
//+------------------------------------------------------------------+
#property copyright "DAX Scalper EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Admiral Signal Structure                                        |
//+------------------------------------------------------------------+
struct SAdmiralSignal
{
    bool              is_valid;
    bool              is_long;
    double            entry_price;
    double            stop_loss;
    double            take_profit;
    double            signal_strength;
    string            signal_description;

    // Default constructor
    SAdmiralSignal()
    {
        is_valid = false;
        is_long = false;
        entry_price = 0.0;
        stop_loss = 0.0;
        take_profit = 0.0;
        signal_strength = 0.0;
        signal_description = "";
    }

    // Copy constructor
    SAdmiralSignal(const SAdmiralSignal &other)
    {
        is_valid = other.is_valid;
        is_long = other.is_long;
        entry_price = other.entry_price;
        stop_loss = other.stop_loss;
        take_profit = other.take_profit;
        signal_strength = other.signal_strength;
        signal_description = other.signal_description;
    }

    // Assignment operator
    void operator=(const SAdmiralSignal &other)
    {
        is_valid = other.is_valid;
        is_long = other.is_long;
        entry_price = other.entry_price;
        stop_loss = other.stop_loss;
        take_profit = other.take_profit;
        signal_strength = other.signal_strength;
        signal_description = other.signal_description;
    }
};
