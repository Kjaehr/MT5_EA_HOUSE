//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"

#include <Trade/Trade.mqh>
#include "Logger.mqh"
#include "ConfigManager.mqh"

//--- Custom error codes
#define ERR_INVALID_TRADE_PARAMETERS 4000

//--- Trade result structure
struct STradeResult
{
    bool              success;            // Trade execution success
    int               error_code;         // Error code if failed
    ulong             ticket;             // Order/Position ticket
    double            executed_price;     // Actual execution price
    double            executed_volume;    // Actual executed volume
    string            comment;            // Trade comment
};

//--- Position info structure
struct SPositionInfo
{
    bool              exists;             // Position exists
    ulong             ticket;             // Position ticket
    ENUM_POSITION_TYPE type;             // Position type (buy/sell)
    double            volume;             // Position volume
    double            open_price;         // Open price
    double            current_price;      // Current price
    double            stop_loss;          // Stop loss
    double            take_profit;        // Take profit
    double            profit;             // Current profit
    double            profit_points;      // Profit in points
    string            comment;            // Position comment
    datetime          open_time;          // Open time

    // Copy constructor to resolve deprecation warning
    SPositionInfo(const SPositionInfo& other)
    {
        exists = other.exists;
        ticket = other.ticket;
        type = other.type;
        volume = other.volume;
        open_price = other.open_price;
        current_price = other.current_price;
        stop_loss = other.stop_loss;
        take_profit = other.take_profit;
        profit = other.profit;
        profit_points = other.profit_points;
        comment = other.comment;
        open_time = other.open_time;
    }

    // Default constructor
    SPositionInfo()
    {
        exists = false;
        ticket = 0;
        type = POSITION_TYPE_BUY;
        volume = 0.0;
        open_price = 0.0;
        current_price = 0.0;
        stop_loss = 0.0;
        take_profit = 0.0;
        profit = 0.0;
        profit_points = 0.0;
        comment = "";
        open_time = 0;
    }
};

//+------------------------------------------------------------------+
//| Trade Manager class for handling all trading operations         |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
    CTrade            m_trade;            // Trade object
    CLogger*          m_logger;           // Logger reference
    CConfigManager*   m_config;           // Configuration reference
    string            m_symbol;           // Trading symbol
    int               m_magic_number;     // Magic number

    //--- Internal methods
    double            CalculateLotSize(double entry_price, double stop_loss);
    double            ValidateLotSize(double lots);
    bool              ValidateTradeRequest(double price, double sl, double tp, double volume);
    double            GetCurrentPrice(ENUM_ORDER_TYPE order_type);
    void              LogTradeAttempt(ENUM_ORDER_TYPE order_type, double volume, double price, double sl, double tp, string comment);

