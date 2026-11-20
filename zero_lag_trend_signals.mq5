//+------------------------------------------------------------------+
//| Zero Lag Trend Signals (MTF) [AlgoAlpha]                          |
//|                                                                  |
//| Original Pine Script:                                            |
//| Copyright (c) AlgoAlpha                                          |
//|                                                                  |
//| MQL5 Port and Adaptation:                                        |
//| Copyright (c) 2026 Ahmad Said                                    |
//|                                                                  |
//| Licensed under the Mozilla Public License 2.0 (MPL 2.0).         |
//| https://www.mozilla.org/MPL/2.0/                                 |
//|                                                                  |
//| This indicator is derived from the original Pine Script by      |
//| AlgoAlpha and has been translated and adapted for MetaTrader 5.  |
//|                                                                  |
//| Original attribution and license notices are preserved.         |
//| Modifications are distributed under MPL 2.0.                     |
//|                                                                  |
//| This is a custom technical indicator, not an Expert Advisor.     |
//+------------------------------------------------------------------+
#property copyright "Original (c) AlgoAlpha; MQL5 translation under MPL 2.0"
#property link      "https://mozilla.org/MPL/2.0/"
#property version   "1.00"
#property description "Zero-lag EMA, Wilder ATR deviation bands, trend/entry signals, five-timeframe panel and alerts."
#property indicator_chart_window
#property indicator_buffers 12
#property indicator_plots   9

#property indicator_label1  "Zero Lag Basis"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrMediumSeaGreen,clrTomato
#property indicator_width1  2

#property indicator_label2  "Upper Deviation Band"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrIndianRed
#property indicator_width2  1

#property indicator_label3  "Lower Deviation Band"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSeaGreen
#property indicator_width3  1

#property indicator_label4  "Bearish Band Fill"
#property indicator_type4   DRAW_FILLING
#property indicator_color4  clrMaroon,clrMaroon

#property indicator_label5  "Bullish Band Fill"
#property indicator_type5   DRAW_FILLING
#property indicator_color5  clrDarkGreen,clrDarkGreen

#property indicator_label6  "Bullish Trend"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrLime
#property indicator_width6  2

#property indicator_label7  "Bearish Trend"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrRed
#property indicator_width7  2

#property indicator_label8  "Bullish Entry"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrLime
#property indicator_width8  1

#property indicator_label9  "Bearish Entry"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  clrRed
#property indicator_width9  1

input group "Main Calculations"
input int               InpLength         = 70;             // Length
input double            InpBandMultiplier = 1.2;            // Band multiplier
input int               InpCalculationBars= 2500;           // Bars per timeframe to calculate

input group "Extra Timeframes"
input ENUM_TIMEFRAMES   InpTF1            = PERIOD_M5;      // Timeframe 1
input ENUM_TIMEFRAMES   InpTF2            = PERIOD_M15;     // Timeframe 2
input ENUM_TIMEFRAMES   InpTF3            = PERIOD_H1;      // Timeframe 3
input ENUM_TIMEFRAMES   InpTF4            = PERIOD_H4;      // Timeframe 4
input ENUM_TIMEFRAMES   InpTF5            = PERIOD_D1;      // Timeframe 5

input group "Appearance"
input color             InpBullColor      = C'0,255,187';    // Bullish color
input color             InpBearColor      = C'255,17,0';     // Bearish color
input bool              InpShowBandFills  = true;           // Show simple (non-gradient) band fills
input bool              InpShowDashboard  = true;           // Show MTF status panel

input group "Alerts"
input bool              InpEnableAlerts   = true;           // Terminal popup alerts
input bool              InpAlertEntries   = true;           // Entry signals
input bool              InpAlertTrends    = true;           // Main chart trend reversals
input bool              InpAlertMTF       = true;           // Higher/lower timeframe trend reversals
// Alerts are emitted once for a fully CLOSED signal bar to prevent intrabar duplicates.

// Indicator plots; SetIndexBuffer order matches the #property plot declarations.
double BasisBuffer[];
double BasisColorBuffer[];
double UpperBuffer[];
double LowerBuffer[];
double BearFillBasis[];
double BearFillOuter[];
double BullFillBasis[];
double BullFillOuter[];
double BullTrendArrow[];
double BearTrendArrow[];
double BullEntryArrow[];
double BearEntryArrow[];

