
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 81800;

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
input int DonchianPeriod = 20;            //Period of averaging
input Applied_Extrem Extremes = HIGH_LOW; //Type of extreme points
input int Margins = -2;
input int Shift = 1;                      //Horizontal shift of the indicator in bars
int DHandle;
double D_UP[];
double D_Down[];
double D_Middle[];

input  group             "Volty Channel Stop"
//+------------------------------------------------------------------+
//|   ENUM_VISUAL_MODE                                               |
//+------------------------------------------------------------------+
enum ENUM_VISUAL_MODE
  {
   VISUAL_LINES,// Lines
   VISUAL_DOTS  // Dots
  };


input ENUM_VISUAL_MODE     InpVisualMode  =  VISUAL_LINES;  // Visual Mode
input ushort               InpMaPeriod    =  1;             // MA Period 
input ENUM_MA_METHOD       InpMaMethod    =  MODE_SMA;      // MA Method
input ENUM_APPLIED_PRICE   InpMaPrice     =  PRICE_CLOSE;   // MA Price

input ushort               InpAtrPeriod   =  10;            // ATR Period
input double               InpVolFactor   =  4;             // Volatility Factor
input double               InpMoneyRisk   =  1;             // Offset Factor 
input bool                 InpUseBreak    =  true;          // Use Break
input bool                 InpUseEnvelopes=  false;         // Use Envelopes
input bool                 InpUseAlert    =  true;          // Use Alert
int VHandle;
double UpBuffer[];
double DnBuffer[];
double UpSignal[];
double DnSignal[];

input  group   "Candles set stop low"
input int BackCandlesStop = 0;

int OnInit(void)
  {
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

   VHandle = iCustom(_Symbol,chartTimeframe,"volty_channel_stop", InpVisualMode, InpMaPeriod, InpMaMethod, InpMaPrice, InpAtrPeriod, InpVolFactor, InpMoneyRisk, InpUseBreak, InpUseEnvelopes,InpUseAlert);
   if (VHandle < 0) {
      Print("Erro VHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(VHandle);
   ArraySetAsSeries(UpBuffer, true);
   ArraySetAsSeries(DnBuffer, true);
   ArraySetAsSeries(UpSignal, true);
   ArraySetAsSeries(DnSignal, true);
   
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
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
   CopyRates(_Symbol, chartTimeframe, 0, BackCandlesStop + 5, priceData);
   
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

   if (CopyBuffer(VHandle, 0, 0, 3, UpBuffer) < 0)   {
      Print("Erro copiando buffer do indicador DHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(VHandle, 1, 0, 3, DnBuffer) < 0)   {
      Print("Erro copiando buffer do indicador DHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(VHandle, 2, 0, 3, UpSignal) < 0)   {
      Print("Erro copiando buffer do indicador DHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(VHandle, 3, 0, 3, DnSignal) < 0)   {
      Print("Erro copiando buffer do indicador DHandle - error:", GetLastError());
      ResetLastError();
      return;
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
      if (UpSignal[0] != EMPTY_VALUE) {
          signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG && DnSignal[0] != EMPTY_VALUE) {
         signal_exit = SHORT;
      }
      
      /*if (onGoingTrade == LONG && MaxPyramidTrades > 0 &&
         totalPosisions <= MaxPyramidTrades &&
         priceData[1].close > D_UP[2] && StopATRDirection == LONG) {
         if (UseRiskToPyramid == true) {
            if (StopATRDown[1] != EMPTY_VALUE && StopATRDown[1] > PositionPrice) {
               TradeNewMann(LONG);
            }
         }
         else {
            TradeNewMann(LONG);
         }
      }*/
      
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (DnSignal[0] != EMPTY_VALUE) {
          signal = SHORT;
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT && UpSignal[0] != EMPTY_VALUE) {
         signal_exit = LONG;

      }
      
      /*if (onGoingTrade == SHORT && MaxPyramidTrades > 0 &&
         totalPosisions <= MaxPyramidTrades &&
         priceData[1].close < D_Down[2] && StopATRDirection == SHORT) {
         if (UseRiskToPyramid == true) {
            if (StopATRUP[1] != EMPTY_VALUE && StopATRUP[1] < PositionPrice) {
               TradeNewMann(SHORT);
            }
         }
         else {
            TradeNewMann(SHORT);
         }
      }*/
      
   }
   
   TradeMann(signal, signal_exit);
   
   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
