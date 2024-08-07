
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "EMA Fast"
input int EMAFastPeriod = 200;
int EMAFastHandle = -1;
double EMAFastBuffer[];

input group             "Stochastic"
input int              Kperiod = 5;
input int              Dperiod = 3;
input int              slowing = 2;
input ENUM_MA_METHOD   ma_method = MODE_EMA;
input ENUM_STO_PRICE   price_field = STO_CLOSECLOSE;
input int LevelDown = 20;
input int LevelUp = 90;

double STO[];
int STOHandle;

input group             "Exit & Stop"
input int ExitPoints = 100;
input int ExitStopLoss = 400;

int OnInit(void)
  {
   EAVersion = "v1.0";
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
   ArraySetAsSeries(EMAFastBuffer, true);   

   STOHandle = iStochastic( _Symbol, chartTimeframe, Kperiod, Dperiod, slowing, ma_method, price_field);
   if (STOHandle < 0) {
      Print("Erro criando indicadores - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(STOHandle, 1);
   ArraySetAsSeries(STO, true);
   
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   // AddIndicator(ATRHandle, 4);
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

   if (CopyBuffer(EMAFastHandle, 0, 0, 3, EMAFastBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAFastHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(STOHandle, 1, 0, 3, STO) < 0)   {
      Print("Erro copiando buffer do indicador RSIHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   /* New candle detected, clean pending orders */
   if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == NOTRADE) {
      removeOrders(ORDER_TYPE_BUY_LIMIT);
      removeOrders(ORDER_TYPE_SELL_LIMIT);      
   }
   
   /* Check if symbol needs to be changed */
   CheckAutoRollingSymbol();      

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
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
   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
      StopLossPrice = EMPTY_VALUE;
      removeLine("TP");
      removeLine("SL");
   }
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close > EMAFastBuffer[1]) {
            if (STO[1] > LevelUp) {
               if (priceData[0].open > priceData[1].high && priceData[0].close > EMAFastBuffer[0]) {
                  signal = LONG;
               }
               if (priceData[0].open < priceData[1].high && priceData[0].close > EMAFastBuffer[0]) {
                  TradeMannStopLimit(priceData[1].high + SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE), ORDER_TYPE_BUY_LIMIT);
               }
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (PositionCandlePosition > 0) {
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
         if (priceData[1].close < EMAFastBuffer[1]) {
            if (STO[1] < LevelDown) {
               if (priceData[0].open < priceData[1].low && priceData[0].close < EMAFastBuffer[0]) {
                  signal = SHORT;
               }
               if (priceData[0].open > priceData[1].low && priceData[0].close < EMAFastBuffer[0]) {
                  TradeMannStopLimit(priceData[1].low - SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE), ORDER_TYPE_SELL_LIMIT);
               }
            }
         }
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         if (PositionCandlePosition > 0) {
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
 
   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
