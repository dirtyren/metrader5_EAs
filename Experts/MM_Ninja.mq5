
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
//#define MCARLO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "MM Stop"
input int EMAFastPeriod = 15;
input ENUM_MA_METHOD MM_Method = MODE_SMA;

input  group             "MM Start"
input int EMALongPeriod = 29;
input ENUM_MA_METHOD MM_MethodLong = MODE_SMA;

int EMAFastHandle = INVALID_HANDLE;
int EMASlowHandle = INVALID_HANDLE;
double EMAFastBuffer[];
double EMASlowBuffer[];

int OnInit(void)
  {

   EAVersion = "v1.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   EMAFastHandle = iMA(_Symbol,chartTimeframe,EMAFastPeriod,0,MM_Method, PRICE_CLOSE);
   if (EMAFastHandle < 0) {
      Print("Erro criando indicador EMAFastHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAFastHandle);
   ArraySetAsSeries(EMAFastBuffer, true);
   
   EMASlowHandle = iMA(_Symbol,chartTimeframe,EMALongPeriod,0,MM_MethodLong, PRICE_CLOSE);
   if (EMASlowHandle < 0) {
      Print("Erro criando indicador EMASlowHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMASlowHandle);
   ArraySetAsSeries(EMASlowBuffer, true);

   /* Initialize reasl symbol if needed - load the indicators on it */
   CheckAutoRollingSymbol();
   //LoadIndicators();

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
  
/*int LoadIndicators()
{
   // if in test mode, no need to unload and load the indicador
   if (MQLInfoInteger(MQL_TESTER) && EMAFastHandleReal != INVALID_HANDLE) {
      return 0;
   }

   if (EMAFastHandleReal != INVALID_HANDLE) {
      IndicatorRelease(EMAFastHandleReal);
      EMAFastHandleReal = INVALID_HANDLE;
   }
 
   EMAFastHandleReal = iMA(TradeOnSymbol,chartTimeframe,EMAFastPeriod,0,MM_Method , PRICE_CLOSE);
   if (EMAFastHandleReal == INVALID_HANDLE) {
      Print("Erro criando indicador EMAFastHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(EMAFastBuffer, true);
   
   ArraySetAsSeries(priceData, true);   
   CopyRates(TradeOnSymbol, chartTimeframe, 0, 3, priceData);
   
   Print("Indicator(s) loaded on the symbol ", TradeOnSymbol);

   return 0;
}*/

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
   #ifdef MCARLO
      return optpr();         // optimization parameter
   #endif

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
   CopyRates(TradeOnSymbol, chartTimeframe, 0, 3, priceData);
 
   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   CheckAutoRollingSymbol();
   
   if (CopyBuffer(EMAFastHandle, 0, 0, 5, EMAFastBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAFastHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(EMASlowHandle, 0, 0, 5, EMASlowBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAFastHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }   
   
   onGoingTrade = checkPositionTypeOpen();
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (EMASlowBuffer[1] > EMASlowBuffer[2]) {
            if (EMAFastBuffer[1] > EMAFastBuffer[2]) {
               if (priceData[1].close > EMASlowBuffer[1]) {
                  signal = LONG;
               }
            }
         }
      }
      /* Long Exit */
      if (onGoingTrade == LONG) {
         if (EMAFastBuffer[1] < EMAFastBuffer[2]) {
            if (priceData[1].close < EMASlowBuffer[1]) {
               signal_exit = SHORT;
            }
         }
      }
      
      /* Pyramid */
      if (onGoingTrade == LONG) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition >0) {
            if (priceData[1].close > EMAFastBuffer[1] && priceData[1].close > priceData[2].close) {
               TradeNewMann(LONG);
            }
         }
      }      
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (EMASlowBuffer[1] < EMASlowBuffer[2]) {
            if (EMAFastBuffer[1] < EMAFastBuffer[2]) {
               if (priceData[1].close < EMASlowBuffer[1]) {
                  signal = SHORT;
               }
            }
         }
      }
      if (onGoingTrade == SHORT) {
         if (EMAFastBuffer[1] > EMAFastBuffer[2]) {
            if (priceData[1].close > EMASlowBuffer[1]) {
               signal_exit = LONG;
            }
         }
      }
      
      /* Pyramid */
      if (onGoingTrade == SHORT) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition >0) {
            if (priceData[1].close < EMAFastBuffer[1] && priceData[1].close < priceData[2].close) {
               TradeNewMann(SHORT);
            }
         }
      }
   }

   TradeMann(signal, signal_exit);
   
   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
