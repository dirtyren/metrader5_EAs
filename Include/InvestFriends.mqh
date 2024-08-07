//+------------------------------------------------------------------+
//|                                                InvestFriends.mqh |
//|                                                   Alessandro Ren |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Alessandro Ren"
#property link      "https://www.mql5.com"

#ifdef WFO
   #include <WalkForwardOptimizer.mqh>
#endif

#ifdef MCARLO
   #include <mcarlo.mqh>
#endif


#include<Trade\Trade.mqh>
#include <Controls\Dialog.mqh>
#include <Trade\DealInfo.mqh>

CDealInfo      m_deal;                       // object of CDealInfo class

#ifndef WFO
   //#define MCARLO 1
#endif

#ifdef MCARLO
   #include <mcarlo.mqh>
#endif

#ifdef WFO
   typedef double (*FUNCPTR_WFO_CUSTOM)(const datetime startDate, const datetime splitDate, const double &map[/*WFO_STATS_MAP*/]);
#endif

enum INVESTFRIENDS_ORDER_TYPE
  {
   MARKET_ORDER   =  0,
   LIMIT_ORDER =  1
  };

enum TRADE_DIRECTION //Type of extreme points
  {
   LONG_TRADE,
   SHORT_TRADE,
   LONG_SHORT_TRADE
  };
  
enum Geldmann_Type //Type of extreme points
  {
   LOTS,
   GELD,
   GELD_LOT_1
  };
  
enum Symbol_Choice_Filter_Type //Type of extreme points
  {
   PRICE,
   VOLUME,
   NEWEST
  };  

enum AdjustBy //Type of extreme points
  {
   PERCENTAGE,
   POINTS,
   ATR
  };
  
enum StopTypeList //Type of extreme points
  {
   SIGNAL,
   STOPLOSS,
   TAKEPROFIT,
   ENDOFTHEDAY,
   MAXDAILYLOSS,
   MAXDAILYPROFIT
  };  

#define NOTRADE 0
#define LONG 1
#define SHORT 2

int trade_signal = NOTRADE;
int trade_signal_exit = NOTRADE;

string GlobalSymbolsList;

string EAVersion = "";
string EAName = "";

datetime PositionDateTime = NULL;
double TradeEntryPrice = EMPTY_VALUE;
double StopLossPrice = EMPTY_VALUE;
double TakeProfitPrice = EMPTY_VALUE;
double LowestPrice = EMPTY_VALUE;
double HighestPrice = EMPTY_VALUE;
double LowestClosePrice = EMPTY_VALUE;
double HighestClosePrice = EMPTY_VALUE;

ulong PositionTicket = 0;
double PositionPrice = EMPTY_VALUE;
double PositionStopLoss = 0;
double PositionTakeProfit = 0;
double PositionPriceCurrent = EMPTY_VALUE;
int    PositionCandlePosition = 0;
long PositionType;
double PositionProfit = 0;

bool LineIsDrawn = false;

double AskPrice;
double BidPrice;
double TickSize;

int ATRHandle = INVALID_HANDLE;
double ATRValue[];
double ATROpenedTrade = 0;

MqlDateTime now;
MqlRates priceData[]; // array to keep the current and last candle
datetime timeStampCurrentCandle; // Do not trade more than once on the same candle
double Profit = 0;
datetime timeNow = TimeCurrent();
int todayIs = 0;
int last_signal =  NOTRADE;

struct SymbolInfo {
   string      symbolName;
   string      symbolDescription;
   string      symbolCategory;
   string      symbolBasis;
   string      symbolSector;
   string      symbolIndustry;
   string      symbolExchange;
   double      Varience;
   double      Rank;
   double      Bid;
   double      Ask;
   double      Price;
   double      Spread;
   double      SpreadChange;
   long        Volume;
   double      todayPrice;
   datetime    expireDatetime;
};

SymbolInfo TradeOnSymbolDetected;

int TrailingStopON = false;

string TradeOnSymbol = "";
string TradeOnLastSymbol = "";

static int onGoingTrade = NOTRADE;
static int stopLossAdjusted = 0;

static MqlRates candleTrade;

/* parameters */
long totalTrades = 0;
long totalPosisions = 0;
datetime timestampToWait = 0;
datetime lastAdjustedTime = 0;

CTrade trade;

datetime timeLastTrade = 0;
datetime timeLastCloseTrade = 0;
int signalLastCloseTrade = 0;
bool tradeOnCandle = false;
bool tradeArmed = false;

int startTime = 0;
int stopTime = 0;
int stopTrade = 0;
int hourMinuteNow = 0;


string buildCommentString(string Name, long tradeNr)
{
   string comment = GetTimeFrame(_Period);
   StringAdd(comment, " - ");
   StringAdd(comment, Name);
   StringAdd(comment, " - nr. ");
   StringAdd(comment, IntegerToString(totalTrades));
   return comment;
}

double getCandlesize(MqlRates &candleData) {
   double candleSize = 0;
   
   if (candleData.open > candleData.close) {
      candleSize = candleData.open - candleData.close;
   }
   else {
      candleSize = candleData.close - candleData.open;
   }
   
   return(candleSize);
}

