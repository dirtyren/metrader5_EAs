
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input group             "Slow Stochastic"
//--- input parameters
input uint     InpPeriodK     =  9;    // Period K
input uint     InpPeriodD     =  3;    // Period D
input uint     InpPeriodS     =  3;    // Slowing
input double   InpOverbought  =  80.0; // Overbought
input double   InpOversold    =  30.0; // Oversold

double STO[];
int STOHandle = INVALID_HANDLE;
int STOHandleReal = INVALID_HANDLE;

input group             "Exit & Stop"
input double ExitPoints = 100;
input double ExitStopLoss = 250;
input double DistanceToEnter = 1;

int OnInit(void)
  {
   EAVersion = "v1.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   
   if (InitEA() == false) {
      return(INIT_FAILED);
   }

   STOHandle = iCustom(_Symbol,chartTimeframe,"Stochastic_Slow", InpPeriodK, InpPeriodD, InpPeriodS, InpOverbought, InpOversold);
   if (STOHandle < 0) {
      Print("Erro STOHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(STOHandle);
   ArraySetAsSeries(STO, true);
      
   /* Initialize reasl symbol if needed - load the indicators on it */
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
   
   if (CopyBuffer(STOHandle, 1, 0, 3, STO) < 0) {
      Print("Erro copiando buffer do indicador STOHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      if (TradeEntryPrice > PositionPrice) {
         TradeEntryPrice = PositionPrice;
      }
      TakeProfitPrice = TradeEntryPrice + ExitPoints;
      StopLossPrice =  TradeEntryPrice - ExitStopLoss;
      if (MQLInfoInteger(MQL_TESTER)) {
         setTakeProfit(TakeProfitPrice);
         setStopLoss(StopLossPrice);
      }
      drawLine("TP", TakeProfitPrice, clrGreen);
      drawLine("SL", StopLossPrice, clrRed);
   }
   if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
      if (TradeEntryPrice < PositionPrice) {
         TradeEntryPrice = PositionPrice;
      }
      TakeProfitPrice = TradeEntryPrice - ExitPoints;
      StopLossPrice =  TradeEntryPrice + ExitStopLoss;
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
         if (priceData[1].close > priceData[1].open) {
            if (STO[1] > InpOverbought) {
               TradeEntryPrice = priceData[1].high + tickSizeSlippage;
               drawLine("Entry Price", TradeEntryPrice, clrBlueViolet);
               if (MQLInfoInteger(MQL_TESTER)) {
                  if (priceData[0].open > TradeEntryPrice) {
                     signal = LONG;
                  }
                  if (priceData[0].open <= TradeEntryPrice) {
                     TradeMannStopLimit(TradeEntryPrice, ORDER_TYPE_BUY_LIMIT);
                  }
               }
               else {
                  if (priceData[0].close >= TradeEntryPrice) {
                     signal = LONG;
                  }
               }
            }
            else {
               removeLine("Entry Price");
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         removeLine("Entry Price");
         if (STO[1] < InpOverbought) {
            signal_exit = SHORT;
         }
         if (priceData[0].close >= TakeProfitPrice) {
            signal_exit = SHORT;
         }
         if (priceData[0].close <= StopLossPrice) {
            signal_exit = SHORT;
         }
      }
      
      /* Pyramid */
      if (onGoingTrade == LONG) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition > 0) {
         }
      }
      
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close < priceData[1].open) {
            if (STO[1] < InpOversold) {
               TradeEntryPrice = priceData[1].low - tickSizeSlippage;
               drawLine("Entry Price", TradeEntryPrice, clrBlueViolet);
               if (MQLInfoInteger(MQL_TESTER)) {
                  if (priceData[0].open < TradeEntryPrice) {
                     signal = SHORT;
                  }
                  if (priceData[0].open >= TradeEntryPrice) {
                     TradeMannStopLimit(TradeEntryPrice, ORDER_TYPE_SELL_LIMIT);
                  }
               }
               else {
                  if (priceData[0].close <= TradeEntryPrice) {
                     signal = SHORT;
                  }
               }
            }
            else {
               removeLine("Entry Price");
            }
         }
      }
      
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         removeLine("Entry Price");
         if (STO[1] > InpOversold) {
            signal_exit = LONG;
         }
         if (priceData[0].close <= TakeProfitPrice) {
            signal_exit = LONG;
         }
         if (priceData[0].close >= StopLossPrice) {
            signal_exit = LONG;
         }
      }
      
      /* Pyramid */
      if (onGoingTrade == SHORT) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition > 0) {
         }
      }      
   }
   
   TradeMann(signal, signal_exit);
 
   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
