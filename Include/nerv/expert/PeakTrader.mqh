#include <nerv/core.mqh>
#include <nerv/expert/PeriodTrader.mqh>
#include <nerv/math.mqh>

/*
This trader will try to detect when we are for instance in a bullish trend and the current
price is way either than the MA4 value whereas the MA4 value is itself way higher that the MA20 value
(and same kind of situation for a bearish trend)

In that case, the trader will emit a signal that will be used on a tick by tick basic:
When in a bullish trend, we then place a sell order when we detect that the up tendency is stopped
Take profit is placed on the level of the MA4, and stoploss is "twice higher"
*/

enum ENUM_PT_TREND
{
  TREND_NONE,
  TREND_LONG,
  TREND_SHORT
};

class PeakTrader : public nvPeriodTrader
{
protected:
  int _maHandle;  // handle for our Moving Average indicator
  int _ma4Handle;  // handle for our Moving Average indicator
  double _maVal[]; // Dynamic array to hold the values of Moving Average for each bars
  double _ma4Val[]; // Dynamic array to hold the values of Moving Average of period 4 for each bars
  MqlRates _mrate[];

  double _lot;
  nvVecd _maDeltas;
  double _maMean;
  double _maSig;
  double _maThreshold;
  nvVecd _priceDeltas;
  double _priceMean;
  double _priceSig;
  double _priceThreshold;
  int _priceStatCount;
  nvVecd _tickDeltas;
  double _prevTick;
  double _tickAlpha;
  bool _initialized;
  bool _signaled;
  bool _hasNewBar;
  double _prev_ema4;
  double _slMult;

  double _ema4Slope;
  double _slopeAlpha;
  nvVecd _prevSlopes;
  nvVecd _smoothedSlope;

  double _slopeThreshold;
  double _ema4SlopeMean;
  double _ema4SlopeSig;

  ENUM_PT_TREND _trend;
  string _symbol;

public:
  PeakTrader(const nvSecurity& sec, ENUM_TIMEFRAMES period, double priceThres, double maThres, double slMult, double slopeThreshold) : nvPeriodTrader(sec,period)
  {
    // Prepare the moving average indicator:
    _maHandle=iMA(_security.getSymbol(),_period,20,0,MODE_EMA,PRICE_CLOSE);
    _ma4Handle=iMA(_security.getSymbol(),_period,4,0,MODE_EMA,PRICE_CLOSE);
    
    //--- What if handle returns Invalid Handle    
    CHECK(_maHandle>=0 && _ma4Handle>=0,"Invalid indicators handle");

    // the rates arrays
    ArraySetAsSeries(_mrate,true);
    // the MA-20 values arrays
    ArraySetAsSeries(_maVal,true);
    // the MA-4 values arrays
    ArraySetAsSeries(_ma4Val,true);

    // Lot size:
    _lot = 0.1;

    // cache the symbol:
    _symbol = _security.getSymbol();
    
    // Stoploss multiplier:
    _slMult = slMult;

    // initialize the new bar flag:
    _hasNewBar = false;

    // ma threshold given in number of ma sigmas:
    _maThreshold = maThres;

    // price threshold given in number of price sigmas:
    _priceThreshold = priceThres;

    // EMA slope threshold:
    _slopeThreshold = slopeThreshold;

    // Count used to decide if we are ready to trade.
    _priceStatCount = 0;

    // Initialize the trend:
    _trend = TREND_NONE;
    _signaled = false;

    // resize the statistic vectors:
    int malen = 100;
    int pricelen = 100;
    int ticklen = 4;
    int smoothlen = 7;
    int slopelen = 100;

    _maDeltas.resize(malen);
    _priceDeltas.resize(pricelen);
    _tickDeltas.resize(ticklen);
    _smoothedSlope.resize(smoothlen);
    _prevSlopes.resize(slopelen);

    _ema4Slope = 0.0;
    _maMean = 0.0;
    _maSig = 0.0;
    _priceMean = 0.0;
    _priceSig = 0.0;
    _ema4SlopeMean = 0.0;
    _ema4SlopeSig = 0.0;
    _initialized = false;

    // tick exponential moving average alpha:
    _tickAlpha = 1.0/(double)ticklen;

    // EMA slope exponential moving average alpha:
    _slopeAlpha = 1.0/(double)smoothlen;
  }