struct TrendSeries
{
   MqlRates rates[];              // chronological order: oldest at index 0
   double   basis[];
   double   atr[];
   double   volatility[];
   int      trend[];
   bool     bull_entry[];
   bool     bear_entry[];
   int      count;
};

string   g_prefix = "";
color    g_bg = clrBlack;
color    g_fg = clrWhite;
bool     g_alerts_ready = false;
datetime g_last_chart_closed = 0;
datetime g_last_tf_closed[5];

// Blend color toward the chart background. Strength 0 = background, 1 = color.
color BlendColor(const color foreground,const color background,const double strength)
{
   double a=MathMax(0.0,MathMin(1.0,strength));
   int f=(int)foreground;
   int b=(int)background;
   int r=(int)MathRound((f&255)*a+(b&255)*(1.0-a));
   int g=(int)MathRound(((f>>8)&255)*a+((b>>8)&255)*(1.0-a));
   int bl=(int)MathRound(((f>>16)&255)*a+((b>>16)&255)*(1.0-a));
   return (color)(r | (g<<8) | (bl<<16));
}

string TFName(const ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "1m";
      case PERIOD_M2:  return "2m";
      case PERIOD_M3:  return "3m";
      case PERIOD_M4:  return "4m";
      case PERIOD_M5:  return "5m";
      case PERIOD_M6:  return "6m";
      case PERIOD_M10: return "10m";
      case PERIOD_M12: return "12m";
      case PERIOD_M15: return "15m";
      case PERIOD_M20: return "20m";
      case PERIOD_M30: return "30m";
      case PERIOD_H1:  return "1h";
      case PERIOD_H2:  return "2h";
      case PERIOD_H3:  return "3h";
      case PERIOD_H4:  return "4h";
      case PERIOD_H6:  return "6h";
      case PERIOD_H8:  return "8h";
      case PERIOD_H12: return "12h";
      case PERIOD_D1:  return "1D";
      case PERIOD_W1:  return "1W";
      case PERIOD_MN1: return "1M";
      default:         return EnumToString(tf);
   }
}

// TradingView ta.atr(length) = Wilder RMA(true range, length).
// ta.ema() is seeded on its FIRST non-na source value.
// Highest ATR is a rolling window of length*3, ignoring missing ATR values.
bool LoadAndCalculate(const ENUM_TIMEFRAMES tf,TrendSeries &s)
{
   int requested=MathMax(InpCalculationBars,InpLength*4+20);
   ArraySetAsSeries(s.rates,false);
   int n=CopyRates(_Symbol,tf,0,requested,s.rates);
   s.count=n;
   if(n<2)
      return false;

   ArrayResize(s.basis,n);
   ArrayResize(s.atr,n);
   ArrayResize(s.volatility,n);
   ArrayResize(s.trend,n);
   ArrayResize(s.bull_entry,n);
   ArrayResize(s.bear_entry,n);

   int lag=(InpLength-1)/2;
   double alpha=2.0/(InpLength+1.0);
   double true_range_sum=0.0;
   double last_ema=0.0;
   bool ema_started=false;
   double last_atr=0.0;

   // Monotonic deque storing ATR indices for rolling highest(); O(n).
   int deque[];
   ArrayResize(deque,n);
   int head=0,tail=0;
   int window=InpLength*3;

   for(int i=0;i<n;i++)
   {
      s.basis[i]=EMPTY_VALUE;
      s.atr[i]=EMPTY_VALUE;
      s.volatility[i]=EMPTY_VALUE;
      s.trend[i]=(i>0 ? s.trend[i-1] : 0);
      s.bull_entry[i]=false;
      s.bear_entry[i]=false;

      double high=s.rates[i].high;
      double low=s.rates[i].low;
      double close=s.rates[i].close;
      double tr=high-low;
      if(i>0)
      {
         double pc=s.rates[i-1].close;
         tr=MathMax(tr,MathAbs(high-pc));
         tr=MathMax(tr,MathAbs(low-pc));
      }
      if(i<InpLength)
         true_range_sum+=tr;
      if(i==InpLength-1)
      {
         last_atr=true_range_sum/InpLength;
         s.atr[i]=last_atr;
      }
      else if(i>=InpLength)
      {
         last_atr=(last_atr*(InpLength-1)+tr)/InpLength;
         s.atr[i]=last_atr;
      }

      if(i>=lag)
      {
         double corrected_close=2.0*close-s.rates[i-lag].close;
         if(!ema_started)
         {
            last_ema=corrected_close;
            ema_started=true;
         }
         else
            last_ema=alpha*corrected_close+(1.0-alpha)*last_ema;
         s.basis[i]=last_ema;
      }

      if(s.atr[i]!=EMPTY_VALUE)
      {
         while(tail>head && s.atr[deque[tail-1]]<=s.atr[i])
            tail--;
         deque[tail++]=i;
      }
      while(tail>head && deque[head]<=i-window)
         head++;
      if(tail>head)
         s.volatility[i]=s.atr[deque[head]]*InpBandMultiplier;

      if(i==0 || s.basis[i]==EMPTY_VALUE || s.basis[i-1]==EMPTY_VALUE ||
         s.volatility[i]==EMPTY_VALUE || s.volatility[i-1]==EMPTY_VALUE)
         continue;

      double prev_close=s.rates[i-1].close;
      double prev_top=s.basis[i-1]+s.volatility[i-1];
      double top=s.basis[i]+s.volatility[i];
      double prev_bottom=s.basis[i-1]-s.volatility[i-1];
      double bottom=s.basis[i]-s.volatility[i];

      // ta.crossover(close, upper) / ta.crossunder(close, lower)
      if(close>top && prev_close<=prev_top)
         s.trend[i]=1;
      if(close<bottom && prev_close>=prev_bottom)
         s.trend[i]=-1;

      // Small arrows only if the trend was already established on prior bar.
      s.bull_entry[i]=(close>s.basis[i] && prev_close<=s.basis[i-1] &&
                        s.trend[i]==1 && s.trend[i-1]==1);
      s.bear_entry[i]=(close<s.basis[i] && prev_close>=s.basis[i-1] &&
                        s.trend[i]==-1 && s.trend[i-1]==-1);
   }
   return true;
}