/* Holt-Winter calculation */
double Calculate_Holt_Winters(int LookBackPeriod, double hw_alpha, double hw_beta, double holt_tw, ENUM_APPLIED_PRICE PriceType = PRICE_CLOSE) {

/* Calculate holt-winters parameters
   alpha: (1-alpha): weight to place on the most recent actual value (0 < alpha < 1)
   beta: (1-beta): weight to place on most recent trend (0 < beta < 1)
   tw: weight to place on the overall trend
*/
   
   double Prices[];
   double PricesLow[];
   double PricesHigh[];
   double PricesClose[];
   double PricesOpen[];
   int TotalPrices;
   ArraySetAsSeries(Prices, false);
   ArraySetAsSeries(PricesLow, false);
   ArraySetAsSeries(PricesLow, false);
   ArraySetAsSeries(PricesClose, false);
   ArraySetAsSeries(PricesOpen, false);
   //TotalPrices = CopyRates(_Symbol, chartTimeframe, 0, LookBackPeriod, priceDataAux);
   if (PriceType == PRICE_HIGH)
      TotalPrices = CopyHigh(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
   else if (PriceType == PRICE_LOW)
      TotalPrices = CopyLow(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
   else if (PriceType == PRICE_CLOSE)
      TotalPrices = CopyClose(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
   else if (PriceType == PRICE_OPEN)
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);  
   else if (PriceType == PRICE_MEDIAN) {
      TotalPrices = CopyHigh(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesHigh);  
      TotalPrices = CopyLow(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesLow);
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
      for (int i = 0; i<TotalPrices;i++) {
         Prices[i] = (PricesHigh[i] + PricesLow[i]) / 2;
      }
   }
   else if (PriceType == PRICE_TYPICAL) {
      TotalPrices = CopyHigh(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesHigh);  
      TotalPrices = CopyLow(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesLow);
      TotalPrices = CopyClose(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesClose);
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
      for (int i = 0; i<TotalPrices;i++) {
         Prices[i] = (PricesHigh[i] + PricesLow[i] + PricesClose[i]) / 3;
      }
   }
   else if (PriceType == PRICE_WEIGHTED) {
      TotalPrices = CopyHigh(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesHigh);  
      TotalPrices = CopyLow(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesLow);
      TotalPrices = CopyClose(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesClose);
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesOpen);
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
      for (int i = 0; i<TotalPrices;i++) {
         Prices[i] = (PricesHigh[i] + PricesLow[i] + PricesClose[i] + PricesOpen[i]) / 4;
      }
   }   

/* Calculate holt-winters parameters
   alpha: (1-alpha): weight to place on the most recent actual value (0 < alpha < 1)
   beta: (1-beta): weight to place on most recent trend (0 < beta < 1)
   tw: weight to place on the overall trend
*/
   double a2 = Prices[1];
   double t2 = Prices[1] - Prices[0];
   double f2 = a2 + (t2 * holt_tw);
   double f3 = EMPTY_VALUE;
   int i = 0;
   for (i = 0; i < (LookBackPeriod - 2); i++) {
   	double a3 = hw_alpha * f2 + (1 - hw_alpha) * Prices[i+1];
   	double t3 = hw_beta * t2 + (1 - hw_beta) * (a3 - a2);
   	f3 = a3 + (t3 * holt_tw);
   	a2 = a3;
   	t2 = t3;
   	f2 = f3;
   }

   return NormalizeDouble(f3, _Digits);
}

/* Exponential Smoothing */
double Calculate_Exponential_Smoothing(int LookBackPeriod, double hw_alpha, ENUM_APPLIED_PRICE PriceType = PRICE_CLOSE) {

   //MqlRates priceDataAux[]; // array to keep the current and last candle
   double Prices[];
   double PricesLow[];
   double PricesHigh[];
   double PricesClose[];
   double PricesOpen[];
   int TotalPrices;
   ArraySetAsSeries(Prices, false);
   ArraySetAsSeries(PricesLow, false);
   ArraySetAsSeries(PricesLow, false);
   ArraySetAsSeries(PricesClose, false);
   ArraySetAsSeries(PricesOpen, false);
   //TotalPrices = CopyRates(_Symbol, chartTimeframe, 0, LookBackPeriod, priceDataAux);
   if (PriceType == PRICE_HIGH)
      TotalPrices = CopyHigh(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
   else if (PriceType == PRICE_LOW)
      TotalPrices = CopyLow(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
   else if (PriceType == PRICE_CLOSE)
      TotalPrices = CopyClose(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
   else if (PriceType == PRICE_OPEN)
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);  
   else if (PriceType == PRICE_MEDIAN) {
      TotalPrices = CopyHigh(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesHigh);  
      TotalPrices = CopyLow(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesLow);
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
      for (int i = 0; i<TotalPrices;i++) {
         Prices[i] = (PricesHigh[i] + PricesLow[i]) / 2;
      }
   }
   else if (PriceType == PRICE_TYPICAL) {
      TotalPrices = CopyHigh(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesHigh);  
      TotalPrices = CopyLow(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesLow);
      TotalPrices = CopyClose(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesClose);
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
      for (int i = 0; i<TotalPrices;i++) {
         Prices[i] = (PricesHigh[i] + PricesLow[i] + PricesClose[i]) / 3;
      }
   }
   else if (PriceType == PRICE_WEIGHTED) {
      TotalPrices = CopyHigh(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesHigh);  
      TotalPrices = CopyLow(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesLow);
      TotalPrices = CopyClose(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesClose);
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesOpen);
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
      for (int i = 0; i<TotalPrices;i++) {
         Prices[i] = (PricesHigh[i] + PricesLow[i] + PricesClose[i] + PricesOpen[i]) / 4;
      }
   }   
   
   int i = 0;
   double value1 = Prices[0];
   double value2;
   
   for (i = 0; i < (LookBackPeriod - 2); i++) {
 		value2 = Prices[i+1];
   	value1 = (hw_alpha * value1) + (1 - hw_alpha) * value2;
   }
   return NormalizeDouble(value1, _Digits);
}

/* Double Exponential Smoothing */
double Calculate_Double_Exponential_Smoothing(int LookBackPeriod, double hw_alpha, double hw_gama, ENUM_APPLIED_PRICE PriceType = PRICE_CLOSE) {

   //MqlRates priceDataAux[]; // array to keep the current and last candle
   double Prices[];
   double PricesLow[];
   double PricesHigh[];
   double PricesClose[];
   double PricesOpen[];
   int TotalPrices;
   ArraySetAsSeries(Prices, false);
   ArraySetAsSeries(PricesLow, false);
   ArraySetAsSeries(PricesLow, false);
   ArraySetAsSeries(PricesClose, false);
   ArraySetAsSeries(PricesOpen, false);
   //TotalPrices = CopyRates(_Symbol, chartTimeframe, 0, LookBackPeriod, priceDataAux);
   if (PriceType == PRICE_HIGH)
      TotalPrices = CopyHigh(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
   else if (PriceType == PRICE_LOW)
      TotalPrices = CopyLow(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
   else if (PriceType == PRICE_CLOSE)
      TotalPrices = CopyClose(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
   else if (PriceType == PRICE_OPEN)
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);  
   else if (PriceType == PRICE_MEDIAN) {
      TotalPrices = CopyHigh(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesHigh);  
      TotalPrices = CopyLow(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesLow);
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
      for (int i = 0; i<TotalPrices;i++) {
         Prices[i] = (PricesHigh[i] + PricesLow[i]) / 2;
      }
   }
   else if (PriceType == PRICE_TYPICAL) {
      TotalPrices = CopyHigh(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesHigh);  
      TotalPrices = CopyLow(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesLow);
      TotalPrices = CopyClose(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesClose);
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
      for (int i = 0; i<TotalPrices;i++) {
         Prices[i] = (PricesHigh[i] + PricesLow[i] + PricesClose[i]) / 3;
      }
   }
   else if (PriceType == PRICE_WEIGHTED) {
      TotalPrices = CopyHigh(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesHigh);  
      TotalPrices = CopyLow(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesLow);
      TotalPrices = CopyClose(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesClose);
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, PricesOpen);
      TotalPrices = CopyOpen(_Symbol, chartTimeframe, 0, LookBackPeriod, Prices);
      for (int i = 0; i<TotalPrices;i++) {
         Prices[i] = (PricesHigh[i] + PricesLow[i] + PricesClose[i] + PricesOpen[i]) / 4;
      }
   }   
   
   int i = 0;
   double value1 = Prices[0];
   double value2 = EMPTY_VALUE;
   double b = Prices[1] - Prices[0];
   double last_calc = EMPTY_VALUE;
   
   for (i = 0; i < (LookBackPeriod - 2); i++) {
   
 		value2 = Prices[i+1];
 		last_calc = value1;
   	value1 = (hw_alpha * value2) + (1 - hw_alpha) * (value1 + b);
   	b = hw_gama * (value1 - last_calc) + (1 - hw_gama) * b;
   }
   return NormalizeDouble(value1, _Digits);

}

//+---------------------------------------------------------------------+
//| GetTimeFrame function - returns the textual timeframe               |
//+---------------------------------------------------------------------+
string GetTimeFrame(int lPeriod)
{

   switch(lPeriod) {
      case PERIOD_M1: return("M1");
      case PERIOD_M2: return("M2");
      case PERIOD_M3: return("M3");
      case PERIOD_M4: return("M4");
      case PERIOD_M5: return("M5");
      case PERIOD_M6: return("M6");
      case PERIOD_M10: return("M10");
      case PERIOD_M12: return("M12");
      case PERIOD_M15: return("M15");
      case PERIOD_M20: return("M20");
      case PERIOD_M30: return("M30");
      case PERIOD_H1: return("H1");
      case PERIOD_H2: return("H2");
      case PERIOD_H3: return("H3");
      case PERIOD_H4: return("H4");
      case PERIOD_H6: return("H6");
      case PERIOD_H8: return("H8");
      case PERIOD_H12: return("H12");
      case PERIOD_D1: return("D1");
      case PERIOD_W1: return("W1");
      case PERIOD_MN1: return("MN1");
   }

   return("NONE");
}

ENUM_TIMEFRAMES TFMigrate(int tf)
  {
   switch(tf)
     {
      case 0: return(PERIOD_CURRENT);
      case 1: return(PERIOD_M1);
      case 5: return(PERIOD_M5);
      case 15: return(PERIOD_M15);
      case 30: return(PERIOD_M30);
      case 60: return(PERIOD_H1);
      case 240: return(PERIOD_H4);
      case 1440: return(PERIOD_D1);
      case 10080: return(PERIOD_W1);
      case 43200: return(PERIOD_MN1);
      
      case 2: return(PERIOD_M2);
      case 3: return(PERIOD_M3);
      case 4: return(PERIOD_M4);      
      case 6: return(PERIOD_M6);
      case 10: return(PERIOD_M10);
      case 12: return(PERIOD_M12);
      case 16385: return(PERIOD_H1);
      case 16386: return(PERIOD_H2);
      case 16387: return(PERIOD_H3);
      case 16388: return(PERIOD_H4);
      case 16390: return(PERIOD_H6);
      case 16392: return(PERIOD_H8);
      case 16396: return(PERIOD_H12);
      case 16408: return(PERIOD_D1);
      case 32769: return(PERIOD_W1);
      case 49153: return(PERIOD_MN1);      
      default: return(PERIOD_CURRENT);
     }
  }

/* return all open positions for symbol on graph */
int returnAllPositions() {
   int total = 0, i = 0;
   ulong ticket;
   ulong magicNumber;
   string symbol;
   
   for (i=PositionsTotal()-1; i>=0; i--) {
      symbol = PositionGetSymbol(i);
      magicNumber = PositionGetInteger(POSITION_MAGIC);
      if (TradeOnSymbol == symbol && MyMagicNumber == magicNumber) { // I am on the right Symbol
         total++;
      }
   }
   if (total>0) {
      return total;
   }
   for(i=0;i<OrdersTotal();i++) {
      // choosing each order and getting its ticket
      ticket=OrderGetTicket(i);
      magicNumber = OrderGetInteger(ORDER_MAGIC);
      // processing orders with "our" symbols only
      if(OrderGetString(ORDER_SYMBOL) == TradeOnSymbol && magicNumber == MyMagicNumber ) {
         total++;
      }
   }
   return total;
}

/* return all open positions for symbol on graph */
void closePositionBy() {

   CPositionInfo  m_position;                   // object of CPositionInfo class
   ulong    old_ticket_buy    = 0;
   ulong    old_ticket_sell   = 0;
   ulong    young_ticket_buy  = 0;
   ulong    young_ticket_sell = 0;
   datetime old_time_buy      = D'3000.12.31 00:00';
   datetime old_time_sell     = D'3000.12.31 00:00';
   datetime young_time_buy    = D'1970.01.01 00:00';
   datetime young_time_sell   = D'1970.01.01 00:00';

   for(int i=PositionsTotal()-1; i>=0; i--) {
      if (m_position.SelectByIndex(i)) {// selects the position by index for further access to its properties
         if(m_position.Symbol() == TradeOnSymbol && m_position.Magic() == MyMagicNumber) {
            datetime pos_time=m_position.Time();
            if(m_position.PositionType() == POSITION_TYPE_BUY) {
               if(pos_time < old_time_buy) {
                  old_time_buy = pos_time;
                  old_ticket_buy = m_position.Ticket();
               }
               if(pos_time > young_time_buy) {
                  young_time_buy = pos_time;
                  young_ticket_buy = m_position.Ticket();
               }
               continue;
            }
            else {
               if(m_position.PositionType()==POSITION_TYPE_SELL) {
                  if(pos_time < old_time_sell) {
                     old_time_sell = pos_time;
                     old_ticket_sell = m_position.Ticket();
                  }
                  if(pos_time > young_time_sell) {
                     young_time_sell = pos_time;
                     young_ticket_sell = m_position.Ticket();
                  }
               }
            }
         }
      }
   }

   //--- old_ticket_buy -> young_ticket_sell
   if(old_ticket_buy>0  && young_ticket_sell>0)
      trade.PositionCloseBy(old_ticket_buy,young_ticket_sell);

   //--- old_ticket_sell -> young_ticket_buy
   if(old_ticket_sell>0 && young_ticket_buy>0)
      trade.PositionCloseBy(old_ticket_sell,young_ticket_buy);

}

int returnTotalPendingOrder() {
   int total = 0, i = 0;
   ulong ticket;
   ulong magicNumber;

   for(i=0;i<OrdersTotal();i++) {
      // choosing each order and getting its ticket
      ticket = OrderGetTicket(i);
      magicNumber = OrderGetInteger(ORDER_MAGIC);
      // processing orders with "our" symbols only
      if(OrderGetString(ORDER_SYMBOL) == TradeOnSymbol && magicNumber == MyMagicNumber ) {
         //Print("Order state: ",OrderGetInteger(ORDER_STATE));
         if (OrderGetInteger(ORDER_STATE) == ORDER_STATE_PLACED) {
            total++;
         }
      }
   }
   return total;
}

int returnTotalPendingOrderbyType(ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY) {
   int total = 0, i = 0;
   ulong ticket;
   ulong magicNumber;

   for(i=0;i<OrdersTotal();i++) {
      // choosing each order and getting its ticket
      ticket = OrderGetTicket(i);
      magicNumber = OrderGetInteger(ORDER_MAGIC);
      // processing orders with "our" symbols only
      if(OrderGetString(ORDER_SYMBOL) == TradeOnSymbol && magicNumber == MyMagicNumber ) {
         //Print("Order state: ",OrderGetInteger(ORDER_STATE));
         if (OrderGetInteger(ORDER_STATE) == ORDER_STATE_PLACED) {
            if (OrderGetInteger(ORDER_TYPE) == order_type) {
               total++;
            }
         }
      }
   }
   return total;
}

void removeOrders(int order_type) {
   int i = 0;
   ulong ticket;
   ulong magicNumber;

   for(i=0;i<OrdersTotal();i++) {
      // choosing each order and getting its ticket
      ticket = OrderGetTicket(i);
      if (OrderSelect(ticket) == false) {
         return;
      }
      magicNumber = OrderGetInteger(ORDER_MAGIC);
      if(OrderGetString(ORDER_SYMBOL) == TradeOnSymbol && magicNumber == MyMagicNumber ) {
         if (order_type == OrderGetInteger(ORDER_TYPE)) {
            trade.OrderDelete(ticket);
         }
      }
   }
}

void closeAllPositions(StopTypeList StopType) {
   int i;
   string symbol;
   ulong magicNumber,ticket;
   bool closed;

   for (i=PositionsTotal()-1; i>=0; i--) {
      symbol = PositionGetSymbol(i);
      magicNumber = PositionGetInteger(POSITION_MAGIC);
      if (TradeOnSymbol == symbol && MyMagicNumber == magicNumber) { // I am on the right Symbol
         ticket = PositionGetTicket(i);
         closed = trade.PositionClose(ticket);
         string stopTypeName;
         if (StopType == SIGNAL) {
            stopTypeName = "SIGNAL";
         } 
         else if (StopType == STOPLOSS) {
            stopTypeName = "STOPLOSS";
         }
         else if (StopType == TAKEPROFIT) {
            stopTypeName = "TAKEPROFIT";
         }
         else if (StopType == ENDOFTHEDAY) {
            stopTypeName = "ENDOFTHEDAY";
         }
         else if (StopType == MAXDAILYLOSS) {
            stopTypeName = "MAXDAILYLOSS";
         }
         else if (StopType == MAXDAILYPROFIT) {
            stopTypeName = "MAXDAILYPROFIT";
         }
         printf("%s Closing position on %s - Total trades %d - ret %d", stopTypeName, TradeOnSymbol, totalTrades, closed);
      }
   }
   for(i=0;i<OrdersTotal();i++) {
      ticket = OrderGetTicket(i);
      magicNumber = OrderGetInteger(ORDER_MAGIC);
      if(OrderGetString(ORDER_SYMBOL) == TradeOnSymbol && magicNumber == MyMagicNumber ) {
         closed = trade.PositionClose(ticket);
         trade.OrderDelete(ticket);
      }
   }
   TakeProfitPrice = EMPTY_VALUE;
   StopLossPrice = EMPTY_VALUE;
   TradeEntryPrice = EMPTY_VALUE;
   Sleep(1000);
   stopLossAdjusted = 0;
}

void CheckAndChangeSymbol(string symbolToCheck) {
   for (int i=PositionsTotal()-1; i>=0; i--) {
      string symbol = PositionGetSymbol(i);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      double stopGain = 0;

      if (symbolToCheck == symbol && MyMagicNumber == magicNumber) { // I am on the right Symbol
         PositionTicket = PositionGetInteger(POSITION_TICKET);
         PositionPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
         PositionStopLoss = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
         PositionTakeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), _Digits);
         PositionType = PositionGetInteger(POSITION_TYPE);
         PositionDateTime = (datetime)PositionGetInteger(POSITION_TIME);
         PositionCandlePosition = iBarShift(TradeOnSymbol, PERIOD_CURRENT, PositionDateTime,false);
         
         int TradeType = NOTRADE;
         if (PositionType == POSITION_TYPE_BUY) {
            TradeType = LONG;
         }
         else if (PositionType == POSITION_TYPE_SELL) {
            TradeType = SHORT;
         }
         closeAllPositionsOnSymbol(symbolToCheck);
         TradeMann(TradeType, TradeType);
      }
   }
}

void CheckAndChangeBaseSymbol(string symbolToCheck) {

   string BaseSymbolToCheck = StringSubstr(symbolToCheck,0,3);
   SymbolInfo sInfo;
   
   if (symbolToCheck == "") {
      Print("Empty string, nothing to do - CheckAndChangeBaseSymbol");
      return;
   }
   
   for (int i=PositionsTotal()-1; i>=0; i--) {
      string symbol = PositionGetSymbol(i);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);

      //Print("CheckAndChangeBaseSymbol symbol ", symbol, " symbolToCheck ", symbolToCheck);
      /* already trading on symbol */
      if (symbol == symbolToCheck && MyMagicNumber == magicNumber) {
         Print("Already on trade - CheckAndChangeBaseSymbol symbol ", symbol, " symbolToCheck ", symbolToCheck);
         continue;
      }
      
      double stopGain = 0;
      
      string BaseSymbol = StringSubstr(symbol,0,3);

      if (BaseSymbolToCheck == BaseSymbol && MyMagicNumber == magicNumber) { // I am on the right Symbol
         sInfo.symbolName = symbol;
         getSymbolValues(sInfo);
         if (TimeSymbolToExpires(sInfo) < -86400) {
            Print("Symbol ",symbol, " already expired - o not use it ");
            continue;
         }
         
         PositionTicket = PositionGetInteger(POSITION_TICKET);
         PositionPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
         PositionStopLoss = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
         PositionTakeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), _Digits);
         PositionType = PositionGetInteger(POSITION_TYPE);
         PositionDateTime = (datetime)PositionGetInteger(POSITION_TIME);
         PositionCandlePosition = iBarShift(TradeOnSymbol, PERIOD_CURRENT, PositionDateTime,false);
         
         int TradeType = NOTRADE;
         if (PositionType == POSITION_TYPE_BUY) {
            TradeType = LONG;
         }
         else if (PositionType == POSITION_TYPE_SELL) {
            TradeType = SHORT;
         }
         closeAllPositionsOnSymbol(symbol);
         TradeMann(TradeType, TradeType);
      }
   }
}

