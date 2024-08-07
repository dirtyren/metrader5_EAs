
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;
/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "EMA Fast"
input int EMAFastPeriod = 54;
input ENUM_MA_METHOD MM_MethodFast = MODE_SMA;
int EMAFastHandle = INVALID_HANDLE;
int EMAFastHandleReal = INVALID_HANDLE;
double EMAFastBuffer[];

input  group             "EMA Slow"
input int EMAPeriod = 200;
input ENUM_MA_METHOD MM_Method = MODE_SMA;
int EMAHandle = INVALID_HANDLE;
int EMAHandleReal = INVALID_HANDLE;
double EMA[];

int OnInit(void)
  {
   EAVersion = "v1.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   EMAFastHandle = iMA(_Symbol,chartTimeframe,EMAFastPeriod,0,MM_MethodFast, PRICE_CLOSE);
   if (EMAFastHandle < 0) {
      Print("Erro criando indicador EMAFastHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAFastHandle);
   
   EMAHandle = iMA(_Symbol,chartTimeframe,EMAPeriod,0,MM_Method, PRICE_CLOSE);
   if (EMAFastHandle < 0) {
      Print("Erro criando indicador EMAHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAHandle);
   
   /* Symbol has changed or first time, load on real symbol the indicator */
   if (CheckAutoRollingSymbol() == true) {
      LoadIndicators();
   }

   
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
  
int LoadIndicators()
{
   /* if in test mode, no need to unload and load the indicador */
   if (MQLInfoInteger(MQL_TESTER) && EMAFastHandleReal != INVALID_HANDLE) {
      return 0;
   }

   if (EMAFastHandleReal != EMAFastHandleReal) {
      IndicatorRelease(EMAFastHandleReal);
      IndicatorRelease(EMAHandleReal);
      EMAHandleReal = INVALID_HANDLE;
      EMAFastHandleReal = INVALID_HANDLE;
   }
  
   EMAFastHandleReal = iMA(TradeOnSymbol,chartTimeframe,EMAFastPeriod,0,MM_MethodFast , PRICE_CLOSE);
   if (EMAFastHandleReal == INVALID_HANDLE) {
      Print("Erro criando indicador EMAFastHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(EMAFastBuffer, true);   
   
   EMAHandleReal = iMA(TradeOnSymbol,chartTimeframe,EMAPeriod,0, MM_Method, PRICE_CLOSE);
   if (EMAHandleReal == INVALID_HANDLE) {
      Print("Erro criando indicador EMAHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(EMA, true);

  
   Print("Indicator(s) loaded on the symbol ", TradeOnSymbol);

   return 0;
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
   
   if (CopyBuffer(EMAFastHandle, 0, 0, 3, EMAFastBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAFastHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(EMAHandle, 0, 0, 3, EMA) < 0)   {
      Print("Erro copiando buffer do indicador EMAHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (onGoingTrade != NOTRADE) {
      if (priceData[0].time > timeStampCurrentCandle) {
         //setTakeProfit(EMAFastBuffer[1]);
      }
   }
   
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   if (CheckAutoRollingSymbol() == true) {
      LoadIndicators();
   }

   
   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (onGoingTrade != NOTRADE && PositionTakeProfit == EMPTY_VALUE) {
      //setTakeProfit(EMAFastBuffer[1]);
   }
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close > EMA[1] && priceData[1].close > EMAFastBuffer[1]) {
            if (EMAFastBuffer[1] > EMAFastBuffer[2]) {
               signal = LONG;
            }
         }
      }
      if (onGoingTrade == LONG && priceData[1].close < EMAFastBuffer[1]) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close < EMA[1] && priceData[1].close < EMAFastBuffer[1]) {
            if (EMAFastBuffer[1] < EMAFastBuffer[2]) {
               signal = SHORT;
            }
         }
      }
      if (onGoingTrade == SHORT && priceData[1].close > EMAFastBuffer[1]) {
         signal_exit = LONG;
      }
   }

   TradeMann(signal, signal_exit);
   
   Comment("Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
