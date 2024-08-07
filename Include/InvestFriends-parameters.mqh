//+------------------------------+
//|  InvestFriends-arameters.mqh |
//|  Alessandro Ren              |
//|  https://www.mql5.com        |
//+------------------------------+

enum ENUM_INPUT_YES_NO
{
   INPUT_YES   =  1, // Yes
   INPUT_NO    =  0  // No
};

input group "Trade on Symbol that is not the one on the Graph"
input ENUM_INPUT_YES_NO TradeOnAlternativeSymbol = INPUT_NO;
input string inTradeOnSymbol = "";

input group "Rolling futures - close on this one and open on the graph"
input string CloseTradeOnSymbol = "";

input group "Automatic symbol rolling"
input ENUM_INPUT_YES_NO UseAutomaticSymbolRolling = INPUT_NO;
input Symbol_Choice_Filter_Type RollingMethod = PRICE;

input  group             "Configuration"
input ENUM_TIMEFRAMES chartTimeframe = PERIOD_CURRENT;
input TRADE_DIRECTION TradeDirection = LONG_SHORT_TRADE;

input  group             "D. DAY TRADE"
sinput bool              inDayTrade = false;          // D.01 Operacao apenas como day trade
input int                inStartHour = 0;             // D.02 Hora inicio negociacao
input int                inStartWaitMin = 0;          // D.03 Minutos a aguardar antes de iniciar operacoes
input int                inStopHour = 23;             // D.04 Hora final negociacao
input int                inStopBeforeEndMin = 44;     // D.05 Minutos antes do fim para encerrar posicoes
input int                inMaxStartHour = 23;         // D.04 Hora final pra abrir posições
input int                inMaxBeforeEndMin = 44;      // D.05 Minutos final pra abrir posições

input  group             "Geldman!!"
input Geldmann_Type Geldmann_type = LOTS;
input double geldMann = 1;

input  group             "Trailing"
input AdjustBy AdjustByType = PERCENTAGE;
input double TrailingStart = 0.0; // Trailing starts in percentage
input double TrailingPriceAdjustBy = 2; // How much to adjust price - 0 breakeven

input  group             "Takeprofit, Stoploss & setStopAtProfit"
input double takeProfit = 0;
input double stopLoss = 0;

input  group             "Extras"
input double maxDailyLoss = 0;
input double maxDailyProfit = 0;
input int timeToSleep = 0;
input int MaxTradesDaily = 0;

/* If and how many times should I start a new trade */
input  group             "The Great Pyramid of Giza"
input int MaxPyramidTrades = 0;
input bool UseRiskToPyramid = true;

input  group             "ATR"
input int ATRPeriod = 14;