void closeAllPositionsOnSymbol(string symbolToCheck) {
   int i;
   string symbol;
   ulong magicNumber,ticket;
   bool closed;

   for (i=PositionsTotal()-1; i>=0; i--) {
      symbol = PositionGetSymbol(i);
      magicNumber = PositionGetInteger(POSITION_MAGIC);
      if (symbolToCheck == symbol && MyMagicNumber == magicNumber) { // I am on the right Symbol
         ticket = PositionGetTicket(i);
         closed = trade.PositionClose(ticket);
         printf("Change symbol - Closing all positions on %s - ret %d", symbolToCheck, closed);
      }
   }
}

void getPositionOpen() {
   MqlTick tickInfo;

   PositionTicket = 0;
   PositionPrice = EMPTY_VALUE;
   PositionStopLoss = 0;
   PositionTakeProfit = 0;
   PositionPriceCurrent = EMPTY_VALUE;
   PositionCandlePosition = 0;
  
   SymbolInfoTick(TradeOnSymbol, tickInfo);
   PositionPriceCurrent = tickInfo.last;
   if (PositionPriceCurrent == 0) {
      PositionPriceCurrent = tickInfo.ask;
   }
   AskPrice = tickInfo.ask;
   BidPrice = tickInfo.bid;
   TickSize = SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);

   for (int i = 0; i <= PositionsTotal()-1; i++) {
      string symbol = PositionGetSymbol(i);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      double stopGain = 0;

      if (TradeOnSymbol == symbol && MyMagicNumber == magicNumber) { // I am on the right Symbol
         PositionTicket = PositionGetInteger(POSITION_TICKET);
         PositionPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
         PositionStopLoss = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
         PositionTakeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), _Digits);
         PositionType = PositionGetInteger(POSITION_TYPE);
         PositionDateTime = (datetime)PositionGetInteger(POSITION_TIME);
         PositionCandlePosition = iBarShift(TradeOnSymbol, PERIOD_CURRENT, PositionDateTime,false);
         PositionProfit = NormalizeDouble(PositionGetDouble(POSITION_PROFIT), _Digits);
         //Print("PositionTicket ", PositionTicket," PositionPrice ", PositionPrice);
         //break;
      }
   }
}

void setStops(double priceSL, double priceTP) {

   setStopLoss(priceSL);
   setTakeProfit(priceTP);
}

void setStopLoss(double price) {

   MqlTick tickInfo;

   double tickSize = SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);
   price = NormalizeDouble(price, _Digits);
   if (tickSize > 0) {
      price = MathRound(price/tickSize)*tickSize;
   }
   
   PositionTicket = 0;
   PositionPrice = EMPTY_VALUE;
   PositionStopLoss = 0;
   PositionTakeProfit = 0;
   PositionPriceCurrent = EMPTY_VALUE;
   PositionCandlePosition = 0;
  
   SymbolInfoTick(TradeOnSymbol, tickInfo);
   PositionPriceCurrent = tickInfo.last;
   if (PositionPriceCurrent == 0) {
      PositionPriceCurrent = tickInfo.ask;
   }
   AskPrice = tickInfo.ask;
   BidPrice = tickInfo.bid;
   TickSize = SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);

   for (int i=PositionsTotal()-1; i>=0; i--) {
      string symbol = PositionGetSymbol(i);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      double stopGain = 0;

      if (TradeOnSymbol == symbol && MyMagicNumber == magicNumber) { // I am on the right Symbol
         PositionTicket = PositionGetInteger(POSITION_TICKET);
         PositionPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
         PositionStopLoss = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
         PositionTakeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), _Digits);
         PositionType = PositionGetInteger(POSITION_TYPE);
         PositionDateTime = (datetime)PositionGetInteger(POSITION_TIME);
         PositionCandlePosition = iBarShift(TradeOnSymbol, PERIOD_CURRENT, PositionDateTime,false);
         PositionProfit = NormalizeDouble(PositionGetDouble(POSITION_PROFIT), _Digits);
         trade.PositionModify(PositionTicket, price, PositionTakeProfit);
      }
   }
   
}

void setTakeProfit(double price) {
   Print("setTakeProfit ");
   MqlTick tickInfo;

   double tickSize = SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);
   price = NormalizeDouble(price, _Digits);
   if (tickSize > 0) {
      price = MathRound(price/tickSize)*tickSize;
   }
   
   PositionTicket = 0;
   PositionPrice = EMPTY_VALUE;
   PositionStopLoss = 0;
   PositionTakeProfit = 0;
   PositionPriceCurrent = EMPTY_VALUE;
   PositionCandlePosition = 0;
  
   SymbolInfoTick(TradeOnSymbol, tickInfo);
   PositionPriceCurrent = tickInfo.last;
   if (PositionPriceCurrent == 0) {
      PositionPriceCurrent = tickInfo.ask;
   }
   AskPrice = tickInfo.ask;
   BidPrice = tickInfo.bid;
   TickSize = SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);

   for (int i=PositionsTotal()-1; i>=0; i--) {
      string symbol = PositionGetSymbol(i);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      double stopGain = 0;

      if (TradeOnSymbol == symbol && MyMagicNumber == magicNumber) { // I am on the right Symbol
         PositionTicket = PositionGetInteger(POSITION_TICKET);
         PositionPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
         PositionStopLoss = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
         PositionTakeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), _Digits);
         PositionType = PositionGetInteger(POSITION_TYPE);
         PositionDateTime = (datetime)PositionGetInteger(POSITION_TIME);
         PositionCandlePosition = iBarShift(TradeOnSymbol, PERIOD_CURRENT, PositionDateTime,false);
         PositionProfit = NormalizeDouble(PositionGetDouble(POSITION_PROFIT), _Digits);
         trade.PositionModify(PositionTicket, PositionStopLoss, price);
      }
   }
}

