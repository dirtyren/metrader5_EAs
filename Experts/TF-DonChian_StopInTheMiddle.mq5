
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 82000;
enum ENUM_INPUT_YES_NO
  {
   INPUT_YES   =  1, // Yes
   INPUT_NO    =  0  // No
  };
input ENUM_INPUT_YES_NO TradeOnAlternativeSymbol = INPUT_NO;
input string inTradeOnSymbol = "---";

input  group             "Configuration"
input ENUM_TIMEFRAMES chartTimeframe = PERIOD_CURRENT;
input TRADE_DIRECTION TradeDirection = LONG_TRADE;

input  group             "D. DAY TRADE"
sinput bool              inDayTrade = false;               // D.01 Operacao apenas como day trade
input int                inStartHour = 9;                 // D.02 Hora inicio negociacao
input int                inStartWaitMin = 0;              // D.03 Minutos a aguardar antes de iniciar operacoes
input int                inStopHour = 19;                 // D.04 Hora final negociacao
input int                inStopBeforeEndMin = 44;         // D.05 Minutos antes do fim para encerrar posicoes

input  group             "Geldman!!"
input Geldmann_Type Geldmann_type = GELD;
input double geldMann = 3000;

input  group             "Trailing"
input AdjustBy AdjustByType = PERCENTAGE;
input double TrailingStart = 0; // Trailing starts in percentage
input double TrailingPriceAdjustBy = 1; // How much to adjust price

input  group             "Takeprofit and Stoploss"
input double takeProfit = 0;
input double stopLoss = 0;

input  group             "Extras"
input double maxDailyLoss = 0;
input double maxDailyProfit = 0;
input int timeToSleep = 0;


input  group             "ATR"
input int ATRPeriod = 14;

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
input int DonchianPeriod = 26;            //Period of averaging
input Applied_Extrem Extremes = HIGH_LOW; //Type of extreme points
input int Margins = -2;
input int Shift = 1;                      //Horizontal shift of the indicator in bars
int DHandle;
double D_UP[];
double D_Down[];
double D_Middle[];

input  group             "STOP ATR"
input uint     InpPeriod   =  10;   // Period
input double   InpCoeff    =  3.0;  // Coefficient
int StopATRHandle;
double StopATRUP[];
double StopATRDown[];
int StopATRDirection = NOTRADE;

input  group   "Candles set stop low"
input int BackCandlesStop = 5;

int OnInit(void)
  {
   if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
      Print("Invalid trailing parameter ",TrailingStart, " ",TrailingStart);
      return(INIT_FAILED);
   }
   
   TradeOnSymbol = _Symbol;
   if (TradeOnAlternativeSymbol == INPUT_YES) {
      TradeOnSymbol = inTradeOnSymbol;
   }

   startTime = (inStartHour * 60) + inStartWaitMin;
   stopTime = (inStopHour * 60) + inStopBeforeEndMin;

   cleanUPIndicators();
   
   DHandle = iCustom(_Symbol,chartTimeframe,"donchian_channels", DonchianPeriod, Extremes, Margins, Shift);
   if (DHandle < 0) {
      Print("Erro DHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(DHandle);
   ArraySetAsSeries(D_UP, true);
   ArraySetAsSeries(D_Down, true);

   StopATRHandle = iCustom(_Symbol,chartTimeframe,"Mod ATR Trailing Stop MT5 Indicator", InpPeriod, InpCoeff);
   if (StopATRHandle < 0) {
      Print("Erro StopATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(StopATRHandle);
   ArraySetAsSeries(StopATRUP, true);
   ArraySetAsSeries(StopATRDown, true);
   
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);

   trade.SetExpertMagicNumber(MyMagicNumber);
   
   onGoingTrade = checkPositionTypeOpen();
   totalPosisions = returnAllPositions();
   printf("onGoingTrade %d totalPosisions %d closedprofit %.2f", onGoingTrade, totalPosisions, closedProfitPeriod());
   Comment("Magic number: ", MyMagicNumber, " Profit ", closedProfitPeriod());
   
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
   if (BackCandlesStop > 0) {
      CopyRates(_Symbol, chartTimeframe, 0, BackCandlesStop + 5, priceData);
   }
   
   MqlRates RFPrice[]; // array to keep the current and last candle
   ArraySetAsSeries(RFPrice, true);
   CopyRates(_Symbol,PERIOD_MN1 , 0, 7, RFPrice);
   
   /* Time current candle */   
   timeStampCurrentCandle = priceData[0].time;
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

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

   onGoingTrade = checkPositionTypeOpen();
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;
   
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
      if (priceData[0].close > D_UP[1] && priceData[1].close > D_Middle[1]) {
          signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG && (priceData[1].close < D_Middle[1])) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (priceData[0].close < D_Down[1] && priceData[1].close < D_Middle[1]) {
          signal = SHORT;
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT && (priceData[1].close > D_Middle[1])) {
         signal_exit = LONG;

      }
   }
   
   TradeMann(signal, signal_exit);
   
   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
