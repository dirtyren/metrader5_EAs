
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 42500;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "Hodrick-Prescott"
input int InpHPPeriodFast = 21;    // HP Fast Period (4...32)
input int InpHPPeriodSlow = 144;   // HP Slow Period (48...256)
//--- indicator buffers

int HPHandle = -1;
double HP[]; 
double HPSlow[];
double Dev1[];
double Dev2[];


int OnInit(void)
  {
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   HPHandle = iCustom(_Symbol,chartTimeframe,"vhpchannel_02", InpHPPeriodFast, InpHPPeriodSlow);
   if (HPHandle < 0) {
      Print("Erro HPHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(HPHandle, 0);
   ArraySetAsSeries(HP, true);
   ArraySetAsSeries(HPSlow, true);
   ArraySetAsSeries(Dev1, true);
   ArraySetAsSeries(Dev2, true);
   
   
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

   /* Check candle changed and new trade is allowed to start */
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(HPHandle, 0, 0, 3, HP) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(HPHandle, 1, 0, 3, HPSlow) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(HPHandle, 2, 0, 3, Dev1) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(HPHandle, 3, 0, 3, Dev2) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }
   

   if (MQLInfoInteger(MQL_TESTER)) {
      if (onGoingTrade != NOTRADE) {
         if (priceData[0].time > timeStampCurrentCandle) {
            setTakeProfit(HPSlow[0]);
         }
      }
   }
   
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   
   
   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (MQLInfoInteger(MQL_TESTER)) {
      if (onGoingTrade != NOTRADE && PositionTakeProfit == EMPTY_VALUE) {
         setTakeProfit(HPSlow[0]);
      }
   }
  
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[2].close < Dev2[2] && priceData[1].close < HPSlow[0]) {
            if (priceData[1].low < priceData[2].low) {
               signal = LONG;
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (priceData[0].close >= HPSlow[0]) {
            signal_exit = SHORT;
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close > Dev1[1] && priceData[1].close > HPSlow[0]) {
            if (priceData[1].high > priceData[2].high) {
               signal = SHORT;
            }
         }
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         if (priceData[0].close <= HPSlow[0]) {
            signal_exit = LONG;
         }
      }
   }

   TradeMann(signal, signal_exit);

   Comment("Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " Position Price ", PositionPrice, " PositionCandlePosition ", PositionCandlePosition);
}