void adjustStopLoss(AdjustBy AdjustTrailByType)
{
   if (lastAdjustedTime < TimeCurrent()) {
      lastAdjustedTime = TimeCurrent();
   }
   else {
      return;
   }
   if (TrailingStart == 0 ) {
      return;
   }
   
   //getPositionOpen(); // upate all trade variables
   //if (PositionTicket <= 0) {
      //return;
   //}
   
   for (int i=PositionsTotal()-1; i>=0; i--) {
      string symbol = PositionGetSymbol(i);
      ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
      double stopGain = 0;

      if (TradeOnSymbol == symbol && MyMagicNumber == magicNumber) { // I am on the right Symbol
         PositionTicket = PositionGetInteger(POSITION_TICKET);
         PositionPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
         PositionStopLoss = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
         PositionTakeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), _Digits);
         PositionType = PositionGetInteger(POSITION_TYPE);
         PositionDateTime = (datetime)PositionGetInteger(POSITION_TIME);
         PositionCandlePosition = iBarShift(TradeOnSymbol, PERIOD_CURRENT, PositionDateTime,false);
         PositionProfit = NormalizeDouble(PositionGetDouble(POSITION_PROFIT), _Digits);
         adjustTrailingLoss(AdjustTrailByType);
      }
   }
}

void adjustTrailingLoss(AdjustBy AdjustTrailByType) 
{
   double stopEven;
   double stopGain;

   if (PositionType == POSITION_TYPE_BUY) {
      if (stopLoss > 0 && PositionStopLoss < PositionPrice) {
         PositionStopLoss = 0;
      }
      stopEven = calculateStopEven(PositionPrice, PositionStopLoss, TrailingStart, PositionType, AdjustTrailByType);
      if ( priceData[0].close >= stopEven) { // reached price, adjust stop
         TrailingStopON = true;
         stopGain = calculateStopGain(PositionPrice, PositionStopLoss, TrailingPriceAdjustBy, PositionType, AdjustTrailByType);
         if (PositionStopLoss > 0 && stopGain > PositionStopLoss ) {
            trade.PositionModify(PositionTicket, stopGain, 0);
            printf("adjustStopLoss BUY reached1: PositionStopLoss %.5f stopGain %.5f Price close %.4f stopEven %.4f", PositionStopLoss, stopGain, priceData[0].close, stopEven);
            stopLossAdjusted++;
         }
         else if (stopGain >= PositionPrice && stopGain > PositionStopLoss) {
            trade.PositionModify(PositionTicket, stopGain, 0);
            printf("adjustStopLoss BUY reached2: PositionPrice %.4f stopGain %.4f Price close %.4f stopEven %.4f", PositionPrice, stopGain, priceData[0].close, stopEven);
            stopLossAdjusted++;
         }
      }
   }
   else if (PositionType == POSITION_TYPE_SELL) {
      if (stopLoss > 0 && PositionStopLoss > PositionPrice) {
         PositionStopLoss = 0;
      }
      stopEven = calculateStopEven(PositionPrice, PositionStopLoss, TrailingStart, PositionType, AdjustTrailByType);

      if ( priceData[0].close < stopEven) { // reached price, adjust stop
         TrailingStopON = true;
         stopGain = calculateStopGain(PositionPrice, PositionStopLoss, TrailingPriceAdjustBy, PositionType, AdjustTrailByType);
         if (PositionStopLoss > 0 && stopGain < PositionStopLoss ) {
            trade.PositionModify(PositionTicket, stopGain, 0);
            printf("adjustStopLoss SHORT reached: PositionStopLoss %.4f stopGain %.4f Price close %.4f stopEven %.4f", PositionStopLoss, stopGain, priceData[0].close, stopEven);
            stopLossAdjusted++;
         }
         else if (stopGain <= PositionPrice && stopGain < PositionStopLoss) {
            trade.PositionModify(PositionTicket, stopGain, 0);
            printf("adjustStopLoss SHORT reached: PositionPrice %.4f stopGain %.4f Price close %.4f stopEven %.4f", PositionPrice, stopGain, priceData[0].close, stopEven);
            stopLossAdjusted++;
         }
      }
   }
}

double calculateStopEven(double OpenPositionPrice, double OpenPositionStopLoss, double TrailingStartParam, long OpenPositionType, AdjustBy AdjustTrailByType)
{
   double stopEven = 0;
   if (OpenPositionType == POSITION_TYPE_BUY) {
      if (AdjustTrailByType == PERCENTAGE) {
         if (PositionStopLoss == 0) {
            stopEven = NormalizeDouble(OpenPositionPrice * (1+(TrailingStartParam/100)), _Digits);         
         }
         else {
            stopEven = NormalizeDouble(OpenPositionStopLoss * (1+(TrailingStartParam/100)), _Digits);
         }
      }
      else if (AdjustTrailByType == POINTS) {
         if (PositionStopLoss == 0) {
            stopEven = NormalizeDouble(OpenPositionPrice + TrailingStartParam, _Digits);         
         }
         else {
            stopEven = NormalizeDouble(OpenPositionStopLoss + TrailingStartParam, _Digits);         
         }
      }
      else if (AdjustTrailByType == ATR) {
         if (PositionStopLoss == 0) {
            stopEven = NormalizeDouble(OpenPositionPrice + (ATRValue[1] * TrailingStartParam) , _Digits);         
         }
         else {
            stopEven = NormalizeDouble(OpenPositionStopLoss + (ATRValue[1] * TrailingStartParam), _Digits);         
         }
      }
   }
   else if (OpenPositionType == POSITION_TYPE_SELL) {
      if (AdjustTrailByType == PERCENTAGE) {
         if (PositionStopLoss == 0) {
            stopEven = NormalizeDouble(OpenPositionPrice - (OpenPositionPrice * TrailingStartParam / 100), _Digits);         
         }
         else {
            stopEven = NormalizeDouble(OpenPositionStopLoss - (OpenPositionStopLoss * TrailingStartParam / 100), _Digits);
         }
      }
      else if (AdjustTrailByType == POINTS) {
         if (PositionStopLoss == 0) {
            stopEven = NormalizeDouble(OpenPositionPrice - TrailingStartParam, _Digits);         
         }
         else {
            stopEven = NormalizeDouble(OpenPositionStopLoss - TrailingStartParam, _Digits);         
         }
      }
      else if (AdjustTrailByType == ATR) {
         if (PositionStopLoss == 0) {
            stopEven = NormalizeDouble(OpenPositionPrice - (ATRValue[1] * TrailingStartParam) , _Digits);         
         }
         else {
            stopEven = NormalizeDouble(OpenPositionStopLoss - (ATRValue[1] * TrailingStartParam), _Digits);         
         }
      }
   }
   
   return(stopEven);
}

double calculateStopGain(double OpenPositionPrice, double OpenPositionStopLoss, double TrailingPriceAdjustByParam, long OpenPositionType, AdjustBy AdjustTrailByType)
{
   double stopGain = 0;
   double tickSize = SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);

   if (OpenPositionType == POSITION_TYPE_BUY) {
      if (AdjustTrailByType == PERCENTAGE) {
         if (OpenPositionStopLoss == 0) {
            stopGain = NormalizeDouble(OpenPositionPrice * (1+(TrailingPriceAdjustByParam/100) )  , _Digits);
         }
         else {
            stopGain = NormalizeDouble(OpenPositionStopLoss * (1+(TrailingPriceAdjustByParam/100) ) , _Digits);
         }
      }
      else if (AdjustTrailByType == POINTS) {
         if (OpenPositionStopLoss == 0) {
            stopGain = NormalizeDouble(MathRound(OpenPositionPrice + TrailingPriceAdjustByParam+tickSize) , _Digits);
         }
         else {
            stopGain = NormalizeDouble(MathRound(OpenPositionStopLoss + TrailingPriceAdjustByParam+tickSize) , _Digits);
         }
      }
      else if (AdjustTrailByType == ATR) {
         if (OpenPositionStopLoss == 0) {
            stopGain = NormalizeDouble(OpenPositionPrice + (ATROpenedTrade * TrailingPriceAdjustByParam) , _Digits);         
         }
         else {
            stopGain = NormalizeDouble(OpenPositionStopLoss + (ATROpenedTrade * TrailingPriceAdjustByParam), _Digits);         
         }
      }
   }
   else if (OpenPositionType == POSITION_TYPE_SELL) {
      if (AdjustTrailByType == PERCENTAGE) {
         if (OpenPositionStopLoss == 0) {
            stopGain = NormalizeDouble(OpenPositionPrice - (OpenPositionPrice * TrailingPriceAdjustByParam/100) , _Digits);
         }
         else {
            stopGain = NormalizeDouble(OpenPositionStopLoss - (OpenPositionStopLoss * TrailingPriceAdjustByParam/100) , _Digits);
         }
      }
      else if (AdjustTrailByType == POINTS) {
         if (OpenPositionStopLoss == 0) {
            stopGain = NormalizeDouble(MathRound(OpenPositionPrice - TrailingPriceAdjustByParam+tickSize) , _Digits);
         }
         else {
            stopGain = NormalizeDouble(MathRound(OpenPositionStopLoss - TrailingPriceAdjustByParam+tickSize) , _Digits);
         }
      }
      else if (AdjustTrailByType == ATR) {
         if (OpenPositionStopLoss == 0) {
            stopGain = NormalizeDouble(OpenPositionPrice - (ATROpenedTrade * TrailingPriceAdjustByParam) , _Digits);         
         }
         else {
            stopGain = NormalizeDouble(OpenPositionStopLoss - (ATROpenedTrade * TrailingPriceAdjustByParam), _Digits);         
         }
      }
   }

   if (tickSize > 0) {
      stopGain = MathRound(stopGain/tickSize)*tickSize;   
   }
   return(stopGain);
}

double calculateStopLoss(double OpenPositionPrice, double StopLossParam, ENUM_POSITION_TYPE OpenPositionType, AdjustBy AdjustTrailByType)
{
   double stopLossPrice = 0;
   double tickSize = SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);
   
   if (OpenPositionType == POSITION_TYPE_SELL) {
      if (AdjustTrailByType == PERCENTAGE) {
         stopLossPrice = NormalizeDouble(OpenPositionPrice * (1+(StopLossParam/100))  , _Digits);
      }
      else if (AdjustTrailByType == POINTS) {
         stopLossPrice = NormalizeDouble(MathRound(OpenPositionPrice + StopLossParam+tickSize) , _Digits);
      }
      else if (AdjustTrailByType == ATR) {
         stopLossPrice = NormalizeDouble(MathRound(OpenPositionPrice +  (ATROpenedTrade * StopLossParam) + tickSize) , _Digits);
      }
   }
   else if (OpenPositionType == POSITION_TYPE_BUY) {
      if (AdjustTrailByType == PERCENTAGE) {
         stopLossPrice = NormalizeDouble(OpenPositionPrice - (OpenPositionPrice * StopLossParam/100) , _Digits);
      }
      else if (AdjustTrailByType == POINTS) {
         stopLossPrice = NormalizeDouble(MathRound(OpenPositionPrice - StopLossParam+tickSize) , _Digits);
      }
      else if (AdjustTrailByType == ATR) {
         stopLossPrice = NormalizeDouble(MathRound(OpenPositionPrice -  (ATROpenedTrade * StopLossParam) + tickSize) , _Digits);
      }
   }
   if (tickSize > 0) {
      stopLossPrice = MathRound(stopLossPrice/tickSize)*tickSize;
   }
   
   return(stopLossPrice);
}

