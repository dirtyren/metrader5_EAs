
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = 40980;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

MqlRates priceDaily[];

input  group             "Distance"
input double entryExit = 1; // distance to enter and exit in %

int OnInit(void)
  {
   EAVersion = "v1.2";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   if (InitEA() == false) {
      return(INIT_FAILED);
   }

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
 
   MqlDateTime TimeCandle ;
   TimeToStruct(priceData[0].time,TimeCandle);

   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (timeStampCurrentCandle != priceData[0].time || TradeEntryPrice == EMPTY_VALUE) {
      ArraySetAsSeries(priceDaily, true);   
      CopyRates(_Symbol, PERIOD_D1, 0, 3, priceDaily);
      drawLine("LOW", priceDaily[1].low);
      TradeEntryPrice = priceDaily[1].low - (priceDaily[1].low * (entryExit / 100));
   }

   
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
   }
   else if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice + (PositionPrice * (entryExit / 100));
      setTakeProfit(TakeProfitPrice);
   }   
   

   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (TradeEntryPrice != EMPTY_VALUE && priceData[1].close < TradeEntryPrice) {
            signal = LONG;
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close >= TakeProfitPrice) {
            signal_exit = SHORT;
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
   }
   
   TradeMann(signal, signal_exit);

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
