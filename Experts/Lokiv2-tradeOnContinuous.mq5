
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "MM"
input int EMAFastPeriod = 54;
input ENUM_MA_METHOD MM_Method = MODE_SMA;

int HMAHandle = INVALID_HANDLE;
int HMAHandleReal = INVALID_HANDLE;
double HMA[];

input  group             "STOP ATR"
input uint     InpPeriod   =  10;   // Period
input double   InpCoeff    =  3.0;  // Coefficient
int StopATRHandle = INVALID_HANDLE;
int StopATRHandleReal = INVALID_HANDLE;
double StopATRUP[];
double StopATRDown[];
int StopATRDirection = NOTRADE;
int StopATRDirection2 = NOTRADE;

input  group   "Candles set stop low"
input int BackCandlesStop = 0;

int OnInit(void)
  {

   EAVersion = "v2.2";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   HMAHandle = iMA(_Symbol,chartTimeframe,EMAFastPeriod,0,MM_Method , PRICE_CLOSE);
   if (HMAHandle < 0) {
      Print("Erro HMAHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(HMAHandle);
   ArraySetAsSeries(HMA, true);

   StopATRHandle = iCustom(_Symbol,chartTimeframe,"Mod ATR Trailing Stop MT5 Indicator", InpPeriod, InpCoeff);
   if (StopATRHandle < 0) {
      Print("Erro StopATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(StopATRHandle);
   ArraySetAsSeries(StopATRUP, true);
   ArraySetAsSeries(StopATRDown, true);
   
   CheckAutoRollingSymbol();
   //LoadIndicators();

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
  
int LoadIndicators()
{
   /* if in test mode, no need to unload and load the indicador */
   if (MQLInfoInteger(MQL_TESTER) && HMAHandleReal != INVALID_HANDLE) {
      return 0;
   }

   if (HMAHandleReal != INVALID_HANDLE) {
      IndicatorRelease(StopATRHandleReal);
      IndicatorRelease(HMAHandleReal);
      StopATRHandleReal = INVALID_HANDLE;
      HMAHandleReal = INVALID_HANDLE;
   }
 
   //HMAHandle = iCustom(_Symbol,chartTimeframe,"Hull average 2", inpPeriod, inpDivisor, inpPrice);
   HMAHandleReal = iMA(TradeOnSymbol,chartTimeframe,EMAFastPeriod,0,MM_Method , PRICE_CLOSE);
   if (HMAHandleReal < 0) {
      Print("Erro HMAHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(HMAHandleReal);
   ArraySetAsSeries(HMA, true);

   StopATRHandleReal = iCustom(TradeOnSymbol,chartTimeframe,"Mod ATR Trailing Stop MT5 Indicator", InpPeriod, InpCoeff);
   if (StopATRHandleReal < 0) {
      Print("Erro StopATRHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(StopATRHandleReal);
   ArraySetAsSeries(StopATRUP, true);
   ArraySetAsSeries(StopATRDown, true);

   
   ArraySetAsSeries(priceData, true);
   CopyRates(TradeOnSymbol, chartTimeframe, 0, 3, priceData);
   
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
   CopyRates(TradeOnSymbol, chartTimeframe, 0, BackCandlesStop + 5, priceData);
   
   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   /*if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }*/

   if (CopyBuffer(HMAHandle, 0, 0, 4, HMA) < 0)   {
      Print("Erro copiando buffer do indicador HMAHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(StopATRHandle, 0, 0, 3, StopATRUP) < 0)   {
      Print("Erro copiando buffer do indicador VolatilityHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(StopATRHandle, 1, 0, 3, StopATRDown) < 0)   {
      Print("Erro copiando buffer do indicador VolatilityHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
 
   StopATRDirection = NOTRADE;
   if (StopATRUP[1] == EMPTY_VALUE) {
      StopATRDirection = LONG;
   }
   if (StopATRDown[1] == EMPTY_VALUE) {
      StopATRDirection = SHORT;
   }
   
   StopATRDirection2 = NOTRADE;
   if (StopATRUP[2] == EMPTY_VALUE) {
      StopATRDirection2 = LONG;
   }
   if (StopATRDown[2] == EMPTY_VALUE) {
      StopATRDirection2 = SHORT;
   }   

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   if (CheckAutoRollingSymbol() == true) {
      //LoadIndicators();
   }
   
   onGoingTrade = checkPositionTypeOpen();
   trade_signal = NOTRADE;
   trade_signal_exit = NOTRADE;
   
   
   if (onGoingTrade == NOTRADE) {
      LowestPrice = EMPTY_VALUE;
      HighestPrice = EMPTY_VALUE;
   }
   else if (onGoingTrade != NOTRADE && BackCandlesStop > 0 && (PositionStopLoss == 0 || PositionStopLoss == EMPTY_VALUE)) {
      for(int i = 1; i<=BackCandlesStop;i++) {
         if (i == 1) {
            LowestPrice = NormalizeDouble(priceData[i].low, _Digits);
            HighestPrice =  NormalizeDouble(priceData[i].high, _Digits);
         }
         if (priceData[i].low < LowestPrice) {
            LowestPrice = NormalizeDouble(priceData[i].low, _Digits);
         }
         if (priceData[i].high > HighestPrice) {
            HighestPrice = NormalizeDouble(priceData[i].high, _Digits);
         }
      }
      
      if (onGoingTrade == LONG) {
         if (PositionStopLoss == 0 ) {
            setStopLoss(LowestPrice);
         }
      }
      else if (onGoingTrade == SHORT) {
         if (PositionStopLoss == 0 ) {
            setStopLoss(HighestPrice);
         }
      }
      
   }
  
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[2].close < HMA[2] && priceData[1].close > HMA[1] && StopATRDirection == LONG) {
             trade_signal = LONG;
         }
         if (HMA[1] > HMA[2] && StopATRDirection == LONG && StopATRDirection2 != LONG) {
             trade_signal = LONG;
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG && (StopATRDirection == SHORT ||
                                   (StopATRUP[1] != EMPTY_VALUE && priceData[1].close <= StopATRUP[1]))) {
         trade_signal_exit = SHORT;
      }
      
      if (onGoingTrade == LONG && MaxPyramidTrades > 0 &&
         totalPosisions <= MaxPyramidTrades &&
         HMA[1] > HMA[2] && StopATRDirection == LONG) {
         if (UseRiskToPyramid == true) {
            if (StopATRDown[1] != EMPTY_VALUE && StopATRDown[1] > PositionPrice) {
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
         if (priceData[2].close > HMA[2] && priceData[1].close < HMA[1] && StopATRDirection == SHORT) {
             trade_signal = SHORT;
         }
         if (HMA[1] < HMA[2] && StopATRDirection == SHORT && StopATRDirection2 != SHORT) {
             trade_signal = SHORT;
         }
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT && (StopATRDirection == LONG ||
                                   (StopATRDown[1] != EMPTY_VALUE && priceData[1].close >= StopATRDown[2]))) {
         trade_signal_exit = LONG;

      }
      
      if (onGoingTrade == SHORT && MaxPyramidTrades > 0 &&
         totalPosisions <= MaxPyramidTrades &&
         HMA[1] < HMA[2] && StopATRDirection == SHORT) {
         if (UseRiskToPyramid == true) {
            if (StopATRUP[1] != EMPTY_VALUE && StopATRUP[1] < PositionPrice) {
               TradeNewMann(SHORT);
            }
         }
         else {
            TradeNewMann(SHORT);
         }
      }
      
   }
   
   TradeMann(trade_signal, trade_signal_exit);

}