void FixPriceOnSymbol(double &PriceToFix)
{
   double tickSize = SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);
   PriceToFix = NormalizeDouble(PriceToFix, _Digits);
   if (tickSize > 0) {
      PriceToFix = MathRound(PriceToFix/tickSize)*tickSize;
   }
}

double closedProfitPeriod()
{
   double profit = 0.00;
   totalTrades = 0;

   datetime thisPeriod = TimeCurrent() - 32400;
   HistorySelect(thisPeriod,TimeCurrent());
   
   uint TotalNumberOfDeals = HistoryDealsTotal();
   ulong TicketNumber = 0;
   long OrderType, DealEntry;
   double OrderProfit;
   ulong MagicNumber;
   string MySymbol;
   
   for(uint i = 0; i < TotalNumberOfDeals; i++) {
      TicketNumber = HistoryDealGetTicket(i);
      // Print("i %u ticket %u ", i, TicketNumber);
      if (TicketNumber > 0) {
         OrderProfit = HistoryDealGetDouble(TicketNumber,DEAL_PROFIT);
         MySymbol = HistoryDealGetString(TicketNumber, DEAL_SYMBOL);
         MagicNumber = HistoryDealGetInteger(TicketNumber,DEAL_MAGIC);
         OrderType = HistoryDealGetInteger(TicketNumber,DEAL_TYPE);
         DealEntry = HistoryDealGetInteger(TicketNumber,DEAL_ENTRY);
         
         if (MagicNumber == MyMagicNumber && TradeOnSymbol == MySymbol) {
            if (OrderType == ORDER_TYPE_BUY || OrderType == ORDER_TYPE_SELL) {
               if (DealEntry == DEAL_ENTRY_OUT) {
                  //printf("OrderType %u DealEntry %u - ticket  %u - OrderProfit %.4f - MagicNumber %u %u",OrderType, DealEntry, TicketNumber, OrderProfit, MagicNumber);
                  profit += OrderProfit;
                  totalTrades++;
               }
            }
         }
      }
   }
   return(profit);
}

int checkPositionTypeOpen()
{
   int tradeDirection = NOTRADE;

   getPositionOpen();
   if (PositionTicket <= 0) {
      removeLine("Buy");
      removeLine("Sell");
      removeLine("StopLoss");
      removeLine("TakeProfit");   
      return tradeDirection;
   }
   
   if (PositionType == POSITION_TYPE_BUY) {
      if (PositionStopLoss > 0 && PositionPriceCurrent < PositionStopLoss) { // close trade, stoploss hit
         closeAllPositions(STOPLOSS);
         tradeDirection = NOTRADE;
      }
      if (PositionTakeProfit > 0 && PositionPriceCurrent >= PositionTakeProfit) { // close trade, take profit
         closeAllPositions(TAKEPROFIT);
         tradeDirection = NOTRADE;
      }
      tradeDirection = LONG;
   }
   else if (PositionType == POSITION_TYPE_SELL) {
      if (PositionStopLoss > 0 && PositionPriceCurrent > PositionStopLoss) { // close trade, stoploss hit
         closeAllPositions(STOPLOSS);
         tradeDirection = NOTRADE;
      }
      if (PositionTakeProfit > 0 && PositionPriceCurrent <= PositionTakeProfit) { // close trade, take profit
         closeAllPositions(TAKEPROFIT);
         tradeDirection = NOTRADE;
      }
      tradeDirection = SHORT;
   }
   
   if (tradeDirection == SHORT && PositionPrice != EMPTY_VALUE) {
      drawLine("Sell", PositionPrice, clrDodgerBlue);
   }
   if (tradeDirection == LONG && PositionPrice != EMPTY_VALUE) {
      drawLine("Buy", PositionPrice, clrDodgerBlue);
   }
   if(PositionStopLoss > 0 && PositionStopLoss != EMPTY_VALUE) {
      drawLine("StopLoss", PositionStopLoss, clrRed);
   }
   if(PositionTakeProfit > 0 && PositionTakeProfit != EMPTY_VALUE) {
      drawLine("TakeProfit", PositionTakeProfit, clrGreen);
   }

   if (tradeDirection == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
      StopLossPrice = EMPTY_VALUE;
      TradeEntryPrice = EMPTY_VALUE;
   }

   return tradeDirection;
}

bool AddIndicator(int indicator_handle, int subWindow = 0)
  {

   ResetLastError();
   int subwindow = 0;
   if (subWindow == 0) {
      subwindow = subWindow;
   }
   else {
      subwindow = (int)ChartGetInteger(0,CHART_WINDOWS_TOTAL);
   }
   if(!ChartIndicatorAdd(0,subwindow,indicator_handle)) {
      if (GetLastError() == 4114) {
         PrintFormat("Indicator already on chart");
      }
      else {
         PrintFormat("Failed to add indicator on %d chart window. Error code  %d", subwindow,GetLastError());
      }
   }
//--- Indicator added successfully
   return(true);
  }
  
void cleanUPIndicators()
  {
   //--- The number of windows on the chart (at least one main window is always present)
   int windows=(int)ChartGetInteger(0,CHART_WINDOWS_TOTAL);
   PrintFormat("Windows=%d",windows);
   //--- Check all windows
   for(int w=(windows-1);w>=0;w--)
     {
      //--- the number of indicators in this window/subwindow
      int total=ChartIndicatorsTotal(0,w);
      PrintFormat("Window=%d Charts=%d",w,total);
      //--- Go through all indicators in the window
      for(int i=0;i<total;i++)
        {
         //--- get the short name of an indicator
         string name=ChartIndicatorName(0,w,i);
         //--- get the handle of an indicator
         int handle=ChartIndicatorGet(0,w,name);
         ChartIndicatorDelete(0,w,name);
         //--- Add to log
         PrintFormat("Window=%d,  index=%d,  name=%s,  handle=%d",w,i,name,handle);
         //--- You should obligatorily release the indicator handle when it is no longer needed
         IndicatorRelease(handle);
        }
     }
  }
  
/* -------------- */
void DeInitEA()
{
   cleanUPIndicators();
}
  
/* */
bool InitEA()
{
   if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
      Print("Invalid trailing parameter ",TrailingStart, " ",TrailingStart);
      return(false);
   }
   
   HighestPrice = EMPTY_VALUE;
   LowestPrice = EMPTY_VALUE;
  
   if (UseAutomaticSymbolRolling == INPUT_NO) {
      TradeOnSymbol = _Symbol;
   }
   if (TradeOnAlternativeSymbol == INPUT_YES) {
      TradeOnSymbol = inTradeOnSymbol;
   }
   if (CloseTradeOnSymbol != "") {
      Print("Rolling contract: ", CloseTradeOnSymbol," to ",TradeOnSymbol);
      CheckAndChangeSymbol(CloseTradeOnSymbol);
   }

   startTime = (inStartHour * 60) + inStartWaitMin;
   stopTime = (inStopHour * 60) + inStopBeforeEndMin;
   stopTrade = (inMaxStartHour * 60) + inMaxBeforeEndMin;

   cleanUPIndicators();
   
   trade.SetExpertMagicNumber(MyMagicNumber);

   ArraySetAsSeries(priceData, true);
   CopyRates(_Symbol, chartTimeframe, 0, 3, priceData);
   
   onGoingTrade = checkPositionTypeOpen();
   totalPosisions = returnAllPositions();
   printf("onGoingTrade %d totalPosisions %d closedprofit %.2f", onGoingTrade, totalPosisions, closedProfitPeriod());
   
   StringAdd(EAName, " ");
   StringAdd(EAName, EAVersion);
   Comment(EAName, " Magic number: ", MyMagicNumber, " Profit ", closedProfitPeriod());
   
   LineIsDrawn = false;

   return(true);
}


void TradeNewMann(int signal)
{
   double Ask = NormalizeDouble(SymbolInfoDouble(TradeOnSymbol,SYMBOL_ASK), _Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(TradeOnSymbol,SYMBOL_BID), _Digits);
   
   if (tradeOnCandle == true) {
      signal = NOTRADE;
   }
   
   double stopLossPrice = 0;
   double priceTakeProfit = 0;
   if (signal == LONG) {
      CalculateSL_TP(ORDER_TYPE_BUY, priceData[0].close, stopLossPrice, priceTakeProfit);
   }
   else if (signal == SHORT) {
      CalculateSL_TP(ORDER_TYPE_SELL, priceData[0].close, stopLossPrice, priceTakeProfit);
   }

   double DerGeldMann = geldMann;
   if (Geldmann_type ==  GELD) {
      DerGeldMann = convertTOLots(DerGeldMann, 100);
   }
   if (Geldmann_type ==  GELD_LOT_1) {
      DerGeldMann = convertTOLots(DerGeldMann, 1);
   }

   if (signal == SHORT) {
      string comment = buildCommentString(EAName, totalTrades);
      printf("TradeNewMann Open SHORT: signal %d Price %.4f Bid %.4f Ask %.4f", signal, priceData[0].close, Bid, Ask);
      if(!trade.Sell(DerGeldMann, TradeOnSymbol, 0, stopLossPrice, priceTakeProfit, comment)) {
         Print("Sell() method failed. Return code=",trade.ResultRetcode(),
               ". Code description: ",trade.ResultRetcodeDescription());
      }
      else {
         Print("Sell() method executed successfully. Return code=",trade.ResultRetcode(),
               " (",trade.ResultRetcodeDescription(),")");
      }
      onGoingTrade = SHORT;
      tradeOnCandle = true;
      timeLastTrade = timeStampCurrentCandle;
   }

   if (signal == LONG) {
      string comment = buildCommentString(EAName, totalTrades);
      printf("TradeNewMann Open LONG: signal %d Price %.4f Bid %.4f Ask %.4f", signal, priceData[0].close, Bid, Ask);
      if(!trade.Buy(DerGeldMann, TradeOnSymbol, 0, stopLossPrice, priceTakeProfit, comment)) {
         Print("Buy() method failed. Return code=",trade.ResultRetcode(),
               ". Code description: ",trade.ResultRetcodeDescription());
      }
      else {
         Print("Buy() method executed successfully. Return code=",trade.ResultRetcode(),
               " (",trade.ResultRetcodeDescription(),")");
      }
      onGoingTrade = LONG;
      tradeOnCandle = true;
      timeLastTrade = timeStampCurrentCandle;
   }
}

