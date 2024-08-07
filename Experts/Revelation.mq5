
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 42800;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input group "MM"
input int EMAPeriod = 200;
int EMAHandle = -1;
double EMABuffer[];


input  group             "RSI"
input int RSIPeriod = 2;
input int RSIUP = 80;
input int RSIDown = 30;
double RSI[];      
int RSIHandle = -1;

input  group             "Stochastic"
input int KPeriod = 5;
input int DPeriod = 3;
input int SSlowing = 2;
input int SUP = 80;
input int SDown = 40;
double STO[];      
int STOHandle = -1;

input  group             "Target"
input int TargetPoint = 100;

int OnInit(void)
  {
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   STOHandle = iStochastic(_Symbol,chartTimeframe,KPeriod,DPeriod,SSlowing,MODE_EMA,STO_CLOSECLOSE);
   if(STOHandle < 0) {
      Print("Erro criando indicador STOHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(STOHandle);
   ArraySetAsSeries(STO, true);   
   
   EMAHandle = iMA(_Symbol,chartTimeframe,EMAPeriod,0,MODE_EMA, PRICE_CLOSE);
   if(EMAHandle < 0) {
      Print("Erro criando indicador EMAHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAHandle);
   ArraySetAsSeries(EMABuffer, true);
   
   RSIHandle = iRSI(_Symbol,chartTimeframe,RSIPeriod, PRICE_CLOSE);
   if(RSIHandle < 0) {
      Print("Erro criando indicador RSIHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(RSIHandle);
   ArraySetAsSeries(RSI, true);   
   
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
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if(CopyBuffer(EMAHandle, 0, 0, 3, EMABuffer) < 0) {
      Print("Erro copiando buffer do indicador EMALongHandle2 - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if(CopyBuffer(RSIHandle, 0, 0, 3, RSI) < 0) {
      Print("Erro copiando buffer do indicador RSIHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if(CopyBuffer(STOHandle, 1, 0, 3, STO) < 0) {
      Print("Erro copiando buffer do indicador STOHandle - error:", GetLastError());
      ResetLastError();
      return;
   }      
   
   
   /*if (onGoingTrade != NOTRADE) {
      if (priceData[0].time > timeStampCurrentCandle) {
         setTakeProfit(meanVal[0]);
      }
   }
   
   if (MQLInfoInteger(MQL_TESTER)) {
      if (onGoingTrade != NOTRADE) {
         if (priceData[0].time > timeStampCurrentCandle) {
            setTakeProfit(meanVal[0]);
         }
      }
   } */  
   
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   
   
   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   
   if (onGoingTrade != NOTRADE && PositionTakeProfit == EMPTY_VALUE) {
      //setTakeProfit(meanVal[0]);
   }
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close > EMABuffer[1]) {
            if (RSI[1] < RSIDown && STO[1] < SDown) {
               signal = LONG;
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (PositionCandlePosition > 0 && priceData[1].close > (PositionPrice + TargetPoint)) {
            signal_exit = SHORT;
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close < EMABuffer[1]) {
            if (RSI[1] > RSIUP && STO[1] > SUP) {
               signal = SHORT;
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == SHORT) {
         if (PositionCandlePosition > 0 && priceData[1].close < (PositionPrice - TargetPoint)) {
            signal_exit = LONG;
         }
      }
   }
   
   TradeMann(signal, signal_exit);
   
   Comment("Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " Position Price ", PositionPrice, " PositionCandlePosition ", PositionCandlePosition);
}
