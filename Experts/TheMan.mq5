
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
int EMAFastHandle = INVALID_HANDLE;
int EMAFastHandleReal = INVALID_HANDLE;
double EMAFastBuffer[];

input group             "Stochastic"
input int              Kperiod = 5; // Kperiod Dperiod
//input int              Dperiod = 3;
input int              slowing = 2;
input ENUM_MA_METHOD   ma_method = MODE_EMA;
input ENUM_STO_PRICE   price_field = STO_CLOSECLOSE;
input int LevelDown = 20;
input int LevelUp = 80;

double STO[];
int STOHandle = INVALID_HANDLE;
int STOHandleReal = INVALID_HANDLE;

input group             "Exit & Stop"
input double ExitPoints = 100;
input double ExitStopLoss = 400;
input double DistanceToEnter = 1;

int OnInit(void)
  {
   EAVersion = "v1.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   EMAFastHandle = iMA(_Symbol,chartTimeframe,EMAFastPeriod,0,MODE_EMA,PRICE_CLOSE);
   if (EMAFastHandle == INVALID_HANDLE) {
      Print("Erro criando indicador EMAFastHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAFastHandle);
   ArraySetAsSeries(EMAFastBuffer, true);

   STOHandle = iStochastic( _Symbol, chartTimeframe, Kperiod, Kperiod, slowing, ma_method, price_field);
   if (STOHandle < 0) {
      Print("Erro criando indicadores - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(STOHandle, 1);
   ArraySetAsSeries(STO, true);
   
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
   return 0.0;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   cleanUPIndicators();
}

void OnTrade()
{

   closePositionBy();

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
   
   /* New candle detected, clean pending orders */
   if (MQLInfoInteger(MQL_TESTER)) {
      if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == NOTRADE) {
         removeOrders(ORDER_TYPE_BUY_LIMIT);
         removeOrders(ORDER_TYPE_SELL_LIMIT);      
      }
   }
   
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   if (CheckAutoRollingSymbol() == true) {
      //LoadIndicators();
   }

   if (CopyBuffer(EMAFastHandle, 0, 0, 3, EMAFastBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAFastHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(STOHandle, 1, 0, 3, STO) < 0)   {
      Print("Erro copiando buffer do indicador STOHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice + ExitPoints;
      StopLossPrice =  PositionPrice - ExitStopLoss;
      if (MQLInfoInteger(MQL_TESTER)) {
         setTakeProfit(TakeProfitPrice);
         setStopLoss(StopLossPrice);
      }
      drawLine("TP", TakeProfitPrice, clrGreen);
      drawLine("SL", StopLossPrice, clrRed);
   }
   if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice - ExitPoints;
      StopLossPrice =  PositionPrice + ExitStopLoss;
      if (MQLInfoInteger(MQL_TESTER)) {
         setTakeProfit(TakeProfitPrice);
         setStopLoss(StopLossPrice);         
      }
      drawLine("TP", TakeProfitPrice, clrGreen);
      drawLine("SL", StopLossPrice, clrRed);
   }
   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
      StopLossPrice = EMPTY_VALUE;
      removeLine("TP");
      removeLine("SL");
   }
   
   double tickSizeSlippage = DistanceToEnter * SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close > EMAFastBuffer[1]) {
            if (STO[2] < LevelUp && STO[1] > LevelUp) {
               signal = LONG;
               removeLine("Entry Price");
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         removeLine("Entry Price");
         if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close >= TakeProfitPrice) {
            signal_exit = SHORT;
         }
         if (StopLossPrice != EMPTY_VALUE && priceData[0].close <= StopLossPrice) {
            signal_exit = SHORT;
         }
         if (priceData[1].close < EMAFastBuffer[1]) {
            signal_exit = SHORT;
         }
      }
      
      /* Pyramid */
      if (onGoingTrade == LONG) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition > 0) {
            if (priceData[2].close > EMAFastBuffer[1]) {
               if (priceData[1].close < priceData[2].close) {
                  if (MQLInfoInteger(MQL_TESTER)) {
                     if (priceData[0].close < priceData[1].low) {
                        TradeNewMann(LONG);
                     }
                     if (priceData[0].open >= priceData[1].low) {
                        TradeMannStopLimit(priceData[1].low - SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE), ORDER_TYPE_BUY_LIMIT);
                     }
                  }
                  else {
                     if (priceData[0].close <= (priceData[1].low - tickSizeSlippage)) {
                        TradeNewMann(LONG);
                     }
                  }
               }
            }
         }
      }
      
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close < EMAFastBuffer[1]) {
            if (STO[2] > LevelDown && STO[1] < LevelDown) {
               signal = SHORT;
               removeLine("Entry Price");
            }
         }
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         removeLine("Entry Price");
         if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close <= TakeProfitPrice) {
            signal_exit = LONG;
         }
         if (StopLossPrice != EMPTY_VALUE && priceData[0].close >= StopLossPrice) {
            signal_exit = LONG;
         }
         if (priceData[1].close > EMAFastBuffer[1]) {
            signal_exit = LONG;
         }
      }
      
      /* Pyramid */
      if (onGoingTrade == SHORT) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition > 0) {
            if (priceData[2].close < EMAFastBuffer[1]) {
               if (priceData[1].close > priceData[2].close) {
                  if (MQLInfoInteger(MQL_TESTER)) {
                     if (priceData[0].open > priceData[1].high) {
                        TradeNewMann(SHORT);
                     }
                     if (priceData[0].open < priceData[1].high) {
                        TradeMannStopLimit(priceData[1].high + SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE), ORDER_TYPE_SELL_LIMIT);
                     }
                  }
                  else {
                     if (priceData[0].close >= (priceData[1].high + tickSizeSlippage)) {
                        TradeNewMann(SHORT);
                     }
                  }
               }
            }
         }
      }
      
   }
   
   TradeMann(signal, signal_exit);
 
   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