public:
    //--- Constructor/Destructor
                      CTradeManager(string symbol, int magic_number, CLogger* logger = NULL, CConfigManager* config = NULL);
                     ~CTradeManager();

    //--- Configuration methods
    void              SetLogger(CLogger* logger) { m_logger = logger; }
    void              SetConfig(CConfigManager* config) { m_config = config; }
    void              SetMagicNumber(int magic_number);

    //--- Position management
    bool              HasActivePosition();
    SPositionInfo     GetPositionInfo();
    bool              ClosePosition(string reason = "Manual close");
    bool              ClosePartialPosition(double volume, string reason = "Partial close");
    bool              ModifyPosition(double new_sl, double new_tp, string reason = "Modify");

    //--- Order execution methods
    STradeResult      OpenLongPosition(double volume, double price, double sl, double tp, string comment = "");
    STradeResult      OpenShortPosition(double volume, double price, double sl, double tp, string comment = "");
    STradeResult      OpenLongMarket(double volume, double sl, double tp, string comment = "");
    STradeResult      OpenShortMarket(double volume, double sl, double tp, string comment = "");

    //--- Risk-based position sizing
    STradeResult      OpenLongWithRisk(double risk_amount, double entry_price, double sl, double tp, string comment = "");
    STradeResult      OpenShortWithRisk(double risk_amount, double entry_price, double sl, double tp, string comment = "");

    //--- Position monitoring and management
    bool              TrailStopLoss(double trail_distance_points);
    bool              BreakEven(double breakeven_points, double lock_profit_points = 0);
    bool              TimeBasedExit(int max_minutes);

    //--- Utility methods
    double            GetSpreadPoints();
    double            PointsToPrice(double points);
    double            PriceToPoints(double price_diff);
    bool              IsMarketOpen();
    string            GetLastErrorDescription();

    //--- Statistics methods
    int               GetTotalPositions();
    double            GetTotalProfit();
    double            GetTotalVolume();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager(string symbol, int magic_number, CLogger* logger = NULL, CConfigManager* config = NULL)
{
    m_symbol = symbol;
    m_magic_number = magic_number;
    m_logger = logger;
    m_config = config;

    m_trade.SetExpertMagicNumber(m_magic_number);
    m_trade.SetMarginMode();
    m_trade.SetTypeFillingBySymbol(m_symbol);

    if(m_logger != NULL)
    {
        m_logger->Info("TradeManager initialized for " + m_symbol + " with magic " + IntegerToString(m_magic_number));
    }
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
{
    if(m_logger != NULL)
    {
        m_logger->Info("TradeManager destroyed");
    }
}

//+------------------------------------------------------------------+
//| Set magic number                                                 |
//+------------------------------------------------------------------+
void CTradeManager::SetMagicNumber(int magic_number)
{
    m_magic_number = magic_number;
    m_trade.SetExpertMagicNumber(m_magic_number);

    if(m_logger != NULL)
    {
        m_logger->Info("Magic number updated to " + IntegerToString(m_magic_number));
    }
}

//+------------------------------------------------------------------+
//| Check if active position exists                                  |
//+------------------------------------------------------------------+
bool CTradeManager::HasActivePosition()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == m_symbol &&
           PositionGetInteger(POSITION_MAGIC) == m_magic_number)
        {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Get detailed position information                                |
//+------------------------------------------------------------------+
SPositionInfo CTradeManager::GetPositionInfo()
{
    SPositionInfo pos_info;
    pos_info.exists = false;

    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == m_symbol &&
           PositionGetInteger(POSITION_MAGIC) == m_magic_number)
        {
            pos_info.exists = true;
            pos_info.ticket = PositionGetInteger(POSITION_TICKET);
            pos_info.type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            pos_info.volume = PositionGetDouble(POSITION_VOLUME);
            pos_info.open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            pos_info.stop_loss = PositionGetDouble(POSITION_SL);
            pos_info.take_profit = PositionGetDouble(POSITION_TP);
            pos_info.profit = PositionGetDouble(POSITION_PROFIT);
            pos_info.comment = PositionGetString(POSITION_COMMENT);
            pos_info.open_time = (datetime)PositionGetInteger(POSITION_TIME);

            // Calculate current price and profit in points
            if(pos_info.type == POSITION_TYPE_BUY)
            {
                pos_info.current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
                pos_info.profit_points = PriceToPoints(pos_info.current_price - pos_info.open_price);
            }
            else
            {
                pos_info.current_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
                pos_info.profit_points = PriceToPoints(pos_info.open_price - pos_info.current_price);
            }

            break;
        }
    }

    return pos_info;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double CTradeManager::CalculateLotSize(double entry_price, double stop_loss)
{
    if(m_config == NULL) return 0.1; // Default if no config

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double risk_amount = equity * m_config->GetRiskPerTrade();

    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);

    double sl_distance = MathAbs(entry_price - stop_loss);
    double sl_points = sl_distance / point;

    // Calculate lot size based on risk
    double lot_size = risk_amount / (sl_points * tick_value / tick_size);

    return ValidateLotSize(lot_size);
}

//+------------------------------------------------------------------+
//| Validate and normalize lot size                                  |
//+------------------------------------------------------------------+
double CTradeManager::ValidateLotSize(double lots)
{
    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

    //--- Normalize to lot step
    lots = MathRound(lots / lot_step) * lot_step;

    //--- Check limits
    if(lots < min_lot) lots = min_lot;
    if(lots > max_lot) lots = max_lot;

    return lots;
}