//+------------------------------------------------------------------+
void TradeMannStopLimit(double TradePrice = EMPTY_VALUE, ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY)
{
  
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   
   hourMinuteNow = (now.hour * 60) + now.min;
   
   /* Time not to trade */
   if ( hourMinuteNow < startTime || hourMinuteNow > stopTime || hourMinuteNow > stopTrade) {
      Profit = 0;
      if (returnAllPositions() > 0 && inDayTrade == true) { // trade open and daytrade mode, stop all when end of the day
         closeAllPositions(ENDOFTHEDAY);
         totalTrades = 0;
         onGoingTrade = NOTRADE;
      }
      if (returnTotalPendingOrder() > 0) {
         removeOrders(ORDER_TYPE_SELL_LIMIT); 
         removeOrders(ORDER_TYPE_BUY_LIMIT); 
         removeOrders(ORDER_TYPE_BUY_STOP); 
         removeOrders(ORDER_TYPE_SELL_STOP); 
      }
      return;
   }

   /* order  already set */
   if (returnTotalPendingOrderbyType(order_type) > 0) {
      return;
   }
   
   /* Time current candle */
   timeStampCurrentCandle = priceData[0].time;
  
   if (MaxTradesDaily > 0 && totalTrades >= MaxTradesDaily) {
      return;
   }
   /* Max hours and minutes to start trades */
   if (maxDailyLoss > 0 && Profit < 0) {
      return;
   }
   if (maxDailyProfit > 0 && Profit >= maxDailyProfit) {
      return;
   }

   Profit = closedProfitPeriod();
   totalPosisions = returnAllPositions();
  
   double DerGeldMann = geldMann;
   if (Geldmann_type ==  GELD) {
      DerGeldMann = convertTOLots(DerGeldMann, 100);
   }
   if (Geldmann_type ==  GELD_LOT_1) {
      DerGeldMann = convertTOLots(DerGeldMann, 1);
   }
   
   /* Trade already happened on this candle */
   if (tradeOnCandle == true) {
      return;
   }
   
   string comment = buildCommentString(EAName, totalTrades);

   double stopLossPrice = 0;
   double priceTakeProfit = 0;
   CalculateSL_TP(order_type, TradePrice, stopLossPrice, priceTakeProfit);
   
   FixPriceOnSymbol(TradePrice);
   if (order_type == ORDER_TYPE_SELL_LIMIT) {
      if(!trade.SellLimit(DerGeldMann, TradePrice, TradeOnSymbol, stopLossPrice, priceTakeProfit, ORDER_TIME_GTC, 0, comment)) {
         Print("SellLimit() method failed. Return code=",trade.ResultRetcode(),
               ". Code description: ",trade.ResultRetcodeDescription());
      }
      else {
         Print("SellLimit() method executed successfully. Return code=",trade.ResultRetcode(),
               " (",trade.ResultRetcodeDescription(),")");
      }
   }
   if (order_type == ORDER_TYPE_SELL_STOP) {
      if(!trade.SellStop(DerGeldMann, TradePrice, TradeOnSymbol, stopLossPrice, priceTakeProfit, ORDER_TIME_GTC, 0, comment)) {
         Print("SellStop() method failed. Return code=",trade.ResultRetcode(),
               ". Code description: ",trade.ResultRetcodeDescription());
      }
      else {
         Print("SellStop() method executed successfully. Return code=",trade.ResultRetcode(),
               " (",trade.ResultRetcodeDescription(),")");
      }
   }
   if (order_type == ORDER_TYPE_BUY_LIMIT) {
      if(!trade.BuyLimit(DerGeldMann, TradePrice, TradeOnSymbol, stopLossPrice, priceTakeProfit, ORDER_TIME_GTC, 0, comment)) {
         Print("SellLimit() method failed. Return code=",trade.ResultRetcode(),
               ". Code description: ",trade.ResultRetcodeDescription());
      }
      else {
         Print("BuyLimit() method executed successfully. Return code=",trade.ResultRetcode(),
               " (",trade.ResultRetcodeDescription(),")");
      }
   }
   if (order_type == ORDER_TYPE_BUY_STOP) {
      if(!trade.BuyStop(DerGeldMann, TradePrice, TradeOnSymbol, stopLossPrice, priceTakeProfit, ORDER_TIME_GTC, 0, comment)) {
         Print("SellLimit() method failed. Return code=",trade.ResultRetcode(),
               ". Code description: ",trade.ResultRetcodeDescription());
      }
      else {
         Print("BuyStop() method executed successfully. Return code=",trade.ResultRetcode(),
               " (",trade.ResultRetcodeDescription(),")");
      }
   }   

   //tradeOnCandle = true;
   timeLastTrade = timeStampCurrentCandle;
}

void CalculateSL_TP(ENUM_ORDER_TYPE order_type, double TradePrice, double &stopLossPrice, double &priceTakeProfit)
{
   ENUM_POSITION_TYPE position_type = 0;

   /* Calculate SL and TP for BUY orders */
   if (order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_BUY_STOP ||
       order_type == ORDER_TYPE_BUY_STOP_LIMIT || order_type == ORDER_TYPE_BUY) {
       
      position_type = POSITION_TYPE_BUY;
   }
   else if (order_type == ORDER_TYPE_SELL_LIMIT || order_type == ORDER_TYPE_SELL_STOP ||
            order_type == ORDER_TYPE_SELL_STOP_LIMIT || order_type == ORDER_TYPE_SELL) {
      position_type = POSITION_TYPE_SELL;
   }

   /* Stop Loss */
   if (stopLoss > 0) {
      if (TradePrice != EMPTY_VALUE) {
         stopLossPrice = calculateStopLoss(TradePrice, stopLoss, position_type, AdjustByType);
      }
   }
   else {
      if (PositionStopLoss == EMPTY_VALUE)
         stopLossPrice = 0;
      else
         stopLossPrice = PositionStopLoss;
   }
   
   /* Take Profit */
   if (takeProfit > 0) {
      if (TradePrice != EMPTY_VALUE) {
         priceTakeProfit = calculateStopGain(TradePrice, 0, takeProfit, position_type, AdjustByType);
      }
   }
   else {
      if (PositionTakeProfit == EMPTY_VALUE)
         priceTakeProfit = 0;
      else
         priceTakeProfit = PositionTakeProfit;
   }
}


