
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "Vwap semanal"

enum PRICE_TYPE {
   OPEN,
   CLOSE,
   HIGH,
   LOW,
   OPEN_CLOSE,
   HIGH_LOW,
   CLOSE_HIGH_LOW,
   OPEN_CLOSE_HIGH_LOW
};

input   PRICE_TYPE          Price_Type              = CLOSE_HIGH_LOW;
input   bool                Enable_Daily            = false;
input   bool                Enable_Weekly           = true;
input   bool                Enable_Monthly          = false;
input   bool                Enable_Level_01         = false;
input   int                 VWAP_Level_01_Period    = 5;
input   bool                Enable_Level_02         = false;
input   int                 VWAP_Level_02_Period    = 13;
input   bool                Enable_Level_03         = false;
input   int                 VWAP_Level_03_Period    = 20;
input   bool                Enable_Level_04         = false;
input   int                 VWAP_Level_04_Period    = 30;
input   bool                Enable_Level_05         = false;
input   int                 VWAP_Level_05_Period    = 40;

int VwapHandle = INVALID_HANDLE;
int VwapHandleReal = INVALID_HANDLE;
double Vwap[];

input  group             "Distance from Vwap"
input int DistanceMA = 2000;

double LowPrice = EMPTY_VALUE;
double HighPrice = EMPTY_VALUE;

int OnInit(void)
  {
   EAVersion = "v1.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   VwapHandle = iCustom(_Symbol,chartTimeframe,"vwap",  "", Price_Type, Enable_Daily, Enable_Weekly, Enable_Monthly, Enable_Level_01, VWAP_Level_01_Period, Enable_Level_02, VWAP_Level_02_Period, Enable_Level_03, VWAP_Level_03_Period, Enable_Level_04, VWAP_Level_04_Period, Enable_Level_05, VWAP_Level_05_Period);
   if (VwapHandle < 0) {
      Print("Erro criando indicador VwapHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(VwapHandle);
   
   /* Initialize reasl symbol if needed - load the indicators on it */
   CheckAutoRollingSymbol();
   LoadIndicators();
   
   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      // wfo_setCloseTradesOnSeparationLine(true); // false by default
     
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
   if (MQLInfoInteger(MQL_TESTER) && VwapHandleReal != INVALID_HANDLE) {
      return 0;
   }

   if (VwapHandleReal != INVALID_HANDLE) {
      IndicatorRelease(VwapHandleReal);
      VwapHandleReal = INVALID_HANDLE;
   }
   
   VwapHandleReal = iCustom(TradeOnSymbol,chartTimeframe,"vwap", "", Price_Type, Enable_Daily, Enable_Weekly, Enable_Monthly, Enable_Level_01, VWAP_Level_01_Period, Enable_Level_02, VWAP_Level_02_Period, Enable_Level_03, VWAP_Level_03_Period, Enable_Level_04, VWAP_Level_04_Period, Enable_Level_05, VWAP_Level_05_Period);
   if (VwapHandleReal < 0) {
      Print("Erro criando indicador VwapHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(Vwap, true);
 
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
   
   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   ArraySetAsSeries(priceData, true);   
   CopyRates(TradeOnSymbol, chartTimeframe, 0, 3, priceData);
 
   MqlDateTime TimeCandle ;
   TimeToStruct(priceData[0].time,TimeCandle);
   
   /* New candle detected, clean pending orders */
   if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == NOTRADE) {
      removeOrders(ORDER_TYPE_BUY_LIMIT);
      removeOrders(ORDER_TYPE_SELL_LIMIT);      
   }
   
   if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == LONG) {
      setTakeProfit(priceData[1].high);
      drawLine("TakeProfit", TakeProfitPrice, clrSpringGreen);
   }
   if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == SHORT) {
      setTakeProfit(priceData[1].low);
      drawLine("TakeProfit", TakeProfitPrice, clrSpringGreen);
   }

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   if (CheckAutoRollingSymbol() == true) {
      LoadIndicators();
      ArraySetAsSeries(priceData, true);   
      CopyRates(TradeOnSymbol, chartTimeframe, 0, 3, priceData);
   }
  
   if (CopyBuffer(VwapHandleReal, 1, 0, 3, Vwap) < 0)   {
      Print("Erro copiando buffer do indicador VwapHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }

   
   LowPrice = NormalizeDouble((Vwap[1] - DistanceMA), _Digits);
   HighPrice = NormalizeDouble((Vwap[1] + DistanceMA), _Digits);
   
   /*if (MQLInfoInteger(MQL_TESTER)) {
   }*/

   if (onGoingTrade == NOTRADE) {
      drawLine("Low", LowPrice, clrYellow);
      drawLine("High", HighPrice, clrYellow);
   }
   else if (onGoingTrade != NOTRADE) {
      removeLine("Low");
      removeLine("High");
   }

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;

   /*if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice + TargetPoints;
      drawLine("TakeProfit", TakeProfitPrice, clrSpringGreen);
   }
   if (onGoingTrade == NOTRADE) {   
      TakeProfitPrice = EMPTY_VALUE;
      removeLine("TakeProfit");
   }*/

   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close < LowPrice && priceData[1].open > LowPrice) {
            if (priceData[0].open < priceData[1].low && priceData[0].close < priceData[1].low) {
               signal = LONG;
            }
            if (priceData[0].open > priceData[1].low) {
               TradeMannStopLimit(LowPrice - SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE), ORDER_TYPE_BUY_LIMIT);
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         /*if (PositionCandlePosition > 0 && priceData[1].close > vwap[1]) {
            signal_exit = SHORT;
         }
         if (priceData[0].open > TakeProfitPrice && TakeProfitPrice != EMPTY_VALUE) {
            setStopLoss(TakeProfitPrice);
         }
         if (priceData[0].open < TakeProfitPrice && TakeProfitPrice != EMPTY_VALUE) {
            if (priceData[0].close > TakeProfitPrice) {
               signal_exit = SHORT;
            }
         } */        
      }
      
      /* Pyramid */
      /*if (onGoingTrade == LONG) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition > 0) {
            if (priceData[1].close < priceData[2].close) {
               TradeNewMann(LONG);
            }
         }
      }*/
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close > HighPrice && priceData[1].open < HighPrice) {
            if (priceData[0].open > priceData[1].high && priceData[0].close > priceData[1].high) {
               signal = SHORT;
            }
            if (priceData[0].open < priceData[1].high) {
               TradeMannStopLimit(HighPrice + SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE), ORDER_TYPE_SELL_LIMIT);
            }
         }
      }
   }

   TradeMann(signal, signal_exit);
   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