//+------------------------------------------------------------------+
//| Open long position at market                                     |
//+------------------------------------------------------------------+
STradeResult CTradeManager::OpenLongMarket(double volume, double sl, double tp, string comment = "")
{
    STradeResult result;
    result.success = false;
    result.error_code = 0;
    result.ticket = 0;

    double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);

    if(!ValidateTradeRequest(ask, sl, tp, volume))
    {
        result.error_code = ERR_INVALID_TRADE_PARAMETERS;
        if(m_logger != NULL)
            m_logger->Error("Invalid trade parameters for long market order");
        return result;
    }

    LogTradeAttempt(ORDER_TYPE_BUY, volume, ask, sl, tp, comment);

    if(m_trade.Buy(volume, m_symbol, ask, sl, tp, comment))
    {
        result.success = true;
        result.ticket = m_trade.ResultOrder();
        result.executed_price = m_trade.ResultPrice();
        result.executed_volume = m_trade.ResultVolume();
        result.comment = comment;

        if(m_logger != NULL)
        {
            m_logger->LogTrade("BUY MARKET", m_symbol, volume, result.executed_price, sl, tp, comment);
            m_logger->LogTradeResult(true, 0, "Ticket: " + IntegerToString(result.ticket));
        }
    }
    else
    {
        result.error_code = GetLastError();
        if(m_logger != NULL)
        {
            m_logger->LogTradeResult(false, result.error_code, "Failed to open long position");
        }
    }

    return result;
}

//+------------------------------------------------------------------+
//| Open short position at market                                    |
//+------------------------------------------------------------------+
STradeResult CTradeManager::OpenShortMarket(double volume, double sl, double tp, string comment = "")
{
    STradeResult result;
    result.success = false;
    result.error_code = 0;
    result.ticket = 0;

    double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);

    if(!ValidateTradeRequest(bid, sl, tp, volume))
    {
        result.error_code = ERR_INVALID_TRADE_PARAMETERS;
        if(m_logger != NULL)
            m_logger->Error("Invalid trade parameters for short market order");
        return result;
    }

    LogTradeAttempt(ORDER_TYPE_SELL, volume, bid, sl, tp, comment);

    if(m_trade.Sell(volume, m_symbol, bid, sl, tp, comment))
    {
        result.success = true;
        result.ticket = m_trade.ResultOrder();
        result.executed_price = m_trade.ResultPrice();
        result.executed_volume = m_trade.ResultVolume();
        result.comment = comment;

        if(m_logger != NULL)
        {
            m_logger->LogTrade("SELL MARKET", m_symbol, volume, result.executed_price, sl, tp, comment);
            m_logger->LogTradeResult(true, 0, "Ticket: " + IntegerToString(result.ticket));
        }
    }
    else
    {
        result.error_code = GetLastError();
        if(m_logger != NULL)
        {
            m_logger->LogTradeResult(false, result.error_code, "Failed to open short position");
        }
    }

    return result;
}

//+------------------------------------------------------------------+
//| Validate trade request parameters                                |
//+------------------------------------------------------------------+
bool CTradeManager::ValidateTradeRequest(double price, double sl, double tp, double volume)
{
    if(volume <= 0) return false;
    if(price <= 0) return false;

    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);

    if(volume < min_lot || volume > max_lot) return false;

    // Additional validations can be added here
    return true;
}