  ~PeakTrader()
  {
    logDEBUG("Deleting indicators...")
    logDEBUG("Was using: priceThreshold: "<<_priceThreshold<<", maThreshold: "<<_maThreshold<<", slMult: "<<_slMult)

    //--- Release our indicator handles
    IndicatorRelease(_maHandle);
    IndicatorRelease(_ma4Handle);
  }

  void updateStats(double ema4, double ema20, double high, double low)
  {
    if(_prev_ema4 == 0.0)
    {
      // init prev ema:
      _prev_ema4 = ema4;
    }

    // Now compute the smoothed MA4 slope:
    _smoothedSlope.push_back(ema4-_prev_ema4);

    _ema4Slope = _smoothedSlope.EMA(_slopeAlpha);

    // Update the statistics on the smoothed slope:
    _prevSlopes.push_back(_ema4Slope);
    _ema4SlopeMean = _prevSlopes.mean();
    _ema4SlopeSig = _prevSlopes.deviation();

    // save prev ema4 value:
    _prev_ema4 = ema4;

    double delta = ema4 - ema20;
    _maDeltas.push_back(delta);
  
    _maMean = _maDeltas.mean();
    _maSig = _maDeltas.deviation();


    // Now that we have the maMean and maSig values, we have an "idea"
    // on how far the MA4 can go from the MA20 value
    // basing ourself on this observation, we now paid attention to the high prices in the bars
    // when the current maDelta is higher that maMean+maSig,
    // And the low prices, when the current maDelta is lower that maMean-maSig
    if(delta > _maMean+_maThreshold*_maSig)
    {
      // This is a bullish bubble, so we consider the high price:
      double pdelta = high - ema4;
      _priceDeltas.push_back(pdelta);
      _priceStatCount++;
      _priceMean = _priceDeltas.mean();
      _priceSig = _priceDeltas.deviation();
    }
    if(delta < _maMean-_maThreshold*_maSig)
    {
      double pdelta = ema4 - low;
      _priceDeltas.push_back(pdelta);
      _priceStatCount++;
      _priceMean = _priceDeltas.mean();
      _priceSig = _priceDeltas.deviation();
    }
  }

  void initStatistics(int nblocks)
  {
    logDEBUG("Initializing statistics with "<<nblocks<<" data blocks.");

    // Reset the stats count:
    _priceStatCount = 0;
    int ilen = (int)_maDeltas.size()*nblocks;

    // Retrieve the previous rates, and MA20 values:
    // Note that we start with an offset of one because the previous bar details will be 
    // retrieved just after the initialization anyway.
    CHECK(CopyRates(_symbol,_period,1,ilen,_mrate)==ilen,"Cannot copy the latest rates");
    CHECK(CopyBuffer(_maHandle,0,1,ilen,_maVal)==ilen,"Cannot copy MA20 buffer 0");
    CHECK(CopyBuffer(_ma4Handle,0,1,ilen,_ma4Val)==ilen,"Cannot copy MA4 buffer 0");

    // We iterate on each element:
    for(int i=0;i<ilen;++i)
    {
      updateStats(_ma4Val[ilen-i-1],_maVal[ilen-i-1],_mrate[ilen-i-1].high,_mrate[ilen-i-1].low);
    }
  }

  bool ready()
  {
    return _priceStatCount>=(int)_priceDeltas.size();
  }

