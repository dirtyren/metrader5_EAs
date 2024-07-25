
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
input int EMAFastPeriod = 200;
int EMAFastHandle = INVALID_HANDLE;
int EMAFastHandleReal = INVALID_HANDLE;
double EMAFastBuffer[];

input group             "Stochastic"
input int              Kperiod = 5;
input int              Dperiod = 3;
input int              slowing = 2;
input ENUM_MA_METHOD   ma_method = MODE_EMA;
input ENUM_STO_PRICE   price_field = STO_CLOSECLOSE;
input int LevelDown = 10;
input int LevelUp = 80;

double STO[];
int STOHandle = INVALID_HANDLE;
int STOHandleReal = INVALID_HANDLE;

input group             "Exit & Stop"
input int ExitPoints = 100;
input int ExitStopLoss = 400;

int OnInit(void)
  {
   EAVersion = "v1.1";
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

   STOHandle = iStochastic( _Symbol, chartTimeframe, Kperiod, Dperiod, slowing, ma_method, price_field);
   if (STOHandle < 0) {
      Print("Erro criando indicadores - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(STOHandle, 1);
   
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
  
int LoadIndicators()
{
   /* if in test mode, no need to unload and load the indicador */
   if (MQLInfoInteger(MQL_TESTER) && EMAFastHandleReal != INVALID_HANDLE) {
      return 0;
   }

   if (EMAFastHandleReal != INVALID_HANDLE) {
      IndicatorRelease(STOHandleReal);
      IndicatorRelease(EMAFastHandleReal);
      STOHandleReal = INVALID_HANDLE;
      EMAFastHandleReal = INVALID_HANDLE;
   }
 
   EMAFastHandleReal = iMA(TradeOnSymbol,chartTimeframe,EMAFastPeriod,0,MODE_EMA , PRICE_CLOSE);
   if (EMAFastHandleReal == INVALID_HANDLE) {
      Print("Erro criando indicador EMAFastHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(EMAFastBuffer, true);   

   STOHandleReal = iStochastic(TradeOnSymbol, chartTimeframe, Kperiod, Dperiod, slowing, ma_method, price_field);
   if (STOHandleReal < 0) {
      Print("Erro criando indicadores STOHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(STO, true);
   
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
      if (MQLInfoInteger(MQL_TESTER)) {
         TakeProfitPrice = PositionPrice + ExitPoints - SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);
         StopLossPrice =  PositionPrice - ExitStopLoss - ( 2 * SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE));
      }
      else {
         TakeProfitPrice = PositionPrice + ExitPoints;
         StopLossPrice =  PositionPrice - ExitStopLoss;      
      }
      setTakeProfit(TakeProfitPrice);
      setStopLoss(StopLossPrice);
      drawLine("TP", TakeProfitPrice, clrGreen);
      drawLine("SL", StopLossPrice, clrRed);
   }
   if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
      if (MQLInfoInteger(MQL_TESTER)) {
         TakeProfitPrice = PositionPrice - ExitPoints + SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);
         StopLossPrice =  PositionPrice + ExitStopLoss + ( 2 * SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE));
      }
      else {
         TakeProfitPrice = PositionPrice - ExitPoints;
         StopLossPrice =  PositionPrice + ExitStopLoss;
      }
      setTakeProfit(TakeProfitPrice);
      setStopLoss(StopLossPrice);
      drawLine("TP", TakeProfitPrice, clrGreen);
      drawLine("SL", StopLossPrice, clrRed);
   }
   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
      StopLossPrice = EMPTY_VALUE;
      removeLine("TP");
      removeLine("SL");
   }
   
   double tickSizeSlippage = 2 * SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[2].close > EMAFastBuffer[1]) {
            if (STO[1] < LevelDown) {
               if (MQLInfoInteger(MQL_TESTER)) {
                  if (priceData[0].open < (priceData[1].low - tickSizeSlippage) && priceData[0].close > EMAFastBuffer[0]) {
                     signal = LONG;
                  }
                  if (priceData[0].open >= priceData[1].low && priceData[0].close > EMAFastBuffer[0]) {
                     TradeMannStopLimit(priceData[1].low - tickSizeSlippage, ORDER_TYPE_BUY_LIMIT);
                  }
               }
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (STO[1] > LevelUp) {
            signal_exit = SHORT;
         }
         if (MQLInfoInteger(MQL_TESTER) == false) {
            if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close >= TakeProfitPrice) {
               signal_exit = SHORT;
            }
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
                     if (priceData[0].close < priceData[1].low) {
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
         if (priceData[2].close < EMAFastBuffer[1]) {
            if (STO[1] > LevelUp) {
               if (MQLInfoInteger(MQL_TESTER)) {
                  if (priceData[0].open > (priceData[1].high + tickSizeSlippage) < EMAFastBuffer[0]) {
                     signal = SHORT;
                  }
                  if (priceData[0].open < priceData[1].high && priceData[0].close < EMAFastBuffer[0]) {
                     TradeMannStopLimit(priceData[1].high + tickSizeSlippage, ORDER_TYPE_SELL_LIMIT);
                  }
               }
            }
         }
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         if (STO[1] < LevelDown) {
            signal_exit = LONG;
         }
         if (MQLInfoInteger(MQL_TESTER) == false) {
            if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close <= TakeProfitPrice) {
               signal_exit = LONG;
            }
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
                     if (priceData[0].close > priceData[1].high) {
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