void MakeRectangle(const string key,const int x,const int y,const int w,
                   const int h,const color fill,const color border)
{
   string name=g_prefix+key;
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,fill);
   ObjectSetInteger(0,name,OBJPROP_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
}

void MakeLabel(const string key,const int x,const int y,
               const string value,const color ink,const bool bold=false)
{
   string name=g_prefix+key;
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,name,OBJPROP_FONT,(bold ? "Arial Bold" : "Arial"));
   ObjectSetString(0,name,OBJPROP_TEXT,value);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void UpdatePanel(const ENUM_TIMEFRAMES &frames[],const int &states[])
{
   if(!InpShowDashboard)
      return;
   // Top-right panel: 220px wide x 148px high. All distances from right edge.
   MakeRectangle("Panel",232,12,220,148,g_bg,BlendColor(g_fg,g_bg,0.6));
   MakeLabel("TitleTF",118,20,"Time Frame",g_fg,true);
   MakeLabel("TitleSignal",21,20,"Signal",g_fg,true);
   for(int i=0;i<5;i++)
   {
      int top=42+i*22;
      bool bull=(states[i]==1);
      bool bear=(states[i]==-1);
      string state=(bull ? "Bullish" : (bear ? "Bearish" : "N/A"));
      color ink=(bull ? InpBullColor : (bear ? InpBearColor : g_fg));
      color tint=BlendColor(ink,g_bg,0.22);
      MakeRectangle("Cell"+IntegerToString(i),105,top-2,86,20,tint,g_bg);
      MakeLabel("TF"+IntegerToString(i),118,top,TFName(frames[i]),g_fg);
      MakeLabel("State"+IntegerToString(i),28,top,state,ink,true);
   }
}

void NotifyTrend(const string label,const bool bullish)
{
   Alert("AlgoAlpha Zero Lag [",_Symbol,"] ",label,": ",
         (bullish ? "Bullish Trend" : "Bearish Trend"));
}

