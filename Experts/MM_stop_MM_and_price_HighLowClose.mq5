
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
//#define MCARLO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = 11370;
/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "MM"
input int EMAFastPeriod = 54;
input ENUM_MA_METHOD MM_Method = MODE_SMA;

int EMAFastHandle = -1;//
double EMAFastBuffer[];

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
   CopyRates(_Symbol, chartTimeframe, 0, 3, priceData);
 
   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(ATRHandle, 0, 0, 5, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(EMAFastHandle, 0, 0, 5, EMAFastBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAFastHandle - error:", GetLastError());
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
         if (priceData[1].close > EMAFastBuffer[1] && priceData[2].low < EMAFastBuffer[2]) {
            if (EMAFastBuffer[1] > EMAFastBuffer[2]) {
               signal = LONG;
            }
         }
         if (priceData[1].close > EMAFastBuffer[1] && priceData[2].close < EMAFastBuffer[2]) {
            if (EMAFastBuffer[1] > EMAFastBuffer[2]) {
               signal = LONG;
            }
         }
         if (EMAFastBuffer[1] > EMAFastBuffer[2] && EMAFastBuffer[2] < EMAFastBuffer[3]) {
            if (priceData[1].close > EMAFastBuffer[1]) {
               signal = LONG;
            }
         }
      }
      if (onGoingTrade == LONG && priceData[1].close < EMAFastBuffer[1]) {
         if (EMAFastBuffer[1] < EMAFastBuffer[2]) {
            signal_exit = SHORT;
         }
      }
      
      if (onGoingTrade == LONG && MaxPyramidTrades > 0 &&
          totalPosisions <= MaxPyramidTrades &&
          EMAFastBuffer[1] > EMAFastBuffer[2] && EMAFastBuffer[2] < EMAFastBuffer[3]) {
          
          if (UseRiskToPyramid == true) {
            if (priceData[1].close > EMAFastBuffer[1]) {
               TradeNewMann(LONG);
            }
          }
          else {
            TradeNewMann(LONG);
          }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close < EMAFastBuffer[1] && priceData[2].high > EMAFastBuffer[2]) {
            if (EMAFastBuffer[1] < EMAFastBuffer[2]) {
               signal = SHORT;
            }
         }
         if (priceData[1].close < EMAFastBuffer[1] && priceData[2].close > EMAFastBuffer[2]) {
            if (EMAFastBuffer[1] < EMAFastBuffer[2]) {
               signal = SHORT;
            }
         }
         if (EMAFastBuffer[1] < EMAFastBuffer[2] && EMAFastBuffer[2] > EMAFastBuffer[3]) {
            if (priceData[1].close < EMAFastBuffer[1]) {
               signal = SHORT;
            }
         }
      }
      if (onGoingTrade == SHORT && priceData[1].close > EMAFastBuffer[1]) {
         if (EMAFastBuffer[1] > EMAFastBuffer[2]) {
            signal_exit = LONG;
         }
      }
      
      if (onGoingTrade == SHORT && MaxPyramidTrades > 0 &&
          totalPosisions <= MaxPyramidTrades &&
          EMAFastBuffer[1] < EMAFastBuffer[2] && EMAFastBuffer[2] > EMAFastBuffer[3]) {
          
          if (UseRiskToPyramid == true) {
            if (priceData[1].close < EMAFastBuffer[1]) {
               TradeNewMann(LONG);
            }
          }
          else {
            TradeNewMann(LONG);
          }
      }
      
   }

   TradeMann(signal, signal_exit);
   
   Comment("Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
