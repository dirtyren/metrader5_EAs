
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include <InvestFriends.mqh>

input  group             "The Wizard Number"
input ulong MyMagicNumber = 80000;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "Don Chian"
//+-----------------------------------+
//|  Enumeration declaration          |
//+-----------------------------------+
enum Applied_Extrem //Type of extreme points
  {
   HIGH_LOW,
   HIGH_LOW_OPEN,
   HIGH_LOW_CLOSE,
   OPEN_HIGH_LOW,
   CLOSE_HIGH_LOW
  };
//+-----------------------------------+
//|  INPUT PARAMETERS OF THE INDICATOR|
//+-----------------------------------+
input int DonchianPeriod = 10;            // UP Period of averaging
input Applied_Extrem Extremes = HIGH_LOW; //Type of extreme points
input int Margins = -2;
input int Shift = 1;                      //Horizontal shift of the indicator in bars
int DHandle;
double D_UP[];
double D_Down[];
double D_Middle[];

int OnInit(void)
  {
   EAVersion = "v2.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

   if (InitEA() == false) {
      return(INIT_FAILED);
   }

   DHandle = iCustom(_Symbol,chartTimeframe,"donchian_channels", DonchianPeriod, Extremes, Margins, Shift);
   if (DHandle < 0) {
      Print("Erro DHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(DHandle);
   ArraySetAsSeries(D_UP, true);
   ArraySetAsSeries(D_Down, true);
   ArraySetAsSeries(D_Middle, true);
   
   CheckAutoRollingSymbol();

   /*ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);*/

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
   CopyRates(_Symbol, chartTimeframe, 0, 5, priceData);
  
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }

   /*if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }*/

   if (CopyBuffer(DHandle, 0, 0, 3, D_UP) < 0)   {
      Print("Erro copiando buffer do indicador DHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(DHandle, 1, 0, 3, D_Middle) < 0)   {
      Print("Erro copiando buffer do indicador DHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(DHandle, 2, 0, 3, D_Down) < 0)   {
      Print("Erro copiando buffer do indicador DHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if ( (onGoingTrade == LONG || onGoingTrade == SHORT) && TakeProfitPrice == EMPTY_VALUE) {
      drawLine("Entry Price", PositionPrice, clrGreen);
      TakeProfitPrice = 1;
   }
   if (onGoingTrade == NOTRADE && TakeProfitPrice != EMPTY_VALUE) {
      removeLine("Entry Price");
      TakeProfitPrice = EMPTY_VALUE;
   }
   
   /* Check if symbol needs to be changed */
   CheckAutoRollingSymbol();

   onGoingTrade = checkPositionTypeOpen();
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;

   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[2].close < D_Down[2]) {
            if (priceData[1].close > D_Down[1]) {
               signal = LONG;
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         for (int i=PositionsTotal()-1; i>=0; i--) {
            string symbol = PositionGetSymbol(i);
            ulong magicNumber = PositionGetInteger(POSITION_MAGIC);
            double stopGain = 0;
      
            if (TradeOnSymbol == symbol && MyMagicNumber == magicNumber) { // I am on the right Symbol
               PositionTicket = PositionGetInteger(POSITION_TICKET);
               PositionPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
               PositionStopLoss = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
               PositionTakeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), _Digits);
               PositionType = PositionGetInteger(POSITION_TYPE);
               PositionDateTime = (datetime)PositionGetInteger(POSITION_TIME);
               PositionCandlePosition = iBarShift(TradeOnSymbol, PERIOD_CURRENT, PositionDateTime,false);
               PositionProfit = NormalizeDouble(PositionGetDouble(POSITION_PROFIT), _Digits);

               if (PositionStopLoss == 0 && PositionCandlePosition > 0 && priceData[1].close > EMAHighBuffer[1]) {
                  signal_exit = SHORT;
               }
            }
         }
      
         /*if (PositionCandlePosition > 0 && priceData[1].close < D_Down[2]) {
            signal_exit = SHORT;
         }*/
      }
      
      
      if (onGoingTrade == LONG && MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades &&
          priceData[1].close > D_UP[2]) {
          
          if (UseRiskToPyramid == true) {
            if (D_Down[1] > PositionPrice) {
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
         if (priceData[1].close < D_Down[2]) {
             signal = SHORT;
         }
      }
      
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         if (priceData[1].close > D_UP[2]) {
            signal_exit = LONG;
            TradeMann(signal, signal_exit);
         }
      }
      if (onGoingTrade == SHORT && MaxPyramidTrades > 0 &&
          totalPosisions <= MaxPyramidTrades &&
          priceData[1].close < D_Down[2]) {
          if (UseRiskToPyramid == true) {
            if (D_UP[1] < PositionPrice) {
               TradeNewMann(SHORT);
            }
          }
          else {
            TradeNewMann(SHORT);
          }
      }
      
   }
   
   TradeMann(signal, signal_exit);
   
}