//+------------------------------------------------------------------+
void TradeMann(int signal, int signal_exit, double TradePrice = EMPTY_VALUE)
{

   double Ask = NormalizeDouble(SymbolInfoDouble(TradeOnSymbol,SYMBOL_ASK), _Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(TradeOnSymbol,SYMBOL_BID), _Digits);
   
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   
   /* Time current candle */
   timeStampCurrentCandle = priceData[0].time;
   
   totalPosisions = returnAllPositions();
   Profit = closedProfitPeriod();
   
   if (MaxTradesDaily > 0 && totalTrades >= MaxTradesDaily) {
      signal = NOTRADE;
   }

   hourMinuteNow = (now.hour * 60) + now.min;
   
   /* Max hours and minutes to start trades */
   if (hourMinuteNow > stopTrade) {
      signal =  NOTRADE;
   }
   /* Time not to trade */
   if ( hourMinuteNow < startTime || hourMinuteNow > stopTime) {
      signal =  NOTRADE;
      Profit = 0;
      if (returnAllPositions() > 0 && inDayTrade == true) { // trade open and daytrade mode, stop all when end of the day
         //printf("%s End of the day close all trades - Total trades %d", _Symbol, totalTrades);
         closeAllPositions(ENDOFTHEDAY);
         totalTrades = 0;
         onGoingTrade = NOTRADE;
      }
      if (returnTotalPendingOrder() > 0) {
         removeOrders(ORDER_TYPE_SELL_LIMIT); 
         removeOrders(ORDER_TYPE_BUY_LIMIT); 
         removeOrders(ORDER_TYPE_BUY_STOP); 
         removeOrders(ORDER_TYPE_SELL_STOP); 
      }
   }

   if (maxDailyLoss > 0 && Profit < 0) {
      double auxProfit = Profit * -1;
      if (auxProfit > maxDailyLoss) {
         closeAllPositions(MAXDAILYLOSS);
         signal =  NOTRADE;
      }
   }
   if (maxDailyProfit > 0 && Profit >= maxDailyProfit) {
      closeAllPositions(MAXDAILYPROFIT);
      signal =  NOTRADE;
   }

   // checkDayHasChanged();
   
   if (Bid > Ask) { // pre-market or leilao
      printf("Pre market detected: signal %d Price %.4f Bid %.4f Ask %.4f", signal, priceData[0].close, Bid, Ask);
      Sleep(5000); // sleep 1 minuto to avoid high loads
      return;
   }

   if (totalPosisions > 0 && onGoingTrade == LONG && signal_exit == SHORT) {
      closeAllPositions(SIGNAL);
      onGoingTrade = NOTRADE;
      timestampToWait =  TimeCurrent() + timeToSleep;
      if (last_signal == LONG) {
         tradeOnCandle = true;
         timeLastTrade = priceData[0].time;
      }
      Print("Close LONG: signal ",signal," signal_exit ",signal_exit, " last_signal ", last_signal," tradeOnCandle ", tradeOnCandle, " timeLastTrade ", priceData[0].time);
   }
   else if (totalPosisions>0  && onGoingTrade == SHORT && signal_exit == LONG) {
      closeAllPositions(SIGNAL);
      onGoingTrade = NOTRADE;
      timestampToWait =  TimeCurrent() + timeToSleep;
      if (last_signal == SHORT) {
         tradeOnCandle = true;
         timeLastTrade = priceData[0].time;
      }
      Print("Close LONG: signal ",signal," signal_exit ",signal_exit, " last_signal ", last_signal, " tradeOnCandle ", tradeOnCandle, " timeLastTrade ", priceData[0].time);
   }
   Profit = closedProfitPeriod();
   
   if (totalPosisions == 0 && (stopLossAdjusted > 0 || onGoingTrade != NOTRADE)) { // stop was adjusted and trade ended, go to sleep
      onGoingTrade = NOTRADE;
      stopLossAdjusted = 0;
      timestampToWait =  TimeCurrent() + timeToSleep;
   }
   
   /* If a stop loss has ocurred, EA donot trade for timeToSleep seconds */
   if (timestampToWait > 0 && timestampToWait > timeNow) {
      signal =  NOTRADE;
   }
   else {
      timestampToWait = 0;
   }

   if (tradeOnCandle == true && (last_signal == signal)) {
      signal = NOTRADE;
   }

   totalPosisions = returnAllPositions() + returnTotalPendingOrder();
   if (totalPosisions == 0) {
      TrailingStopON = false;
   }
   if (totalPosisions == 0 && (signal == SHORT || signal == LONG) ) {
   
      if (ATRHandle != INVALID_HANDLE) {
         ATROpenedTrade = ATRValue[1];
      }
      
      double DerGeldMann = geldMann;
      if (Geldmann_type ==  GELD) {
         DerGeldMann = convertTOLots(DerGeldMann, 100);
      }
      if (Geldmann_type ==  GELD_LOT_1) {
         DerGeldMann = convertTOLots(DerGeldMann, 1);
      }
      
      if (signal == SHORT) {
         string comment = buildCommentString(EAName, totalTrades);
         printf("Open SHORT: signal %d Price %.4f Bid %.4f Ask %.4f", signal, priceData[0].close, Bid, Ask);
         double stopLossPrice = 0;
         double priceTakeProfit = 0;
         if (stopLoss > 0) {
            if (TradePrice != EMPTY_VALUE) {
               stopLossPrice = calculateStopLoss(TradePrice, stopLoss, POSITION_TYPE_SELL, AdjustByType);
            }
            else {
               stopLossPrice = calculateStopLoss(priceData[0].close, stopLoss, POSITION_TYPE_SELL, AdjustByType);
            }
          }

         if (takeProfit > 0) {
            if (TradePrice != EMPTY_VALUE) {
               priceTakeProfit = calculateStopGain(TradePrice, 0, takeProfit, POSITION_TYPE_SELL, AdjustByType);
            }
            else {
               priceTakeProfit = calculateStopGain(priceData[0].close, 0, takeProfit, POSITION_TYPE_SELL, AdjustByType);
            }
         }
         if (TradePrice == EMPTY_VALUE) {
            if(!trade.Sell(DerGeldMann, TradeOnSymbol, 0, stopLossPrice, priceTakeProfit, comment)) {
               Print("Sell() method failed. Return code=",trade.ResultRetcode(),
                     ". Code description: ",trade.ResultRetcodeDescription());
            }
            else {
               Print("Sell() method executed successfully. Return code=",trade.ResultRetcode(),
                     " (",trade.ResultRetcodeDescription(),")");
            }
         }
         else {
            FixPriceOnSymbol(TradePrice);
            if(!trade.Sell(DerGeldMann, TradeOnSymbol, TradePrice, stopLossPrice, priceTakeProfit, comment)) {
               Print("Sell() method failed. Return code=",trade.ResultRetcode(),
                     ". Code description: ",trade.ResultRetcodeDescription());
            }
            else {
               Print("Sell() method executed successfully. Return code=",trade.ResultRetcode(),
                     " (",trade.ResultRetcodeDescription(),")");
            }
         }
         onGoingTrade = signal;
         tradeOnCandle = true;
         last_signal = signal;
         timeLastTrade = timeStampCurrentCandle;
      }
      if (signal == LONG) {
         string comment = buildCommentString(EAName, totalTrades);
         double stopLossPrice = 0;
         if (stopLoss > 0) {
            if (TradePrice != EMPTY_VALUE) {
               stopLossPrice = calculateStopLoss(TradePrice, stopLoss, POSITION_TYPE_BUY, AdjustByType);
            }
            else {
               stopLossPrice = calculateStopLoss(priceData[0].close, stopLoss, POSITION_TYPE_BUY, AdjustByType);
            }
         }
         double priceTakeProfit = 0;
         if (takeProfit > 0) {
            if (TradePrice != EMPTY_VALUE) {
               priceTakeProfit = calculateStopGain(TradePrice, 0, takeProfit, POSITION_TYPE_BUY, AdjustByType);
            }
            else {
               priceTakeProfit = calculateStopGain(priceData[0].close, 0, takeProfit, POSITION_TYPE_BUY, AdjustByType);
            }
         }
         if (TradePrice == EMPTY_VALUE) {
            if(!trade.Buy(DerGeldMann, TradeOnSymbol, 0, stopLossPrice, priceTakeProfit, comment)) {
               Print("Buy() method failed. Return code=",trade.ResultRetcode(),
                     ". Code description: ",trade.ResultRetcodeDescription());
            }
            else {
               Print("Buy() method executed successfully. Return code=",trade.ResultRetcode(),
                     " (",trade.ResultRetcodeDescription(),")");
            }
            tradeOnCandle = true;
         }
         else {
            FixPriceOnSymbol(TradePrice);
            if(!trade.Buy(DerGeldMann, TradeOnSymbol, TradePrice, stopLossPrice, priceTakeProfit, comment)) {
               Print("Buy() method failed. Return code=",trade.ResultRetcode(),
                     ". Code description: ",trade.ResultRetcodeDescription());
            }
            else {
               Print("Buy() method executed successfully. Return code=",trade.ResultRetcode(),
                     " (",trade.ResultRetcodeDescription(),")");
            }
            tradeOnCandle = true;
         }
         onGoingTrade = signal;
         last_signal = signal;
         timeLastTrade = timeStampCurrentCandle;
         tradeOnCandle = true;
      }

      totalPosisions++;
   }
   totalPosisions = returnAllPositions();
   
   if (totalPosisions > 0) {
      adjustStopLoss(AdjustByType);
      tradeArmed = true;
   }
}

/* Return Highest and Lowest value for price */
int SetHighLowPriceCandles(int candles, int startOn, ENUM_TIMEFRAMES TimeframeCandle, int CandleShift = 0)
{
   int candleIndex = -1, count = 0;
   getPositionOpen();
   
   LowestPrice = EMPTY_VALUE;
   
   candleIndex = iHighest(TradeOnSymbol, TimeframeCandle, MODE_HIGH, candles + CandleShift, startOn + CandleShift);
   if(candleIndex != -1)  {
      HighestPrice = NormalizeDouble(iHigh(TradeOnSymbol, TimeframeCandle, candleIndex), _Digits);
      count++;
   }
   candleIndex = iLowest(TradeOnSymbol, TimeframeCandle, MODE_LOW, candles + CandleShift , startOn + CandleShift);
   if(candleIndex != -1)  {
      LowestPrice = NormalizeDouble(iLow(TradeOnSymbol, TimeframeCandle, candleIndex), _Digits);
      count++;
   }
   
   candleIndex = iHighest(TradeOnSymbol, TimeframeCandle, MODE_CLOSE, candles + CandleShift , startOn + CandleShift);
   if(candleIndex != -1)  {
      HighestClosePrice = NormalizeDouble(iHigh(TradeOnSymbol, TimeframeCandle, candleIndex), _Digits);
      count++;
   }
   candleIndex = iLowest(TradeOnSymbol, TimeframeCandle, MODE_CLOSE, candles + CandleShift , startOn + CandleShift);
   if(candleIndex != -1)  {
      LowestClosePrice = NormalizeDouble(iLow(TradeOnSymbol, TimeframeCandle, candleIndex), _Digits);
      count++;
   }
   
   if (TickSize > 0) {
      HighestPrice = MathRound(HighestPrice/TickSize)*TickSize;
      LowestPrice = MathRound(LowestPrice/TickSize)*TickSize;
      HighestClosePrice = MathRound(HighestClosePrice/TickSize)*TickSize;
      LowestClosePrice = MathRound(LowestClosePrice/TickSize)*TickSize;
   }

   return(count);
}

double convertTOLots(double valueToTrade, int lotSize = 100)
{
   double totalLots = 0;
   totalLots = MathRound(valueToTrade/priceData[0].close/lotSize)*lotSize;
   if (totalLots < lotSize) {
      totalLots = lotSize;
   }

   return totalLots;
}

bool checkDayHasChanged()
{
   TimeToStruct(TimeCurrent(),now);
   
   if (now.day != todayIs && inDayTrade == true) { // reset tradeArmed
      todayIs = now.day;
      tradeArmed = false;
      tradeOnCandle = false;
      return true;
      
   }
   return false;
}


void drawLine(string name, double price, const color clr = clrRed)
{
   long chart_ID = ChartID();
   
   removeLine(name);

   ObjectDelete(chart_ID, name);
   ResetLastError();
   if(!ObjectCreate(chart_ID, name, OBJ_HLINE, 0, 0, price) || GetLastError()!=0)
      Print("Error creating object: ",GetLastError());
   else
      ChartRedraw(chart_ID);

   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH, 1);
   
   LineIsDrawn = true;

}

void removeLine(string name)
{
   long cid = ChartID();
   double bid = SymbolInfoDouble(Symbol(),SYMBOL_BID);

   ObjectDelete(cid, name);
   ResetLastError();
   
}

double returnVariance(ENUM_TIMEFRAMES varTimeframe, int howLongInThePast) {
   
   MqlRates RFPrice[]; // array to keep the current and last candle
   ArraySetAsSeries(RFPrice, true);
   int CandlesToCalc = CopyRates(_Symbol, varTimeframe, 0, howLongInThePast+1, RFPrice);

   long candle;
   double Variance = 0;
   
   //MqlDateTime str1; 
   for(candle = (CandlesToCalc-1);candle > 0; candle--) {
      //Print("Candle ", candle);
      //Variance += (double)(RFPrice[candle-1].close / RFPrice[candle].close - 1) * 100;
      /*
      TimeToStruct(RFPrice[candle].time,str1); 
      string neoson = "FR -> ";
      StringAdd(neoson, IntegerToString(str1.day));
      StringAdd(neoson, ".");
      StringAdd(neoson, IntegerToString(str1.mon));
      StringAdd(neoson, ".");
      StringAdd(neoson, IntegerToString(str1.year));
      StringAdd(neoson, " ");
      StringAdd(neoson, DoubleToString(Var1m ,2));
      StringAdd(neoson, "%");
      Print(neoson);
      // StringAdd(neoson, "% | ");*/
      //Print("neoson");
   }
   Variance = Variance / howLongInThePast;
   return (Variance);
 }
 
string GetSymbolDetails(string Symbol) {
   string symbolDetails;

   StringAdd(symbolDetails, SymbolInfoString(Symbol, SYMBOL_DESCRIPTION));
   StringAdd(symbolDetails, ",");
   StringAdd(symbolDetails, SymbolInfoString(Symbol, SYMBOL_CATEGORY));
   StringAdd(symbolDetails, ",");
   StringAdd(symbolDetails, SymbolInfoString(Symbol, SYMBOL_BASIS));
   StringAdd(symbolDetails, ",");
   StringAdd(symbolDetails, SymbolInfoString(Symbol, SYMBOL_SECTOR_NAME));
   StringAdd(symbolDetails, ",");
   StringAdd(symbolDetails, SymbolInfoString(Symbol, SYMBOL_INDUSTRY_NAME));
   StringAdd(symbolDetails, ",");
   StringAdd(symbolDetails, SymbolInfoString(Symbol, SYMBOL_EXCHANGE));
   
   return symbolDetails;
}

