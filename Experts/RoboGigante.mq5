//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "Ichimuko"  
input int tenkan_sen = 9;
input int kijun_sen = 26;
input int senkou_span_b = 52;

int SpectramanHandle;
double Tenkensen[];
double Kijunsen[];
double SenkouspanA[];
double SenkouspanB[];
double Chikouspan[];

int OnInit(void)
  {
  
   EAVersion = "v1.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
  
   SpectramanHandle = iIchimoku(_Symbol, chartTimeframe, tenkan_sen, kijun_sen, senkou_span_b);
   if (SpectramanHandle < 0) {
      Print("Erro criando indicadore SpectramanHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(SpectramanHandle);
   ArraySetAsSeries(Tenkensen, true);
   ArraySetAsSeries(Kijunsen, true);
   ArraySetAsSeries(SenkouspanA, true);
   ArraySetAsSeries(SenkouspanB, true);
   ArraySetAsSeries(Chikouspan, true);
   
   /*ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 1);
   ArraySetAsSeries(ATRValue, true);*/

   /* Initialize reasl symbol if needed - load the indicators on it */
   CheckAutoRollingSymbol();
   //LoadIndicators();
   
   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      // wfo_setCloseTradesOnSeparationLine(true); // false by default
     
      // this is the only required call in OnInit, all parameters come from the header
      int WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);
   
      //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
      //wfo_setCustomPerformanceMeter(customEstimator);
      
      return(WFORockAndRoll);
   #endif
   return(0);
}
  
/* double OnTester()
{
   return optpr();         // optimization parameter
}
*/

double OnTester()
{
   if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
      return 0.0;
   }
   
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
   
   /* if day changes, reset filters to not trade is one was openedd yesterday */
   checkDayHasChanged();
     
   /* Tick time for EA */
   TimeToStruct(TimeCurrent(),now);
   timeNow = TimeCurrent();
   
   CopyRates(_Symbol, chartTimeframe, 0, 30, priceData);

   /* Time current candle */   
   timeStampCurrentCandle = priceData[0].time;
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(SpectramanHandle, 0, 0, 4, Tenkensen) < 0)   {
      Print("Erro copiando buffer do indicador SpectramanHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(SpectramanHandle, 1, 0, 4, Kijunsen) < 0)   {
      Print("Erro copiando buffer do indicador SpectramanHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(SpectramanHandle, 2, -kijun_sen, kijun_sen+2, SenkouspanA) < 0)   {
      Print("Erro copiando buffer do indicador SpectramanHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(SpectramanHandle, 3, -kijun_sen, kijun_sen+2  , SenkouspanB) < 0)   {
      Print("Erro copiando buffer do indicador SpectramanHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(SpectramanHandle, 4, kijun_sen, kijun_sen+2, Chikouspan) < 0)   {
      Print("Erro copiando buffer do indicador SpectramanHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   onGoingTrade = checkPositionTypeOpen();
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      if (SenkouspanA[1] > SenkouspanB[1] && // = nuvem pra cima
          Tenkensen[1] > Kijunsen[1] /*&& Tenkensen[2] < Kijunsen[2]*/ &&
          Chikouspan[1] > SenkouspanA[1] &&
          priceData[1].close > Tenkensen[1] &&
          priceData[1].close > Kijunsen[1]) {
          signal = LONG;
      }
      if (onGoingTrade == LONG && (Tenkensen[1] < Kijunsen[1])) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      if (SenkouspanA[1] < SenkouspanB[1] && // = nuvem pra cima
          Tenkensen[1] < Kijunsen[1] && /*Tenkensen[2] > Kijunsen[2] &&*/
          Chikouspan[1] < SenkouspanA[1] &&
          priceData[1].close < Tenkensen[1] &&
          priceData[1].close < Kijunsen[1]) {
          signal = SHORT;
      }
      if (onGoingTrade == SHORT && (Tenkensen[1] > Kijunsen[1])) {
         signal_exit = LONG;
      }
   }

   TradeMann(signal, signal_exit);
}