//+------------------------------------------------------------------+
//| Log trade attempt                                                |
//+------------------------------------------------------------------+
void CTradeManager::LogTradeAttempt(ENUM_ORDER_TYPE order_type, double volume, double price, double sl, double tp, string comment)
{
    if(m_logger == NULL) return;

    string order_type_str = (order_type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
    string message = StringFormat("Attempting %s: %.2f lots @ %.5f SL:%.5f TP:%.5f [%s]",
                                 order_type_str, volume, price, sl, tp, comment);
    m_logger->Debug(message);
}

//+------------------------------------------------------------------+
//| Convert points to price difference                               |
//+------------------------------------------------------------------+
double CTradeManager::PointsToPrice(double points)
{
    return points * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Convert price difference to points                               |
//+------------------------------------------------------------------+
double CTradeManager::PriceToPoints(double price_diff)
{
    return price_diff / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Get current spread in points                                     |
//+------------------------------------------------------------------+
double CTradeManager::GetSpreadPoints()
{
    double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    return PriceToPoints(ask - bid);
}

//+------------------------------------------------------------------+
//| Get current price for order type                                 |
//+------------------------------------------------------------------+
double CTradeManager::GetCurrentPrice(ENUM_ORDER_TYPE order_type)
{
    if(order_type == ORDER_TYPE_BUY)
        return SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    else
        return SymbolInfoDouble(m_symbol, SYMBOL_BID);
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool CTradeManager::ClosePosition(string reason = "Manual close")
{
    SPositionInfo pos_info = GetPositionInfo();
    if(!pos_info.exists) return false;

    bool result = m_trade.PositionClose(pos_info.ticket);

    if(m_logger != NULL)
    {
        if(result)
            m_logger->Info("Position closed: " + reason);
        else
            m_logger->Error("Failed to close position: " + reason);
    }

    return result;
}

//+------------------------------------------------------------------+
//| Close partial position                                           |
//+------------------------------------------------------------------+
bool CTradeManager::ClosePartialPosition(double volume, string reason = "Partial close")
{
    SPositionInfo pos_info = GetPositionInfo();
    if(!pos_info.exists) return false;

    if(volume >= pos_info.volume)
        return ClosePosition(reason);

    bool result = m_trade.PositionClosePartial(pos_info.ticket, volume);

    if(m_logger != NULL)
    {
        if(result)
            m_logger->Info(StringFormat("Partial position closed: %.2f lots - %s", volume, reason));
        else
            m_logger->Error("Failed to close partial position: " + reason);
    }

    return result;
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
bool CTradeManager::ModifyPosition(double new_sl, double new_tp, string reason = "Modify")
{
    SPositionInfo pos_info = GetPositionInfo();
    if(!pos_info.exists) return false;

    bool result = m_trade.PositionModify(pos_info.ticket, new_sl, new_tp);

    if(m_logger != NULL)
    {
        if(result)
            m_logger->Info(StringFormat("Position modified SL:%.5f TP:%.5f - %s", new_sl, new_tp, reason));
        else
            m_logger->Error("Failed to modify position: " + reason);
    }

    return result;
}

//+------------------------------------------------------------------+
//| Open long position with limit/stop order                        |
//+------------------------------------------------------------------+
STradeResult CTradeManager::OpenLongPosition(double volume, double price, double sl, double tp, string comment = "")
{
    STradeResult result;
    result.success = false;
    result.error_code = 0;
    result.ticket = 0;

    double current_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    ENUM_ORDER_TYPE order_type = (price > current_price) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_BUY_LIMIT;

    if(!ValidateTradeRequest(price, sl, tp, volume))
    {
        result.error_code = ERR_INVALID_TRADE_PARAMETERS;
        if(m_logger != NULL)
            m_logger->Error("Invalid trade parameters for long position");
        return result;
    }

    LogTradeAttempt(order_type, volume, price, sl, tp, comment);

    bool trade_result = false;
    if(order_type == ORDER_TYPE_BUY_STOP)
        trade_result = m_trade.BuyStop(volume, price, m_symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
    else
        trade_result = m_trade.BuyLimit(volume, price, m_symbol, sl, tp, ORDER_TIME_GTC, 0, comment);

    if(trade_result)
    {
        result.success = true;
        result.ticket = m_trade.ResultOrder();
        result.executed_price = price;
        result.executed_volume = volume;
        result.comment = comment;

        if(m_logger != NULL)
        {
            string order_type_str = (order_type == ORDER_TYPE_BUY_STOP) ? "BUY STOP" : "BUY LIMIT";
            m_logger->LogTrade(order_type_str, m_symbol, volume, price, sl, tp, comment);
            m_logger->LogTradeResult(true, 0, "Ticket: " + IntegerToString(result.ticket));
        }
    }
    else
    {
        result.error_code = GetLastError();
        if(m_logger != NULL)
        {
            m_logger->LogTradeResult(false, result.error_code, "Failed to place long order");
        }
    }

    return result;
}

//+------------------------------------------------------------------+
//| Open short position with limit/stop order                       |
//+------------------------------------------------------------------+
STradeResult CTradeManager::OpenShortPosition(double volume, double price, double sl, double tp, string comment = "")
{
    STradeResult result;
    result.success = false;
    result.error_code = 0;
    result.ticket = 0;

    double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    ENUM_ORDER_TYPE order_type = (price < current_price) ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_SELL_LIMIT;

    if(!ValidateTradeRequest(price, sl, tp, volume))
    {
        result.error_code = ERR_INVALID_TRADE_PARAMETERS;
        if(m_logger != NULL)
            m_logger->Error("Invalid trade parameters for short position");
        return result;
    }

    LogTradeAttempt(order_type, volume, price, sl, tp, comment);

    bool trade_result = false;
    if(order_type == ORDER_TYPE_SELL_STOP)
        trade_result = m_trade.SellStop(volume, price, m_symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
    else
        trade_result = m_trade.SellLimit(volume, price, m_symbol, sl, tp, ORDER_TIME_GTC, 0, comment);

    if(trade_result)
    {
        result.success = true;
        result.ticket = m_trade.ResultOrder();
        result.executed_price = price;
        result.executed_volume = volume;
        result.comment = comment;

        if(m_logger != NULL)
        {
            string order_type_str = (order_type == ORDER_TYPE_SELL_STOP) ? "SELL STOP" : "SELL LIMIT";
            m_logger->LogTrade(order_type_str, m_symbol, volume, price, sl, tp, comment);
            m_logger->LogTradeResult(true, 0, "Ticket: " + IntegerToString(result.ticket));
        }
    }
    else
    {
        result.error_code = GetLastError();
        if(m_logger != NULL)
        {
            m_logger->LogTradeResult(false, result.error_code, "Failed to place short order");
        }
    }

    return result;
}

//+------------------------------------------------------------------+
//| Open long position with risk-based sizing                       |
//+------------------------------------------------------------------+
STradeResult CTradeManager::OpenLongWithRisk(double risk_amount, double entry_price, double sl, double tp, string comment = "")
{
    double calculated_volume = CalculateLotSize(entry_price, sl);
    return OpenLongPosition(calculated_volume, entry_price, sl, tp, comment);
}

//+------------------------------------------------------------------+
//| Open short position with risk-based sizing                      |
//+------------------------------------------------------------------+
STradeResult CTradeManager::OpenShortWithRisk(double risk_amount, double entry_price, double sl, double tp, string comment = "")
{
    double calculated_volume = CalculateLotSize(entry_price, sl);
    return OpenShortPosition(calculated_volume, entry_price, sl, tp, comment);
}

//+------------------------------------------------------------------+
//| Trail stop loss                                                  |
//+------------------------------------------------------------------+
bool CTradeManager::TrailStopLoss(double trail_distance_points)
{
    SPositionInfo pos_info = GetPositionInfo();
    if(!pos_info.exists) return false;

    double trail_distance = PointsToPrice(trail_distance_points);
    double new_sl = 0;

    if(pos_info.type == POSITION_TYPE_BUY)
    {
        new_sl = pos_info.current_price - trail_distance;
        if(pos_info.stop_loss == 0 || new_sl > pos_info.stop_loss)
        {
            return ModifyPosition(new_sl, pos_info.take_profit, "Trail SL");
        }
    }
    else
    {
        new_sl = pos_info.current_price + trail_distance;
        if(pos_info.stop_loss == 0 || new_sl < pos_info.stop_loss)
        {
            return ModifyPosition(new_sl, pos_info.take_profit, "Trail SL");
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Move to break even                                               |
//+------------------------------------------------------------------+
bool CTradeManager::BreakEven(double breakeven_points, double lock_profit_points = 0)
{
    SPositionInfo pos_info = GetPositionInfo();
    if(!pos_info.exists) return false;

    double breakeven_distance = PointsToPrice(breakeven_points);
    double lock_profit_distance = PointsToPrice(lock_profit_points);

    if(pos_info.type == POSITION_TYPE_BUY)
    {
        if(pos_info.current_price >= pos_info.open_price + breakeven_distance)
        {
            double new_sl = pos_info.open_price + lock_profit_distance;
            if(pos_info.stop_loss < new_sl)
            {
                return ModifyPosition(new_sl, pos_info.take_profit, "Break Even");
            }
        }
    }
    else
    {
        if(pos_info.current_price <= pos_info.open_price - breakeven_distance)
        {
            double new_sl = pos_info.open_price - lock_profit_distance;
            if(pos_info.stop_loss > new_sl || pos_info.stop_loss == 0)
            {
                return ModifyPosition(new_sl, pos_info.take_profit, "Break Even");
            }
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Time-based exit                                                  |
//+------------------------------------------------------------------+
bool CTradeManager::TimeBasedExit(int max_minutes)
{
    SPositionInfo pos_info = GetPositionInfo();
    if(!pos_info.exists) return false;

    datetime current_time = TimeCurrent();
    int minutes_open = (int)((current_time - pos_info.open_time) / 60);

    if(minutes_open >= max_minutes)
    {
        return ClosePosition("Time-based exit");
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check if market is open                                          |
//+------------------------------------------------------------------+
bool CTradeManager::IsMarketOpen()
{
    return SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL;
}

//+------------------------------------------------------------------+
//| Get last error description                                       |
//+------------------------------------------------------------------+
string CTradeManager::GetLastErrorDescription()
{
    int error_code = GetLastError();
    string error_desc = "";

    // Common MQL5 error descriptions
    switch(error_code)
    {
        case 0: error_desc = "No error"; break;
        case 4756: error_desc = "Invalid trade request"; break;
        case 4757: error_desc = "Request rejected"; break;
        case 4758: error_desc = "Request canceled by trader"; break;
        case 4759: error_desc = "Order placed"; break;
        case 4760: error_desc = "Request completed"; break;
        case 4761: error_desc = "Request processing error"; break;
        case 4762: error_desc = "Request canceled by timeout"; break;
        case 4763: error_desc = "Invalid request"; break;
        case 4764: error_desc = "Invalid volume in the request"; break;
        case 4765: error_desc = "Invalid price in the request"; break;
        case 4766: error_desc = "Invalid stops in the request"; break;
        case 4767: error_desc = "Trade is disabled"; break;
        case 4768: error_desc = "Market is closed"; break;
        case 4769: error_desc = "There is not enough money to complete the request"; break;
        case 4770: error_desc = "Prices changed"; break;
        case 4771: error_desc = "There are no quotes to process the request"; break;
        case 4772: error_desc = "Invalid order expiration date in the request"; break;
        case 4773: error_desc = "Order state changed"; break;
        case 4774: error_desc = "Too frequent requests"; break;
        case 4775: error_desc = "No changes in request"; break;
        case 4776: error_desc = "Autotrading disabled by server"; break;
        case 4777: error_desc = "Autotrading disabled by client terminal"; break;
        case 4778: error_desc = "Request locked for processing"; break;
        case 4779: error_desc = "Order or position frozen"; break;
        case 4780: error_desc = "Invalid order filling type"; break;
        case 4781: error_desc = "No connection with the trade server"; break;
        case 4782: error_desc = "Operation is allowed only for live accounts"; break;
        case 4783: error_desc = "The number of pending orders has reached the limit"; break;
        case 4784: error_desc = "The volume of orders and positions for the symbol has reached the limit"; break;
        case 4785: error_desc = "Incorrect or prohibited order type"; break;
        case 4786: error_desc = "Position with the specified POSITION_IDENTIFIER has already been closed"; break;
        default: error_desc = "Unknown error"; break;
    }

    return "Error " + IntegerToString(error_code) + ": " + error_desc;
}

//+------------------------------------------------------------------+
//| Get total positions count                                        |
//+------------------------------------------------------------------+
int CTradeManager::GetTotalPositions()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == m_symbol &&
           PositionGetInteger(POSITION_MAGIC) == m_magic_number)
        {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Get total profit from all positions                             |
//+------------------------------------------------------------------+
double CTradeManager::GetTotalProfit()
{
    double total_profit = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == m_symbol &&
           PositionGetInteger(POSITION_MAGIC) == m_magic_number)
        {
            total_profit += PositionGetDouble(POSITION_PROFIT);
        }
    }
    return total_profit;
}

//+------------------------------------------------------------------+
//| Get total volume from all positions                             |
//+------------------------------------------------------------------+
double CTradeManager::GetTotalVolume()
{
    double total_volume = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == m_symbol &&
           PositionGetInteger(POSITION_MAGIC) == m_magic_number)
        {
            total_volume += PositionGetDouble(POSITION_VOLUME);
        }
    }
    return total_volume;
}