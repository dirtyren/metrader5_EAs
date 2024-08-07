
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>


input  group             "STOP ATR"
input uint     InpPeriod   =  20;   // Period
input double   InpCoeff    =  1.6;  // Coefficient
input ENUM_MA_METHOD InpMode = MODE_EMA;

int StopATRHandle;
double StopATRUP[];
double StopATRDown[];

input group             "Exit & Stop"
input double ExitPoints = 50;
input double ExitStopLoss = 2000;


int OnInit(void)
  {

   EAVersion = "v1.7";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);  

   if (InitEA() == false) {
      return(INIT_FAILED);
   }

   //StopATRHandle = iCustom(_Symbol,chartTimeframe,"Mod ATR Trailing Stop MT5 Indicator", InpPeriod, InpCoeff,InpMode);
   StopATRHandle = iCustom(_Symbol,chartTimeframe,"ATR_Trailing_Stop_1_Buffer", InpPeriod, InpCoeff,InpMode);
   if (StopATRHandle < 0) {
      Print("Erro StopATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(StopATRHandle);
   ArraySetAsSeries(StopATRUP, true);
   ArraySetAsSeries(StopATRDown, true);

   /* Initialize reasl symbol if needed - load the indicators on it */
   CheckAutoRollingSymbol();   

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
   
   return(0.0);
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
   
   ArraySetAsSeries(priceData, true);
   CopyRates(_Symbol, chartTimeframe, 0, 3, priceData);

   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(StopATRHandle, 0, 0, 3, StopATRUP) < 0)   {
      Print("Erro copiando buffer do indicador VolatilityHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      TradeEntryPrice = PositionPrice;
      TakeProfitPrice = TradeEntryPrice + ExitPoints;
      StopLossPrice =  TradeEntryPrice - ExitStopLoss;
      drawLine("TP", TakeProfitPrice, clrGreen);
      drawLine("SL", StopLossPrice, clrRed);      
      //if (MQLInfoInteger(MQL_TESTER)) {
         setTakeProfit(TakeProfitPrice);
         setStopLoss(StopLossPrice);
      //}
   }
   if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
      TradeEntryPrice = PositionPrice;
      TakeProfitPrice = TradeEntryPrice - ExitPoints;
      StopLossPrice =  TradeEntryPrice + ExitStopLoss;
      drawLine("TP", TakeProfitPrice, clrGreen);
      drawLine("SL", StopLossPrice, clrRed);
      //if (MQLInfoInteger(MQL_TESTER)) {
         setTakeProfit(TakeProfitPrice);
         setStopLoss(StopLossPrice);         
      //}
   }
   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
      StopLossPrice = EMPTY_VALUE;
      removeLine("TP");
      removeLine("SL");
   }

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   
   
  
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close > StopATRUP[1]) {
            if (priceData[1].low <= StopATRUP[1]) {
               signal = LONG;
             }
         }
      }
      
      /* Long Stop */
      if (onGoingTrade == LONG) {
         if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close > TakeProfitPrice) {
            signal_exit = SHORT;
         }
         if (StopLossPrice != EMPTY_VALUE && priceData[0].close < StopLossPrice) {
            signal_exit = SHORT;
         }         
      }
      
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close < StopATRUP[1]) {
            if (priceData[1].high >= StopATRUP[1]) {
               signal = SHORT;
             }
         }
      }

      
      /* Short Stop */
      if (onGoingTrade == SHORT) {
         if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close < TakeProfitPrice) {
            signal_exit = LONG;
         }
         if (StopLossPrice != EMPTY_VALUE && priceData[0].close > StopLossPrice) {
            signal_exit = LONG;
         }         
      }
   }
   
   TradeMann(signal, signal_exit);
   
   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
