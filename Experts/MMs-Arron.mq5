
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
input int EMAFastPeriod = 9;
input ENUM_MA_METHOD EMAFastMode = MODE_SMA;
int EMAFastHandle = -1;
double EMAFastBuffer[];

input  group             "EMA Slow"
input int EMASlowPeriod = 20;
input ENUM_MA_METHOD EMASlowMode = MODE_SMA;
int EMASlowHandle = -1;
double EMASlowBuffer[];

input  group             "Aroon Oscillator"
input int    AroonPeriod  = 25; // Aroon period
input double Filter       = 50; // Level filter value

int AroonHandle = -1;
double AroonValue[];
double AroonDirection[];

int OnInit(void)
  {

   EAVersion = "v1.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

   if(InitEA() == false) {
      return(INIT_FAILED);
   }
   
   EMAFastHandle = iMA(_Symbol,chartTimeframe,EMAFastPeriod,0,EMAFastMode , PRICE_CLOSE);
   if (EMAFastHandle == INVALID_HANDLE) {
      Print("Erro criando indicador EMAFastHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAFastHandle);
   ArraySetAsSeries(EMAFastBuffer, true);

   EMASlowHandle = iMA(_Symbol,chartTimeframe,EMASlowPeriod,0,EMASlowMode , PRICE_CLOSE);
   if (EMASlowHandle == INVALID_HANDLE) {
      Print("Erro criando indicador EMASlowHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMASlowHandle);
   ArraySetAsSeries(EMASlowBuffer, true);   
   
   AroonHandle = iCustom(_Symbol,chartTimeframe,"aroon_oscillator_line", AroonPeriod, Filter);
   if (AroonHandle == INVALID_HANDLE) {
      Print("Erro AroonHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(AroonHandle, 1);
   ArraySetAsSeries(AroonValue, true);
   ArraySetAsSeries(AroonDirection, true);

   int WFORockAndRoll = 0;
   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      wfo_setCloseTradesOnSeparationLine(false); // false by default
     
      // this is the only required call in OnInit, all parameters come from the header
      WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);
   
      //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
      //wfo_setCustomPerformanceMeter(customEstimator);
      return(WFORockAndRoll);
   #endif
   return(INIT_SUCCEEDED);
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
   #ifdef WFO
      if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
         return 0.0;
      }
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
   if (CopyBuffer(EMASlowHandle, 0, 0, 3, EMASlowBuffer) < 0) {
      Print("Erro copiando buffer do indicador EMASlowHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(AroonHandle, 0, 0, 3, AroonValue) < 0) {
      Print("Erro copiando buffer do indicador AroonHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(AroonHandle, 1, 0, 3, AroonDirection) < 0) {
      Print("Erro copiando buffer do indicador AroonHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   
   
   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (EMAFastBuffer[1] > EMASlowBuffer[1]) {
            if (AroonValue[2] < 0 && AroonValue[1] > 0) {
               signal = LONG;
            }
         }
      }

      /* Stops */
      if (onGoingTrade == LONG) {
         if (EMAFastBuffer[1] < EMASlowBuffer[1]) {
               signal_exit = SHORT;
         }
      }
      
      /*if (onGoingTrade == LONG && MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades &&
          D[2] < LevelUp && D[1] > LevelUp) {
         
         if (UseRiskToPyramid == true) {
            if (priceData[1].close > PositionPrice) {
               TradeNewMann(LONG);
            }
         }
         else {
            TradeNewMann(LONG);
         }
      }*/
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (EMAFastBuffer[1] < EMASlowBuffer[1]) {
            if (AroonValue[2] > 0 && AroonValue[1] < 0) {
               signal = SHORT;
            }
         }
      }
      
      if (onGoingTrade == SHORT) {
         if (EMAFastBuffer[1] > EMASlowBuffer[1]) {
            signal_exit = LONG;
         }
      }

      /*if (onGoingTrade == SHORT && MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades &&
          D[2] > LevelDown && D[1] < LevelDown) {
         
         if (UseRiskToPyramid == true) {
            if (priceData[1].close < PositionPrice) {
               TradeNewMann(SHORT);
            }
         }
         else {
            TradeNewMann(SHORT);
         }
      } */    
   }
   
   TradeMann(signal, signal_exit);

   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