  void handleBar()
  {
    if(!_initialized) 
    {
      logDEBUG("Initializing delta statistics...");
      int nblocks=0;
      while(!ready())
      {
        initStatistics(++nblocks);
      }

      _initialized = true;
    }

    // Each time we get a new bar, we update the statistics:
    // Get the details of the latest 4 bars
    CHECK(CopyRates(_symbol,_period,0,1,_mrate)==1,"Cannot copy the latest rates");
    CHECK(CopyBuffer(_maHandle,0,0,1,_maVal)==1,"Cannot copy MA20 buffer 0");
    CHECK(CopyBuffer(_ma4Handle,0,0,1,_ma4Val)==1,"Cannot copy MA4 buffer 0");
    
    // Store the current MA4 value since this is needed to place orders.
    updateStats(_ma4Val[0],_maVal[0],_mrate[0].high,_mrate[0].low);

    // Define if we are currently in trend bubble or not:
    _trend = TREND_NONE;
    double delta = _ma4Val[0] - _maVal[0];

    if(delta > _maMean+_maThreshold*_maSig)
    {
      logDEBUG("Detected Long bubble.")
      _trend = TREND_LONG;
    }
    if(delta < _maMean-_maThreshold*_maSig)
    {
      logDEBUG("Detected Short bubble.")
      _trend = TREND_SHORT;
    }

    // Mark that a new bar as arrived, thus a new order could be placed if possible:
    _hasNewBar = true;
  }

  void handleTick()
  {
    CHECK(ready(),"Not enough statistic data ?")

    if(selectPosition())
    {
      // We do nothing here by default.
      return;
    }

    // We don't have anything to do if we are not in a trend bubble:
    if(_trend == TREND_NONE)
    {
      return;
    }

    // logDEBUG("Entering handleTick()")

    // MqlTick latest_price;
    MqlTick latest_price;
    CHECK(SymbolInfoTick(_symbol,latest_price),"Cannot retrieve latest price.")

    double tick = latest_price.bid;

    if(_prevTick==0.0)
    {
      // initialize the prev tick value:
      _prevTick = tick;
    }

    // So first we update the tick deltas with the latest tick info,
    // This will depend on the current trend considered.
    double tdelta = _trend==TREND_LONG ? tick - _prevTick : _prevTick - tick;
    _prevTick = tick;
    
    // Add this delta to the vector:
    _tickDeltas.push_back(tdelta);


    // So we received a new tick, statistics are ready and we are not in a position yet.
    // So first we check if we are currently in a signaled state:
    if(_signaled) {
      // logDEBUG("Handling signal")
      // the previous ticks entered the alert zone, so now we just need to decide if we should buy/sell right now 
      // or wait a bit longer for the tick trend to finish.
      // To do that we should use the mean of the latest tick deltas

      // Now check the current EMA: it should be positive, otherwise, we place an order!
      if(_tickDeltas.EMA(_tickAlpha)<0.0)
      {
        // place the order depending on the current trend:
        if(true) { //_hasNewBar) {
          if(_trend==TREND_LONG) {
            // We place a sell order in that case:
            sendDealOrder(ORDER_TYPE_SELL,_lot,tick,tick+_slMult*_priceSig,_prev_ema4);
          }
          else {
            // We place a buy order in that case:
            sendDealOrder(ORDER_TYPE_BUY,_lot,latest_price.ask,tick-_slMult*_priceSig,_prev_ema4);
          }

          // Now we need to wait for a new bar in case we would like to place another order!
          _hasNewBar = false;          
        }

        // terminate this signal:
        _signaled = false;
      }

      // The tick trend is still not finished, so we wait...
    }
    else {
      // logDEBUG("Checking for signal...")
      // Check if the market is not current trending too much:
      if(MathAbs(_ema4Slope - _ema4SlopeMean) > _slopeThreshold*_ema4SlopeSig)
      {
        // Current trend is too strong.
        // We just don't want to take the risk here.
        return;
      }

      // There is currently no signal for an interesting tick behavior.
      // So just check if the current tick is goind too far.
      // This again will depend on the current trend.
      if((_trend==TREND_LONG && tick > _prev_ema4+_priceMean+_priceThreshold*_priceSig && _tickDeltas.EMA(_tickAlpha)>0.0)
        || (_trend==TREND_SHORT && tick < _prev_ema4-_priceMean-_priceThreshold*_priceSig && _tickDeltas.EMA(_tickAlpha)>0.0))
      {
        // Signal this tick as interesting and keep the current tick statistics:
        logDEBUG("Detected interesting tick!")
        _signaled = true;
      }
    }
  }
};
