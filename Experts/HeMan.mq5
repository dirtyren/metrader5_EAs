
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 50000;
enum ENUM_INPUT_YES_NO
  {
   INPUT_YES   =  1, // Yes
   INPUT_NO    =  0  // No
  };
input ENUM_INPUT_YES_NO TradeOnAlternativeSymbol = INPUT_NO;
input string inTradeOnSymbol = "---";

input  group             "Configuration"
input ENUM_TIMEFRAMES chartTimeframe = PERIOD_CURRENT;
input TRADE_DIRECTION TradeDirection = LONG_SHORT_TRADE;

input  group             "D. DAY TRADE"
sinput bool              inDayTrade = true;               // D.01 Operacao apenas como day trade
input int                inStartHour = 9;                 // D.02 Hora inicio negociacao
input int                inStartWaitMin = 0;              // D.03 Minutos a aguardar antes de iniciar operacoes
input int                inStopHour = 17;                 // D.04 Hora final negociacao
input int                inStopBeforeEndMin = 44;         // D.05 Minutos antes do fim para encerrar posicoes

input  group             "Geldman!!"
input Geldmann_Type Geldmann_type = LOTS;
input double geldMann = 1;

input  group             "Auto adjust stops in"
input AdjustBy AdjustByType = PERCENTAGE;

input  group             "Break even after"
input double BreakEven = 0.0; // Breakevent stop when hit AdjustByType

input  group             "Trailing"
input double TrailingStart = 0.0; // Trailing starts set in AdjustByType
input double TrailingPriceAdjustBy = 2; // How much to adjust price

input  group             "Takeprofit and Stoploss set in AdjustByType"
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
input int DonchianPeriod = 5;            //Period of averaging UP
input Applied_Extrem Extremes = HIGH_LOW; //Type of extreme points
input int Margins = 0;
input int Shift = 1;                      //Horizontal shift of the indicator in bars
int DonchianPeriodDown=DonchianPeriod;        //Period of averaging DOWN
int DHandle;
double D_UP[];
double D_Down[];

/*input  group             "Backbars"
input uint           BackBars = 5; // BackBars
double KeepLowest = EMPTY_VALUE;
double KeepHighest = EMPTY_VALUE;
*/

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
   
   DHandle = iCustom(_Symbol,chartTimeframe,"donchian_channels", DonchianPeriod, Extremes, Margins, Shift, DonchianPeriodDown);
   if (DHandle < 0) {
      Print("Erro DHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(DHandle);
   ArraySetAsSeries(D_UP, true);
   ArraySetAsSeries(D_Down, true);

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
   
   getPositionOpen();

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
      if(wfo == -1) {
         // can do some non-trading stuff, such as gathering bar or ticks statistics
         return;
      }
      else if(wfo == +1) {
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
   CopyRates(_Symbol, chartTimeframe, 0, 3 + DonchianPeriod, priceData);

   /* Time current candle */   
   timeStampCurrentCandle = priceData[1].time;
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
   if (CopyBuffer(DHandle, 2, 0, 3, D_Down) < 0)   {
      Print("Erro copiando buffer do indicador DHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   /*double Lowest = priceData[2].low;
   double Highest = priceData[2].high;
   for(uint i = 3; i <= BackBars+1; i++) {
      if (priceData[i].high > Highest)  {
         Highest = priceData[i].high;
      }
      if (priceData[i].low < Lowest)  {
         Lowest = priceData[i].low;
      }
   }*/
   
   /*if (KeepLowest != Lowest) {
      KeepLowest = NormalizeDouble(Lowest, _Digits);
      removeLine("Lowest");
      drawLine("Lowest", KeepLowest);
   }
   if (KeepHighest != Highest) {
      KeepHighest = NormalizeDouble(Highest, _Digits);;
      removeLine("Highest");
      drawLine("Highest", Highest);
   }*/

   
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   onGoingTrade = checkPositionTypeOpen();

   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (priceData[1].close <= D_Down[1]) {
            signal = LONG;
            signal_exit = LONG;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      if (priceData[1].close > D_UP[1]) {
            signal = SHORT;
            signal_exit = SHORT;
      }
   }
   
   TradeMann(signal, signal_exit);
   
   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
