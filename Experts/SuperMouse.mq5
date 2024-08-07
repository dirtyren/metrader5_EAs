
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "EMA Fast"
input int EMAFastPeriod = 200;
int EMAFastHandle = INVALID_HANDLE;
int EMAFastHandleReal = INVALID_HANDLE;
double EMAFastBuffer[];

input  group             "Changle Momentum Oscillator"
input int CMO_period= 9; // CMO period
input int CMO_Shift = 0; // CMO shift

input int LevelUP = 90;
input int LevelDown = -90;

int CMOHandle = INVALID_HANDLE;
int CMOHandleReal = INVALID_HANDLE;
double CMO[];

input group             "Exit & Stop"
input int ExitPoints = 100;
input int ExitStopLoss = 400;


int OnInit(void)
  {
   EAVersion = "v2.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   
   if (InitEA() == false) {
      return(INIT_FAILED);
   }

   EMAFastHandle = iMA(_Symbol,chartTimeframe,EMAFastPeriod,0,MODE_EMA , PRICE_CLOSE);
   if (EMAFastHandle == INVALID_HANDLE) {
      Print("Erro criando indicador EMAFastHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAFastHandle);
   
   CMOHandle = iCustom(_Symbol,chartTimeframe,"chande_momentum_oscillator", CMO_period, CMO_Shift);
   if (CMOHandle < 0) {
      Print("Erro CMOHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(CMOHandle);
   
   /* Symbol has changed or first time, load on real symbol the indicator */
   if (CheckAutoRollingSymbol() == true) {
      LoadIndicators();
   }

   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      wfo_setCloseTradesOnSeparationLine(false); // false by default
     
      // this is the only required call in OnInit, all parameters come from the header
      int WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);
   
      //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
      //wfo_setCustomPerformanceMeter(customEstimator);
      return(WFORockAndRoll);
   #endif
   return(0);
  }
  
int LoadIndicators()
{
   /* if in test mode, no need to unload and load the indicador */
   if (MQLInfoInteger(MQL_TESTER) && CMOHandleReal != INVALID_HANDLE) {
      return 0;
   }

   if (CMOHandleReal != INVALID_HANDLE) {
      IndicatorRelease(EMAFastHandleReal);
      IndicatorRelease(CMOHandleReal);
      CMOHandleReal = INVALID_HANDLE;
      EMAFastHandleReal = INVALID_HANDLE;
   }
   
   EMAFastHandleReal = iMA(TradeOnSymbol,chartTimeframe,EMAFastPeriod,0,MODE_EMA , PRICE_CLOSE);
   if (EMAFastHandleReal == INVALID_HANDLE) {
      Print("Erro criando indicador EMAFastHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(EMAFastBuffer, true);      
 
   CMOHandleReal = iCustom(TradeOnSymbol,chartTimeframe,"chande_momentum_oscillator", CMO_period, CMO_Shift);
   if (CMOHandleReal < 0) {
      Print("Erro CMOHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(CMO, true);
   
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
   
   #ifdef MCARLO
      return optpr();         // optimization parameter
   #endif
   
   return(0);
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
   
   CopyRates(_Symbol, chartTimeframe, 0, 3, priceData);

   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(EMAFastHandleReal, 0, 0, 3, EMAFastBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAFastHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(CMOHandleReal, 0, 0, 3, CMO) < 0)   {
      Print("Erro copiando buffer do indicador VolatilitCMOHandleRealyHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   /* New candle detected, clean pending orders */
   if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == NOTRADE) {
      removeOrders(ORDER_TYPE_BUY_LIMIT);
      removeOrders(ORDER_TYPE_SELL_LIMIT);      
   }   

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   if (CheckAutoRollingSymbol() == true) {
      LoadIndicators();
   }
   
   onGoingTrade = checkPositionTypeOpen();
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;
   
   if (MQLInfoInteger(MQL_TESTER)) {
      if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
         TakeProfitPrice = PositionPrice + ExitPoints;
         StopLossPrice =  PositionPrice - ExitStopLoss;      
         setTakeProfit(TakeProfitPrice);
         setStopLoss(StopLossPrice);
         drawLine("TP", TakeProfitPrice, clrGreen);
         drawLine("SL", StopLossPrice, clrRed);
      }
      if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
         TakeProfitPrice = PositionPrice - ExitPoints;
         StopLossPrice =  PositionPrice + ExitStopLoss;
         setTakeProfit(TakeProfitPrice);
         setStopLoss(StopLossPrice);
         drawLine("TP", TakeProfitPrice, clrGreen);
         drawLine("SL", StopLossPrice, clrRed);
      }
   }
   else {
      if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
         TakeProfitPrice = PositionPrice + ExitPoints + SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);
         StopLossPrice =  PositionPrice - ExitStopLoss;      
         setTakeProfit(TakeProfitPrice);
         setStopLoss(StopLossPrice);
         drawLine("TP", TakeProfitPrice, clrGreen);
         drawLine("SL", StopLossPrice, clrRed);
      }
      if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
         TakeProfitPrice = PositionPrice - ExitPoints - SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);
         StopLossPrice =  PositionPrice + ExitStopLoss;
         setTakeProfit(TakeProfitPrice);
         setStopLoss(StopLossPrice);
         drawLine("TP", TakeProfitPrice, clrGreen);
         drawLine("SL", StopLossPrice, clrRed);
      }   
   }
   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
      StopLossPrice = EMPTY_VALUE;
      removeLine("TP");
      removeLine("SL");
   }

   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         //if (priceData[2].close > EMAFastBuffer[1]) {
            if (CMO[1] > LevelUP) {
               if (MQLInfoInteger(MQL_TESTER)) {
                  if (priceData[0].open < priceData[1].low && priceData[0].close > EMAFastBuffer[0]) {
                     signal = LONG;
                  }
                  if (priceData[0].open >= priceData[1].low && priceData[0].close > EMAFastBuffer[0]) {
                     TradeMannStopLimit(priceData[1].low - SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE), ORDER_TYPE_BUY_LIMIT);
                  }
               }
               else {
                  if (priceData[0].close < priceData[1].low && priceData[0].close > EMAFastBuffer[0]) {
                     signal = LONG;
                  }
               }
            }
         //}
      }

      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (MQLInfoInteger(MQL_TESTER)) {
            if (PositionCandlePosition > 0) {
               if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close >= TakeProfitPrice) {
                  signal_exit = SHORT;
               }
               if (StopLossPrice != EMPTY_VALUE && priceData[0].close <= StopLossPrice) {
                  signal_exit = SHORT;
               }
            }
         }
         else {
            if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close >= TakeProfitPrice) {
               signal_exit = SHORT;
            }
            if (StopLossPrice != EMPTY_VALUE && priceData[0].close <= StopLossPrice) {
               signal_exit = SHORT;
            }
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         //if (priceData[2].close < EMAFastBuffer[1]) {
            if (CMO[1] < LevelDown) {
               if (MQLInfoInteger(MQL_TESTER)) {
                  if (priceData[0].open > priceData[1].high && priceData[0].close < EMAFastBuffer[0]) {
                     signal = SHORT;
                  }
                  if (priceData[0].open <= priceData[1].high && priceData[0].close < EMAFastBuffer[0]) {
                     TradeMannStopLimit(priceData[1].high + SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE), ORDER_TYPE_SELL_LIMIT);
                  }
               }
               else {
                  if (priceData[0].close > priceData[1].high && priceData[0].close < EMAFastBuffer[0]) {
                     signal = SHORT;
                  }
               }
           }
        //}
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         if (MQLInfoInteger(MQL_TESTER)) {
            if (PositionCandlePosition > 0) {
               if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close <= TakeProfitPrice) {
                  signal_exit = LONG;
               }
               if (StopLossPrice != EMPTY_VALUE && priceData[0].close >= StopLossPrice) {
                  signal_exit = LONG;
               }
            }
         }
         else {
            if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close <= TakeProfitPrice) {
               signal_exit = LONG;
            }
            if (StopLossPrice != EMPTY_VALUE && priceData[0].close >= StopLossPrice) {
               signal_exit = LONG;
            }
         }
      }
   }

   TradeMann(signal, signal_exit);

   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " Position Price ", PositionPrice, " PositionCandlePosition ", PositionCandlePosition);
}
