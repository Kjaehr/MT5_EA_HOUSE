//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                  Copyright 2025, Your Company   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://www.mql5.com"

//--- Log levels
enum ENUM_LOG_LEVEL
{
    LOG_LEVEL_DEBUG = 0,    // Debug messages
    LOG_LEVEL_INFO = 1,     // Information messages
    LOG_LEVEL_WARNING = 2,  // Warning messages
    LOG_LEVEL_ERROR = 3,    // Error messages
    LOG_LEVEL_CRITICAL = 4  // Critical errors
};

//+------------------------------------------------------------------+
//| Logger class for structured logging                             |
//+------------------------------------------------------------------+
class CLogger
{
private:
    ENUM_LOG_LEVEL    m_log_level;        // Current log level
    bool              m_file_logging;     // Enable file logging
    bool              m_console_logging;  // Enable console logging
    string            m_log_file;         // Log file name
    int               m_file_handle;      // File handle
    string            m_prefix;           // Log prefix (EA name)

    //--- Internal methods
    string            GetLogLevelString(ENUM_LOG_LEVEL level);
    string            GetTimestamp();
    bool              ShouldLog(ENUM_LOG_LEVEL level);
    void              WriteToFile(string message);
    void              WriteToConsole(string message);

public:
    //--- Constructor/Destructor
                      CLogger(string prefix = "EA", ENUM_LOG_LEVEL level = LOG_LEVEL_INFO);
                     ~CLogger();

    //--- Configuration methods
    void              SetLogLevel(ENUM_LOG_LEVEL level) { m_log_level = level; }
    void              EnableFileLogging(string filename = "");
    void              DisableFileLogging();
    void              EnableConsoleLogging() { m_console_logging = true; }
    void              DisableConsoleLogging() { m_console_logging = false; }

    //--- Logging methods
    void              Debug(string message);
    void              Info(string message);
    void              Warning(string message);
    void              Error(string message);
    void              Critical(string message);

