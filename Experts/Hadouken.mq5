
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 7000;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "Heiken Ashi"
enum Smooth_Method
  {
   MODE_SMA_,  //SMA
   MODE_EMA_,  //EMA
   MODE_SMMA_, //SMMA
   MODE_LWMA_, //LWMA
   MODE_JJMA,  //JJMA
   MODE_JurX,  //JurX
   MODE_ParMA, //ParMA
   MODE_T3,    //T3
   MODE_VIDYA, //VIDYA
   MODE_AMA,   //AMA
  };
input Smooth_Method MA_SMethod = MODE_EMA_; //Smoothing method
input int SmLength = 30; //Smoothing depth                    
input int SmPhase = 100; //Smoothing parameter,
int HeikenHandle;
double HeikenDirection[];
double HeikenClose[];

int OnInit(void)
  {
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
  
   HeikenHandle = iCustom(_Symbol,chartTimeframe,"heiken_ashi_smoothed", MA_SMethod, SmLength, SmPhase);
   if (HeikenHandle < 0) {
      Print("Erro HeikenHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(HeikenHandle, 1);
   ArraySetAsSeries(HeikenDirection, true);
   ArraySetAsSeries(HeikenClose, true);
   
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
   
   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(HeikenHandle, 3, 0, 3, HeikenClose) < 0) {
      Print("Erro copiando buffer do indicador VolatilityHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(HeikenHandle, 4, 0, 3, HeikenDirection) < 0) {
      Print("Erro copiando buffer do indicador VolatilityHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (HeikenDirection[2] != 0 && HeikenDirection[1] == 0) {
          signal = LONG;
      }
      if (onGoingTrade == LONG && (HeikenDirection[1] == 1)) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if ( HeikenDirection[2] != 1 && HeikenDirection[1] == 1) {
          signal = SHORT;
      }
      if (onGoingTrade == SHORT && (HeikenDirection[1] == 0)) {
         signal_exit = LONG;
      }
   }
   

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

   TradeMann(signal, signal_exit);
  
}