bool returnBestIndiceSymbol(string symbolBase, Symbol_Choice_Filter_Type ChoiceType, SymbolInfo &SymbolToTrade)
{
   string Alphabet[26] = {"A", "B", "C", "D", "E", "F", "G",
                          "H", "I", "J", "K", "L", "M", "N",
                          "O", "P", "Q", "R", "S", "T", "U",
                          "V", "Y", "W", "X", "Z"};
   int symbol_index = 0;
   bool is_custom;
   SymbolInfo SymbolsInfo[], BaseSymbol, auxSymbolInfo, choseSymbol;
   MqlDateTime str1;
   
   GlobalSymbolsList = "";
   
   /* Get price and volume for the base symbol */
   if (SymbolExist(symbolBase, is_custom) == true) {
      BaseSymbol.symbolName = symbolBase;
      if (!getSymbolValues(BaseSymbol)) {
         Print("Symbol ",symbolBase," - cound not get quote");
         return false;
      }
      //Print("Base symbol ",BaseSymbol.symbolName, " Price ", BaseSymbol.Price, " Volume ", BaseSymbol.Volume);
      StringAdd(GlobalSymbolsList,StringFormat("\n\n   Base symbol %s - Price %0.2f - Volume %0.2f\n\n",
                                     BaseSymbol.symbolName, BaseSymbol.Price, BaseSymbol.Volume)
                );
   }
   else {
      Print("Symbol ",symbolBase," does not exists");
      return false;
   }
   
   ArrayResize(SymbolsInfo, 10, 0);
   
   int totalChars = ArraySize(Alphabet);
  
   MqlDateTime stm;
   TimeToStruct(TimeCurrent(), stm);
   
   datetime NewestSymbol = 0;   
   double valueDifference = EMPTY_VALUE;
   double priceD = EMPTY_VALUE;
   for(int i = (stm.year - 1); i <= (stm.year+1); i = i + 1) {
      for (int AIndex = 0; AIndex<ArraySize(Alphabet); AIndex++) {
      
         /* Remove $ or @ char to get base symbol */
         string newSymbol = StringSubstr(BaseSymbol.symbolName, 0, 3);
   
         StringAdd(newSymbol, Alphabet[AIndex]);
         StringAdd(newSymbol, returnYearLast2Digits(i));
         
         if (SymbolExist(newSymbol, is_custom) == true) {
            auxSymbolInfo.symbolName = newSymbol;
            /* Symbol has a quote and do not expire today */
            if (getSymbolValues(auxSymbolInfo) && CheckSymbolExpiresToday(auxSymbolInfo) == false) {
               ArrayResize(SymbolsInfo, ArraySize(SymbolsInfo) + 1, 0);
               SymbolsInfo[symbol_index] = auxSymbolInfo;

               //Print("Analysing Symbol ",SymbolsInfo[symbol_index].symbolName, " Price ", SymbolsInfo[symbol_index].Price, " Volume ", SymbolsInfo[symbol_index].Volume);
               TimeToStruct(SymbolsInfo[symbol_index].expireDatetime,str1);
               StringAdd(GlobalSymbolsList,StringFormat("   %s - Expire %02d.%02d.%4d - Price %0.2f - Volume %0.2f\n",
                                     SymbolsInfo[symbol_index].symbolName,str1.day,str1.mon, str1.year,SymbolsInfo[symbol_index].Price, SymbolsInfo[symbol_index].Volume)
                );               

               if (ChoiceType == NEWEST) {
                  if (NewestSymbol == 0) {
                     choseSymbol = SymbolsInfo[symbol_index];
                     NewestSymbol = SymbolsInfo[symbol_index].expireDatetime;
                  }
                  else if (SymbolsInfo[symbol_index].expireDatetime < NewestSymbol) {
                     choseSymbol = SymbolsInfo[symbol_index];
                     NewestSymbol = SymbolsInfo[symbol_index].expireDatetime;
                  }
               }
               else if (ChoiceType == PRICE || ChoiceType == VOLUME) {
                  /* Chosse closest price */
                  if (ChoiceType == PRICE) {
                     priceD = BaseSymbol.todayPrice - SymbolsInfo[symbol_index].todayPrice; 
                  }
                  if (ChoiceType == VOLUME) {
                     priceD = (double)BaseSymbol.Volume - SymbolsInfo[symbol_index].Volume; 
                  }
                  if (priceD < 0) {
                     priceD = priceD * -1;
                  }
                  if (valueDifference == EMPTY_VALUE) {
                     choseSymbol = SymbolsInfo[symbol_index];
                     valueDifference = priceD;
                  }
                  else if (priceD < valueDifference) {
                     choseSymbol = SymbolsInfo[symbol_index];
                     valueDifference = priceD;
                  }
               }

               symbol_index++;
            }
         }
      }
   }
   string choseMethod = "";
   if (ChoiceType == NEWEST) {
      //Print("Symbol chose by NEWEST ", choseSymbol.symbolName);
      choseMethod = "NEWEST";
   }
   else if (ChoiceType == PRICE) {
      //Print("Symbol chose by PRICE ", choseSymbol.symbolName);
      choseMethod = "PRICE";
   }
   else if (ChoiceType == VOLUME) {
      //Print("Symbol chose by VOLUME ", choseSymbol.symbolName);
      choseMethod = "VOLUME";
   }
   StringAdd(GlobalSymbolsList,StringFormat("\n   Selected symbol %s by %s - Price %0.2f - Volume %0.2f\n",
               choseSymbol.symbolName, choseMethod, choseSymbol.Price, choseSymbol.Volume)
   );
   SymbolToTrade = choseSymbol;
   return true;
}

bool getSymbolValues(SymbolInfo &sInfo)  {
   MqlRates priceToday[]; // array to keep the current and last candle
   int total_candles = 0;

   ArraySetAsSeries(priceToday, true);
   total_candles = CopyRates(sInfo.symbolName, PERIOD_D1, 0, 2, priceToday);   
   if (total_candles < 2) {
      return false;
   }
   else {
      sInfo.Price = priceToday[1].close;
      sInfo.Volume = priceToday[1].real_volume;
      sInfo.todayPrice = priceToday[0].close;
      sInfo.expireDatetime = (datetime)SymbolInfoInteger(sInfo.symbolName,SYMBOL_EXPIRATION_TIME);
   }
   return true;
}

bool CheckSymbolExpiresToday(SymbolInfo &sInfo)
{
   datetime current = TimeCurrent();
   MqlDateTime DateTimeNow ,DateTimeSymbol;

   TimeToStruct(current, DateTimeNow); 
   TimeToStruct(sInfo.expireDatetime, DateTimeSymbol);
   
   if ( DateTimeNow.year ==  DateTimeSymbol.year && 
        DateTimeNow.mon ==  DateTimeSymbol.mon && 
        DateTimeNow.day ==  DateTimeSymbol.day) {
        
        printf("Symbol %s expires today - %s - no more trading on it.",sInfo.symbolName,TimeToString(sInfo.expireDatetime));
        return true;
   }
   
   if ( sInfo.expireDatetime < current) {
        
        //printf("Symbol %s expired - %s - no more trading on it.",sInfo.symbolName,TimeToString(sInfo.expireDatetime));
        return true;
   }   
   
   return false;
}

datetime TimeSymbolToExpires(SymbolInfo &sInfo)
{
   datetime howLongToExpire = sInfo.expireDatetime - TimeCurrent();
   
   return howLongToExpire;
}


string returnYearLast2Digits(int year)
{
   string YearDigits = IntegerToString(year);
   YearDigits = StringSubstr(YearDigits, 2);
   
   return(YearDigits);
}

void setComment()
{
   string commentAux;
   
   if (PositionPrice == EMPTY_VALUE) {   
      commentAux = StringFormat("%s Magic number: %ld Symbol to trade %s - Total trades: %ld - signal %d - signal_exit %d - onGoingTrade %d - tradeOnCandle %d - PositionPrice NoPosition - PositionCandlePosition %d\n\n",EAName, MyMagicNumber,TradeOnSymbol,totalTrades, trade_signal, trade_signal_exit, onGoingTrade, tradeOnCandle,PositionCandlePosition);
   }
   else {
      commentAux = StringFormat("%s Magic number: %ld Symbol to trade %s - Total trades: %ld - signal %d - signal_exit %d - onGoingTrade %d - tradeOnCandle %d - PositionPrice %0.2f - PositionCandlePosition %d\n\n",EAName, MyMagicNumber,TradeOnSymbol,totalTrades, trade_signal, trade_signal_exit, onGoingTrade, tradeOnCandle, PositionPrice, PositionCandlePosition);
   }
   StringAdd(commentAux, GlobalSymbolsList);               

   Comment(commentAux);
}

/* return true if symbol changed and indicators must be reloaded  */
bool CheckAutoRollingSymbol()
{

   bool tradeSymbolChanged = false;
   
   if (MQLInfoInteger(MQL_TESTER) || UseAutomaticSymbolRolling == INPUT_NO) {
      /* Time current candle */
      timeStampCurrentCandle = priceData[0].time;

      TradeOnSymbol = _Symbol;
      tradeSymbolChanged = false;
      
      setComment();
      
      return tradeSymbolChanged;
   }
   
   bool tradeSymbolFound = true;
   /* Automatic symbol change on price, volume or expired */
   if (UseAutomaticSymbolRolling == INPUT_YES) {
      if ( (StringFind(TradeOnSymbol, "$", 0) > 0) && (StringFind(TradeOnSymbol, "@", 0) > 0) ) {
         TradeOnSymbol = "";
      }
      if (TradeOnSymbol == "" || timeStampCurrentCandle < priceData[0].time) { // once each new candle
         tradeSymbolFound = false;
         while (!tradeSymbolFound) {
            if (returnBestIndiceSymbol(_Symbol, RollingMethod,TradeOnSymbolDetected)) {

               TradeOnSymbol = TradeOnSymbolDetected.symbolName;
               //Print("Symbol to trade ", TradeOnSymbolDetected.symbolName," - TradeOnLastSymbol ", TradeOnLastSymbol);

               /* Check if symbol changed */
               if (TradeOnLastSymbol != TradeOnSymbol) {
                  tradeSymbolChanged = true;
                  TradeOnLastSymbol = TradeOnSymbol;
               }

               CheckAndChangeBaseSymbol(TradeOnSymbol);
               tradeSymbolFound = true;
            }
            else {
               Print("Trade symbol not found, retrying in 1s");
               Sleep(1000);
            }
         }
      }
   }

   /* Time current candle */
   timeStampCurrentCandle = priceData[0].time;
   
   setComment();
   
   return tradeSymbolChanged;
}

bool ChartCommentGet(string &result,const long chart_ID=0) 
 { 
   ResetLastError(); 
   //--- receive the property value 
   if(!ChartGetString(chart_ID,CHART_COMMENT,result)) { 
      //--- display the error message in Experts journal 
      Print(__FUNCTION__+", Error Code = ",GetLastError()); 
      return(false); 
   } 
   return(true); 
}