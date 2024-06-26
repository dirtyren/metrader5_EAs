//+------------------------------------------------------------------------+
//|                                                Ren_DonChian_Trader.mqh |
//|                                                         Alessandro Ren |
//|                                                                        |
//+------------------------------------------------------------------------+

#property copyright "Copyright © 2023 Alessandro Ren"
#include <Ren_MQL_Library.mqh>

input  group             "The Wizard Number"
input ulong MyMagicNumber = 80000;

/* Global parameters for all EAs */
#include <Ren_MQL_Library_Parameters.mqh>

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
input int DonchianPeriod = 20;            // UP Period of averaging
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

   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 1);
   ArraySetAsSeries(ATRValue, true);

   return(INIT_SUCCEEDED);
  }
  
void OnTesterInit()
{
}

void OnTesterDeinit()
{
}

void OnTesterPass()
{
}

double OnTester()
{
   if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
      return 0.0;
   }
   
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

   if (CopyBuffer(ATRHandle, 0, 0, 5, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(DHandle, 0, 0, 5, D_UP) < 0)   {
      Print("Erro copiando buffer do indicador DHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(DHandle, 1, 0, 5, D_Middle) < 0)   {
      Print("Erro copiando buffer do indicador DHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(DHandle, 2, 0, 5, D_Down) < 0)   {
      Print("Erro copiando buffer do indicador DHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   /* Check if symbol needs to be changed */
   CheckAutoRollingSymbol();

   onGoingTrade = checkPositionTypeOpen();
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;

   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close > D_UP[2]) {
             signal = LONG;
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (priceData[1].close < D_Down[2]) {
            signal_exit = SHORT;
            TradeMann(signal, signal_exit);
         }
      }
      
      
      if (onGoingTrade == LONG && MaxPyramidTrades > 0 &&
          totalPosisions <= MaxPyramidTrades &&
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
