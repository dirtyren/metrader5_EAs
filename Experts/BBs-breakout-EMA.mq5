
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "Bolinger Bands"
enum enMaTypes {
   ma_sma,    // Simple moving average
   ma_ema,    // Exponential moving average
   ma_smma,   // Smoothed MA
   ma_lwma    // Linear weighted MA
};
input int                 inpPeriods    = 20;           // Bollinger bands period
input double              inpDeviations = 2.0;          // Bollinger bands deviations
input enMaTypes           inpMaMethod   = ma_ema;       // Bands median average method
input ENUM_APPLIED_PRICE  inpPrice      = PRICE_CLOSE;  // Price
input int     InpBandsShift = 1;         // Shift

int bandsHandle = -1;
double meanVal[];      // Array dinamico para armazenar valores medios da banda de Bollinger
double upperVal[];     // Array dinamico para armazenar valores medios da banda superior
double lowerVal[];     // Array dinamico para armazenar valores medios da banda inferior


int OnInit(void)
  {
  
   EAVersion = "v3.2";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   bandsHandle = iCustom(_Symbol,chartTimeframe,"Bollinger bands - EMA deviation", inpPeriods, inpDeviations, inpMaMethod, inpPrice, InpBandsShift);
   if (bandsHandle == INVALID_HANDLE) {
      Print("Erro bandsHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(bandsHandle);
   ArraySetAsSeries(meanVal, true);
   ArraySetAsSeries(upperVal, true);
   ArraySetAsSeries(lowerVal, true);
   
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);

   int WFORockAndRoll = 0;
   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      // wfo_setCloseTradesOnSeparationLine(true); // false by default
     
      // this is the only required call in OnInit, all parameters come from the header
      WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);
   
      //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
      //wfo_setCustomPerformanceMeter(customEstimator);
   #endif 
   
   return(WFORockAndRoll);
  }
  
/* double OnTester()
{
   return optpr();         // optimization parameter
}
*/

void OnTesterInit()
{
   #ifdef WFO
      wfo_OnTesterInit(wfo_outputFile); // required
   #endif
}

void OnTesterDeinit()
{
   #ifdef WFO
      wfo_OnTesterDeinit(); // required
   #endif
}

void OnTesterPass()
{
   #ifdef WFO
      wfo_OnTesterPass(); // required
   #endif
}

double OnTester()
{
   if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
      return 0.0;
   }
   #ifdef WFO
      return wfo_OnTester(); // required
   #endif
   return 0.0;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   cleanUPIndicators();
}

void OnTick()
{

   #ifdef WFO
      int wfo = wfo_OnTick();
      if(wfo == -1)
      {
         // can do some non-trading stuff, such as gathering bar or ticks statistics
         return;
      }
      else if(wfo == +1)
      {
         // can do some non-trading stuff
         return;
      }
   #endif

   /* if day changes, reset filters to not trade is one was opened yesterday */
   checkDayHasChanged();
     
   /* Tick time for EA */
   TimeToStruct(TimeCurrent(),now);
   timeNow = TimeCurrent();
   
   ArraySetAsSeries(priceData, true);   
   CopyRates(_Symbol, chartTimeframe, 0, 3, priceData);

   /* Check candle changed and new trade is allowed to start */
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(bandsHandle, 8, 0, 3, meanVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(bandsHandle, 4, 0, 3, upperVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(bandsHandle, 6, 0, 3, lowerVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (MQLInfoInteger(MQL_TESTER)) {
   
      /* New candle detected, clean pending orders */
      if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == NOTRADE) {
         removeOrders(ORDER_TYPE_BUY_LIMIT);
         removeOrders(ORDER_TYPE_SELL_LIMIT);      
      }
   
      if (onGoingTrade != NOTRADE && PositionTakeProfit == 0) {
         if (onGoingTrade == LONG) {
            setTakeProfit(meanVal[0] + SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE));
         }
         if (onGoingTrade == SHORT) {
            setTakeProfit(meanVal[0] - SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE));
         }
      }
      if (priceData[0].time != timeStampCurrentCandle && onGoingTrade != NOTRADE) {
         if (onGoingTrade == LONG) {
            setTakeProfit(meanVal[0] + SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE));
         }
         if (onGoingTrade == SHORT) {
            setTakeProfit(meanVal[0] - SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE));
         }
      }   
   }
  
   onGoingTrade = checkPositionTypeOpen();
  
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   
   
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close < lowerVal[1]) {
            if (MQLInfoInteger(MQL_TESTER)) {
               if (priceData[0].open < priceData[1].low) {
                  signal = LONG;
               }
               if (priceData[0].open >= priceData[1].low) {
                  TradeMannStopLimit(priceData[1].low - SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE), ORDER_TYPE_BUY_LIMIT);
               }
            }
            else {
               if (priceData[0].close < priceData[1].low) {
                  signal = LONG;
               }
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (MQLInfoInteger(MQL_TESTER) == false) {
            if (priceData[0].close >= meanVal[0]) {
               signal_exit = SHORT;
            }
         }
         if (priceData[1].close > meanVal[1]) {
            signal_exit = SHORT;
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close > upperVal[1]) {
            if (MQLInfoInteger(MQL_TESTER)) {
               if (priceData[0].open > priceData[1].high) {
                  signal = SHORT;
               }
               if (priceData[0].open <= priceData[1].high) {
                  TradeMannStopLimit(priceData[1].high + SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE), ORDER_TYPE_SELL_LIMIT);
               }
            }
            else {
               if (priceData[0].close > priceData[1].high) {
                  signal = SHORT;
               }
            }
         }
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         if (MQLInfoInteger(MQL_TESTER) == false) {
            if (priceData[0].close <= meanVal[0]) {
               signal_exit = LONG;
            }
         }
         if (priceData[1].close < meanVal[1]) {
            signal_exit = LONG;
         }
      }
   }

   TradeMann(signal, signal_exit);

   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " Position Price ", PositionPrice, " PositionCandlePosition ", PositionCandlePosition);
}
