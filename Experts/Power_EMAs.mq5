
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = 11200;
/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "MM Fast"
input int EMAFastPeriod = 9;

input  group             "MM Middle"
input int EMASlowPeriod = 12;

input  group             "MM Long"
input int EMALongPeriod = 15;


int EMAFastHandle = -1;
double EMAFastBuffer[];
int EMASlowHandle = -1;
double EMASlowBuffer[];
int EMALongHandle = -1;
double EMALongBuffer[];

int OnInit(void)
  {

   EAVersion = "v1.1";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
  
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   EMAFastHandle = iMA(_Symbol,chartTimeframe,EMAFastPeriod,0,MODE_SMA, PRICE_CLOSE);
   if (EMAFastHandle < 0) {
      Print("Erro criando indicador EMAFastHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAFastHandle);
   ArraySetAsSeries(EMAFastBuffer, true);

   EMASlowHandle = iMA(_Symbol,chartTimeframe,EMASlowPeriod,0,MODE_SMA, PRICE_CLOSE);
   if (EMASlowHandle < 0) {
      Print("Erro criando indicador EMASlowHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMASlowHandle);
   ArraySetAsSeries(EMASlowBuffer, true);   
   
   EMALongHandle = iMA(_Symbol,chartTimeframe,EMALongPeriod,0,MODE_SMA, PRICE_CLOSE);
   if (EMALongHandle < 0) {
      Print("Erro criando indicador EMALongHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMALongHandle);
   ArraySetAsSeries(EMALongBuffer, true);   
  
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   //AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);
   int WFORockAndRoll = 0;
   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      wfo_setCloseTradesOnSeparationLine(false); // false by default
     
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
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(EMAFastHandle, 0, 0, 3, EMAFastBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAFastHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(EMASlowHandle, 0, 0, 3, EMASlowBuffer) < 0) {
      Print("Erro copiando buffer do indicador EMASlowHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(EMALongHandle, 0, 0, 3, EMALongBuffer) < 0) {
      Print("Erro copiando buffer do indicador EMALongHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   /* Check if symbol needs to be changed */
   CheckAutoRollingSymbol();   

   onGoingTrade = checkPositionTypeOpen();
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) { 
         if (priceData[1].close > EMALongBuffer[1]) { 
         if (EMAFastBuffer[1] > EMASlowBuffer[1] && EMAFastBuffer[2] < EMASlowBuffer[2]) {
               signal = LONG;
            }
         }
      }
      if (onGoingTrade == LONG) {
         if (EMAFastBuffer[1] < EMASlowBuffer[1]) {
            signal_exit = SHORT;
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (EMAFastBuffer[1] < EMASlowBuffer[1] && EMAFastBuffer[1] < EMALongBuffer[1] && priceData[1].close < EMAFastBuffer[1]) {
            if (EMASlowBuffer[1] < EMALongBuffer[1] && EMASlowBuffer[2] > EMALongBuffer[2]) {
               signal = SHORT;
            }
         }
      }
      if (onGoingTrade == SHORT && priceData[1].close > EMAFastBuffer[1]) {
      //if (onGoingTrade == SHORT && EMAFastBuffer[1] > EMASlowBuffer[1]) {
         signal_exit = LONG;
      }
   }

   TradeMann(signal, signal_exit);
   
   Comment("Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