int OnInit()
{
   if(InpLength<2 || InpBandMultiplier<=0.0 || InpCalculationBars<100)
   {
      Print("Invalid input: Length >= 2, Band Multiplier > 0, Calculation Bars >= 100.");
      return INIT_PARAMETERS_INCORRECT;
   }

   SetIndexBuffer(0,BasisBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,BasisColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,UpperBuffer,INDICATOR_DATA);
   SetIndexBuffer(3,LowerBuffer,INDICATOR_DATA);
   SetIndexBuffer(4,BearFillBasis,INDICATOR_DATA);
   SetIndexBuffer(5,BearFillOuter,INDICATOR_DATA);
   SetIndexBuffer(6,BullFillBasis,INDICATOR_DATA);
   SetIndexBuffer(7,BullFillOuter,INDICATOR_DATA);
   SetIndexBuffer(8,BullTrendArrow,INDICATOR_DATA);
   SetIndexBuffer(9,BearTrendArrow,INDICATOR_DATA);
   SetIndexBuffer(10,BullEntryArrow,INDICATOR_DATA);
   SetIndexBuffer(11,BearEntryArrow,INDICATOR_DATA);

   ArraySetAsSeries(BasisBuffer,true);
   ArraySetAsSeries(BasisColorBuffer,true);
   ArraySetAsSeries(UpperBuffer,true);
   ArraySetAsSeries(LowerBuffer,true);
   ArraySetAsSeries(BearFillBasis,true);
   ArraySetAsSeries(BearFillOuter,true);
   ArraySetAsSeries(BullFillBasis,true);
   ArraySetAsSeries(BullFillOuter,true);
   ArraySetAsSeries(BullTrendArrow,true);
   ArraySetAsSeries(BearTrendArrow,true);
   ArraySetAsSeries(BullEntryArrow,true);
   ArraySetAsSeries(BearEntryArrow,true);

   g_bg=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   g_fg=(color)ChartGetInteger(0,CHART_COLOR_FOREGROUND);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,0,BlendColor(InpBullColor,g_bg,0.5));
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,1,BlendColor(InpBearColor,g_bg,0.5));
   PlotIndexSetInteger(1,PLOT_LINE_COLOR,0,BlendColor(InpBearColor,g_bg,0.36));
   PlotIndexSetInteger(2,PLOT_LINE_COLOR,0,BlendColor(InpBullColor,g_bg,0.36));
   PlotIndexSetInteger(3,PLOT_LINE_COLOR,0,BlendColor(InpBearColor,g_bg,0.12));
   PlotIndexSetInteger(3,PLOT_LINE_COLOR,1,BlendColor(InpBearColor,g_bg,0.12));
   PlotIndexSetInteger(4,PLOT_LINE_COLOR,0,BlendColor(InpBullColor,g_bg,0.12));
   PlotIndexSetInteger(4,PLOT_LINE_COLOR,1,BlendColor(InpBullColor,g_bg,0.12));
   PlotIndexSetInteger(5,PLOT_LINE_COLOR,0,InpBullColor);
   PlotIndexSetInteger(6,PLOT_LINE_COLOR,0,InpBearColor);
   PlotIndexSetInteger(7,PLOT_LINE_COLOR,0,InpBullColor);
   PlotIndexSetInteger(8,PLOT_LINE_COLOR,0,InpBearColor);

   // Wingdings arrows: 233 up, 234 down.
   PlotIndexSetInteger(5,PLOT_ARROW,233);
   PlotIndexSetInteger(6,PLOT_ARROW,234);
   PlotIndexSetInteger(7,PLOT_ARROW,233);
   PlotIndexSetInteger(8,PLOT_ARROW,234);

   for(int plot=0;plot<9;plot++)
      PlotIndexSetDouble(plot,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME,"Zero Lag Trend Signals (MTF) [AlgoAlpha]");
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);

   g_prefix=StringFormat("AlgoAlphaZL_%I64d_%I64d_",ChartID(),(long)GetMicrosecondCount());
   for(int i=0;i<5;i++)
      g_last_tf_closed[i]=0;
   g_last_chart_closed=0;
   g_alerts_ready=false;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0,g_prefix);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total<InpLength+2)
      return 0;

   TrendSeries main;
   if(!LoadAndCalculate((ENUM_TIMEFRAMES)_Period,main))
      return prev_calculated;

   // Recompute a bounded history so charts remain reasonably responsive.
   // Blank buffers outside the bounded history, rather than leaving stale plots.
   ArrayInitialize(BasisBuffer,EMPTY_VALUE);
   ArrayInitialize(BasisColorBuffer,0.0);
   ArrayInitialize(UpperBuffer,EMPTY_VALUE);
   ArrayInitialize(LowerBuffer,EMPTY_VALUE);
   ArrayInitialize(BearFillBasis,EMPTY_VALUE);
   ArrayInitialize(BearFillOuter,EMPTY_VALUE);
   ArrayInitialize(BullFillBasis,EMPTY_VALUE);
   ArrayInitialize(BullFillOuter,EMPTY_VALUE);
   ArrayInitialize(BullTrendArrow,EMPTY_VALUE);
   ArrayInitialize(BearTrendArrow,EMPTY_VALUE);
   ArrayInitialize(BullEntryArrow,EMPTY_VALUE);
   ArrayInitialize(BearEntryArrow,EMPTY_VALUE);

   int n=main.count;
   for(int i=0;i<n;i++)
   {
      int bar=n-1-i; // indicator index 0 == current candle
      if(main.basis[i]==EMPTY_VALUE)
         continue;

      BasisBuffer[bar]=main.basis[i];
      BasisColorBuffer[bar]=(main.trend[i]==1 ? 0.0 : 1.0);
      if(main.volatility[i]==EMPTY_VALUE)
         continue;

      double upper=main.basis[i]+main.volatility[i];
      double lower=main.basis[i]-main.volatility[i];
      if(main.trend[i]==-1)
      {
         UpperBuffer[bar]=upper;
         if(InpShowBandFills)
         {
            BearFillBasis[bar]=main.basis[i];
            BearFillOuter[bar]=upper;
         }
      }
      if(main.trend[i]==1)
      {
         LowerBuffer[bar]=lower;
         if(InpShowBandFills)
         {
            BullFillBasis[bar]=main.basis[i];
            BullFillOuter[bar]=lower;
         }
      }

      if(i>0)
      {
         if(main.trend[i]==1 && main.trend[i-1]<=0)
            BullTrendArrow[bar]=lower;
         if(main.trend[i]==-1 && main.trend[i-1]>=0)
            BearTrendArrow[bar]=upper;
      }
      if(main.bull_entry[i])
         BullEntryArrow[bar]=main.basis[i]-1.5*main.volatility[i];
      if(main.bear_entry[i])
         BearEntryArrow[bar]=main.basis[i]+1.5*main.volatility[i];
   }

   if(n>=3)
   {
      int j=n-2; // last CLOSED candle (no intrabar repaint in alerts)
      datetime closed=main.rates[j].time;
      if(g_alerts_ready && InpEnableAlerts && closed!=g_last_chart_closed)
      {
         if(InpAlertTrends)
         {
            if(main.trend[j]==1 && main.trend[j-1]<=0)
               NotifyTrend(TFName((ENUM_TIMEFRAMES)_Period),true);
            if(main.trend[j]==-1 && main.trend[j-1]>=0)
               NotifyTrend(TFName((ENUM_TIMEFRAMES)_Period),false);
         }
         if(InpAlertEntries)
         {
            if(main.bull_entry[j])
               Alert("AlgoAlpha Zero Lag [",_Symbol,"] ",TFName((ENUM_TIMEFRAMES)_Period),
                     ": Bullish Entry Signal");
            if(main.bear_entry[j])
               Alert("AlgoAlpha Zero Lag [",_Symbol,"] ",TFName((ENUM_TIMEFRAMES)_Period),
                     ": Bearish Entry Signal");
         }
      }
      g_last_chart_closed=closed;
   }

   ENUM_TIMEFRAMES frames[5]={InpTF1,InpTF2,InpTF3,InpTF4,InpTF5};
   int states[5];
   TrendSeries mtf;
   for(int t=0;t<5;t++)
   {
      states[t]=0;
      if(!LoadAndCalculate(frames[t],mtf))
         continue;
      int last=mtf.count-1;
      states[t]=mtf.trend[last]; // current MTF bar, as in Pine realtime panel

      if(mtf.count>=3)
      {
         int j=mtf.count-2;
         datetime closed=mtf.rates[j].time;
         if(g_alerts_ready && InpEnableAlerts && InpAlertMTF &&
            closed!=g_last_tf_closed[t])
         {
            if(mtf.trend[j]==1 && mtf.trend[j-1]<=0)
               NotifyTrend(TFName(frames[t]),true);
            if(mtf.trend[j]==-1 && mtf.trend[j-1]>=0)
               NotifyTrend(TFName(frames[t]),false);
         }
         g_last_tf_closed[t]=closed;
      }
   }

   UpdatePanel(frames,states);
   g_alerts_ready=true;
   return rates_total;
}
