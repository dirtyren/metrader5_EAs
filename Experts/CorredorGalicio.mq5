
//+------------------------------------------------------------------+
//| Functions by Invest Friends                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 40720;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input group "MM"
input int EMALongPeriod = 70;
int EMALongHandle = -1;
double EMALongBuffer[];

input group "Distance in points"
input int DistanceToEnter = 5;

int OnInit(void)
  {
  
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   EMALongHandle = iMA(_Symbol,chartTimeframe,EMALongPeriod,0,MODE_SMA , PRICE_LOW);
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
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);
   
   int WFORockAndRoll = 0;
   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      //wfo_setCloseTradesOnSeparationLine(true); // false by default
     
      // this is the only required call in OnInit, all parameters come from the header
      WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);
   
      //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
      //wfo_setCustomPerformanceMeter(customEstimator);
   #endif
   return(WFORockAndRoll);
}
  
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
   DeInitEA();
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

   /* Tick time for EA */
   TimeToStruct(TimeCurrent(),now);
   timeNow = TimeCurrent();
   
   /* Get price bars */
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

   if (CopyBuffer(EMALongHandle, 0, 0, 3, EMALongBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMALongHandle2 - error:", GetLastError());
      ResetLastError();
      return;
   }   

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   double UpLimit = priceData[1].high + DistanceToEnter;
   double LowLimit = priceData[1].low - DistanceToEnter;
   
   drawLine("High", UpLimit);   
   drawLine("Low", LowLimit);
   
   AskPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   BidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE && 
          priceData[1].close > EMALongBuffer[1] && AskPrice <= LowLimit && AskPrice > EMALongBuffer[0]) {
            signal = LONG;
      }

      /* Stops */
      if (onGoingTrade == LONG) {
         if (PositionCandlePosition > 0 && priceData[0].close > PositionPrice) {
            signal_exit = SHORT;
         }
         if (PositionCandlePosition > 0 && priceData[1].close < EMALongBuffer[1]) {
            signal_exit = SHORT;
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE && 
          priceData[1].close < EMALongBuffer[1] && BidPrice >= UpLimit && BidPrice < EMALongBuffer[0]) {
            signal = SHORT;
      }

      /* Stops */
      if (onGoingTrade == SHORT) {
         if (PositionCandlePosition > 0 && priceData[0].close < PositionPrice) {
            signal_exit = LONG;
         }
         if (PositionCandlePosition > 0 && priceData[1].close > EMALongBuffer[1]) {
            signal_exit = LONG;
         }
      }
      
   }
   
   TradeMann(signal, signal_exit);

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " DistanceToEnter ", DistanceToEnter);

}
