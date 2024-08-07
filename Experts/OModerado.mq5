
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 11220;
/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>


input  group             "MM Weighted High"
input int MMWeightedHighPeriod = 17;
int MMWeightedHighHandle = -1;
double MMWeightedHigh[];

input  group             "MM Weighted Low"
input int MMWeightedLowPeriod = 17;
int MMWeightedLowHandle = -1;
double MMWeightedLow[];

input  group             "EMA Fast"
input int EMAFastPeriod = 10;
int EMAFastHandle = -1;
double EMAFast[];

input  group             "MM Slow"
input int EMASlowPeriod = 100;
int EMASlowHandle = -1;
double EMASlow[];

input  group             "MM Low"
input int EMALongPeriod = 200;
int EMALongHandle = -1;
double EMALong[];

input  group             "Entry and exit"
input double percentageToEnter = 1;
input double percentageToExit = 0.5;

int OnInit(void)
  {
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   MMWeightedHighHandle = iMA(_Symbol,chartTimeframe,MMWeightedHighPeriod,0,MODE_LWMA, PRICE_HIGH);
   if (MMWeightedHighHandle < 0) {
      Print("Erro criando indicador MMWeightedHighHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(MMWeightedHighHandle);
   ArraySetAsSeries(MMWeightedHigh, true);
   
   MMWeightedLowHandle = iMA(_Symbol,chartTimeframe,MMWeightedLowPeriod,0,MODE_LWMA, PRICE_LOW);
   if (MMWeightedLowHandle < 0) {
      Print("Erro criando indicador MMWeightedLowHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(MMWeightedLowHandle);
   ArraySetAsSeries(MMWeightedLow, true);   
   
   
   EMAFastHandle = iMA(_Symbol,chartTimeframe,EMAFastPeriod,0,MODE_EMA, PRICE_CLOSE);
   if (EMAFastHandle < 0) {
      Print("Erro criando indicador EMAFastHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAFastHandle);
   ArraySetAsSeries(EMAFast, true);

   EMASlowHandle = iMA(_Symbol,chartTimeframe,EMASlowPeriod,0,MODE_EMA , PRICE_CLOSE);
   if (EMASlowHandle < 0) {
      Print("Erro criando indicador EMASlowHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMASlowHandle);
   ArraySetAsSeries(EMASlow, true);   
   
   EMALongHandle = iMA(_Symbol,chartTimeframe,EMALongPeriod,0,MODE_EMA , PRICE_LOW);
   if (EMALongHandle < 0) {
      Print("Erro criando indicador EMALongHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMALongHandle);
   ArraySetAsSeries(EMALong, true);      
  
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
   
   /* Time current candle */   
   timeStampCurrentCandle = priceData[0].time;
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(MMWeightedHighHandle, 0, 0, 3, MMWeightedHigh) < 0)   {
      Print("Erro copiando buffer do indicador MMWeightedHighHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(MMWeightedLowHandle, 0, 0, 3, MMWeightedLow) < 0)   {
      Print("Erro copiando buffer do indicador MMWeightedLowHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(EMAFastHandle, 0, 0, 3, EMAFast) < 0)   {
      Print("Erro copiando buffer do indicador EMAFastHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(EMASlowHandle, 0, 0, 3, EMASlow) < 0) {
      Print("Erro copiando buffer do indicador EMASlowHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(EMALongHandle, 0, 0, 3, EMALong) < 0) {
      Print("Erro copiando buffer do indicador EMALongHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
   }
   else if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice + (TakeProfitPrice * percentageToExit / 100);
   }
   else if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice - (TakeProfitPrice * percentageToExit / 100);
   }

   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE && EMASlow[1] > EMALong[1]) {
         if (priceData[1].close < MMWeightedLow[1]) {
            TradeEntryPrice = priceData[1].close - (priceData[1].close * percentageToEnter / 100);
            if (priceData[0].close < TradeEntryPrice) {
               signal = LONG;
            }
         }
      }
      if (onGoingTrade == LONG && priceData[0].close >= EMAFast[0]) {
         signal_exit = SHORT;
      }
      if (onGoingTrade == LONG && priceData[1].close >= TakeProfitPrice) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      if (onGoingTrade == NOTRADE && EMASlow[1] < EMALong[1]) {
         if (priceData[1].close > MMWeightedHigh[1]) {
            TradeEntryPrice = priceData[1].close + (priceData[1].close * percentageToEnter / 100);
            if (priceData[0].close > TradeEntryPrice) {
               signal = SHORT;
            }
         }
      }
      if (onGoingTrade == SHORT && priceData[0].close <= EMAFast[0]) {
         signal_exit = LONG;
      }
      if (onGoingTrade == SHORT && priceData[1].close <= TakeProfitPrice) {
         signal_exit = LONG;
      }
   }

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

   TradeMann(signal, signal_exit);
}