    //--- Trade logging methods
    void              LogTrade(string action, string symbol, double volume, double price, double sl, double tp, string comment = "");
    void              LogTradeResult(bool success, int error_code, string details = "");
    void              LogPerformance(string metric, double value);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLogger::CLogger(string prefix = "EA", ENUM_LOG_LEVEL level = LOG_LEVEL_INFO)
{
    m_prefix = prefix;
    m_log_level = level;
    m_file_logging = false;
    m_console_logging = true;
    m_file_handle = INVALID_HANDLE;
    m_log_file = "";
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLogger::~CLogger()
{
    if(m_file_handle != INVALID_HANDLE)
    {
        FileClose(m_file_handle);
        m_file_handle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Get log level as string                                          |
//+------------------------------------------------------------------+
string CLogger::GetLogLevelString(ENUM_LOG_LEVEL level)
{
    switch(level)
    {
        case LOG_LEVEL_DEBUG:    return "DEBUG";
        case LOG_LEVEL_INFO:     return "INFO";
        case LOG_LEVEL_WARNING:  return "WARN";
        case LOG_LEVEL_ERROR:    return "ERROR";
        case LOG_LEVEL_CRITICAL: return "CRITICAL";
        default:                 return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Get formatted timestamp                                          |
//+------------------------------------------------------------------+
string CLogger::GetTimestamp()
{
    MqlDateTime dt;
    TimeCurrent(dt);
    return StringFormat("%04d.%02d.%02d %02d:%02d:%02d",
                       dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
}

//+------------------------------------------------------------------+
//| Check if message should be logged                                |
//+------------------------------------------------------------------+
bool CLogger::ShouldLog(ENUM_LOG_LEVEL level)
{
    return level >= m_log_level;
}

//+------------------------------------------------------------------+
//| Enable file logging                                              |
//+------------------------------------------------------------------+
void CLogger::EnableFileLogging(string filename = "")
{
    if(filename == "")
    {
        MqlDateTime dt;
        TimeCurrent(dt);
        filename = StringFormat("%s_%04d%02d%02d.log", m_prefix, dt.year, dt.mon, dt.day);
    }

    m_log_file = filename;
    m_file_logging = true;

    // Test file access
    m_file_handle = FileOpen(m_log_file, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(m_file_handle != INVALID_HANDLE)
    {
        FileClose(m_file_handle);
        m_file_handle = INVALID_HANDLE;
        Info("File logging enabled: " + m_log_file);
    }
    else
    {
        m_file_logging = false;
        Error("Failed to enable file logging: " + m_log_file);
    }
}

//+------------------------------------------------------------------+
//| Disable file logging                                             |
//+------------------------------------------------------------------+
void CLogger::DisableFileLogging()
{
    if(m_file_handle != INVALID_HANDLE)
    {
        FileClose(m_file_handle);
        m_file_handle = INVALID_HANDLE;
    }
    m_file_logging = false;
}

//+------------------------------------------------------------------+
//| Write message to file                                            |
//+------------------------------------------------------------------+
void CLogger::WriteToFile(string message)
{
    if(!m_file_logging || m_log_file == "") return;

    int handle = FileOpen(m_log_file, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(handle != INVALID_HANDLE)
    {
        FileSeek(handle, 0, SEEK_END);
        FileWriteString(handle, message + "\n");
        FileClose(handle);
    }
}

//+------------------------------------------------------------------+
//| Write message to console                                         |
//+------------------------------------------------------------------+
void CLogger::WriteToConsole(string message)
{
    if(m_console_logging)
    {
        Print(message);
    }
}

//+------------------------------------------------------------------+
//| Debug logging                                                    |
//+------------------------------------------------------------------+
void CLogger::Debug(string message)
{
    if(!ShouldLog(LOG_LEVEL_DEBUG)) return;

    string log_message = StringFormat("[%s] [%s] [%s] %s",
                                     GetTimestamp(), m_prefix, GetLogLevelString(LOG_LEVEL_DEBUG), message);

    WriteToConsole(log_message);
    WriteToFile(log_message);
}

//+------------------------------------------------------------------+
//| Info logging                                                     |
//+------------------------------------------------------------------+
void CLogger::Info(string message)
{
    if(!ShouldLog(LOG_LEVEL_INFO)) return;

    string log_message = StringFormat("[%s] [%s] [%s] %s",
                                     GetTimestamp(), m_prefix, GetLogLevelString(LOG_LEVEL_INFO), message);

    WriteToConsole(log_message);
    WriteToFile(log_message);
}

//+------------------------------------------------------------------+
//| Warning logging                                                  |
//+------------------------------------------------------------------+
void CLogger::Warning(string message)
{
    if(!ShouldLog(LOG_LEVEL_WARNING)) return;

    string log_message = StringFormat("[%s] [%s] [%s] %s",
                                     GetTimestamp(), m_prefix, GetLogLevelString(LOG_LEVEL_WARNING), message);

    WriteToConsole(log_message);
    WriteToFile(log_message);
}

//+------------------------------------------------------------------+
//| Error logging                                                    |
//+------------------------------------------------------------------+
void CLogger::Error(string message)
{
    if(!ShouldLog(LOG_LEVEL_ERROR)) return;

    string log_message = StringFormat("[%s] [%s] [%s] %s",
                                     GetTimestamp(), m_prefix, GetLogLevelString(LOG_LEVEL_ERROR), message);

    WriteToConsole(log_message);
    WriteToFile(log_message);
}

//+------------------------------------------------------------------+
//| Critical logging                                                 |
//+------------------------------------------------------------------+
void CLogger::Critical(string message)
{
    if(!ShouldLog(LOG_LEVEL_CRITICAL)) return;

    string log_message = StringFormat("[%s] [%s] [%s] %s",
                                     GetTimestamp(), m_prefix, GetLogLevelString(LOG_LEVEL_CRITICAL), message);

    WriteToConsole(log_message);
    WriteToFile(log_message);
}

//+------------------------------------------------------------------+
//| Log trade action                                                 |
//+------------------------------------------------------------------+
void CLogger::LogTrade(string action, string symbol, double volume, double price, double sl, double tp, string comment = "")
{
    string message = StringFormat("TRADE %s: %s %.2f lots @ %.5f SL:%.5f TP:%.5f %s",
                                 action, symbol, volume, price, sl, tp, comment);
    Info(message);
}

//+------------------------------------------------------------------+
//| Log trade result                                                 |
//+------------------------------------------------------------------+
void CLogger::LogTradeResult(bool success, int error_code, string details = "")
{
    if(success)
    {
        Info("Trade executed successfully" + (details != "" ? ": " + details : ""));
    }
    else
    {
        Error(StringFormat("Trade failed with error %d%s", error_code, (details != "" ? ": " + details : "")));
    }
}

//+------------------------------------------------------------------+
//| Log performance metric                                           |
//+------------------------------------------------------------------+
void CLogger::LogPerformance(string metric, double value)
{
    Info(StringFormat("PERFORMANCE %s: %.4f", metric, value));
}