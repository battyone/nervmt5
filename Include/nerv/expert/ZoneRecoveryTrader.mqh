#include <nerv/core.mqh>
#include <nerv/expert/PeriodTrader.mqh>
#include <nerv/math.mqh>

/*
This trader will implement a simple version of the zone recovery trader.
*/

class ZoneRecoveryTrader : public nvPeriodTrader
{
protected:
  int _ma6Handle;

  double _lotBaseSize;
  double _targetProfit;
  double _zoneWidth;
  double _zoneLow;
  double _zoneHigh;
  double _prevEntry;
  double _prevSize;
  double _minGain;
  int _bounceCount;
  double _totalLost;
  nvVecd _maxBounceStats;
  double _contractSize;
  ENUM_ORDER_TYPE _prevOrder;
  double _riskLevel;
  bool _initialized;
  nvVecd _prevPrices;
  double _priceMean;
  double _priceDev;
  MqlRates _rates[];
  double _ma6Val[];
  datetime _lastMinute;
  double _bandSize;

public:
  ZoneRecoveryTrader(const nvSecurity& sec, ENUM_TIMEFRAMES period) : nvPeriodTrader(sec,period)
  {
    // Init MA20 Handler:
    _ma6Handle=iMA(_security.getSymbol(),PERIOD_H1,6,0,MODE_EMA,PRICE_CLOSE);

    _lotBaseSize = 0.02;

    // Target profit in number of points:
    _zoneWidth = 0.0;
    _zoneLow = 0.0;
    _zoneHigh = 0.0;
    _prevEntry = 0.0;
    _minGain = 10.0*sec.getPoint();
    _bounceCount = 0;
    _totalLost = 0.0;
    _maxBounceStats.resize(500);

    // Contract size for this account:
    _contractSize = 100000.0;

    // Setup the risk level in percentage of the balance:
    _riskLevel = 100.0;

    // Compute the statistics on the previous hours:
    _prevPrices.resize(96);
    _priceMean = 0.0;
    _priceDev = 0.0;
    _lastMinute = 0;
    _initialized = false;
  }

  ~ZoneRecoveryTrader()
  {
    IndicatorRelease(_ma6Handle);
  }

  void updatePriceStatistics(const MqlRates& rate, double ema6)
  {
    if(rate.time > _lastMinute)
    {
      _prevPrices.push_back(rate.close - ema6);
      _priceMean = _prevPrices.mean();
      _priceDev = _prevPrices.deviation();
      _lastMinute = rate.time;  
      logDEBUG(rate.time << ": Updating price minute stats, mean="<<_priceMean<<", dev="<<_priceDev)
    }
  }

  void handleBar()
  {
    if(!_initialized)
    {
      // perform initialization:
      logDEBUG("Initializing ZoneRecovery trader.")
  
      int ilen = (int)_prevPrices.size();

      // Populate our statistic vector with some data:
      CHECK(CopyRates(_symbol,PERIOD_H1,0,ilen,_rates)==ilen,"Cannot copy the latest rates");
      CHECK(CopyBuffer(_ma6Handle,0,0,ilen,_ma6Val)==ilen,"Cannot copy MA20 buffer 0");

      for(int i=0;i<ilen;++i)
      {
        updatePriceStatistics(_rates[i],_ma6Val[i]);
      }

      _initialized = true;
    }
  }

  double normalizeLotSize(double lot)
  {
    // return MathMax(MathCeil(lot*100)/100,0.01);
    return MathMax(MathFloor(lot*100)/100,0.01);
  }

  void toggleHedge(ENUM_ORDER_TYPE order, double entry)
  {
    // close current position:
    closePosition();

    _prevOrder = order;

    // So first we compute how much money we are about to loose:
    // Taking into account that we pay the bid price:
    // the lost in curreny is the lost in number of points multiplied by the current number of lots
    // And multiplied by the contract size, thus:
    double lost = MathAbs(entry - _prevEntry)*_prevSize;
    _totalLost += lost;
    
    // Now check if we really want to keep this lot size of if we just accept this loosing trade:
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    // If this current total lost is too big, we may just cut the losses:
    if( 100.0*_totalLost*_contractSize/balance > _riskLevel )
    {
      logDEBUG("Detected too much risk, stopping lot scale up.")
      // Stop the scale up:
      // _prevSize = _lotBaseSize;
      return;
    }

    // Update the new entry value:
    _prevEntry = entry;

    // Compute the current band details.

    // we will now want the take profit to be at:
    double tp = order==ORDER_TYPE_BUY ? _zoneHigh + _targetProfit : _zoneLow - _targetProfit;

    // and we want to compute the lot size to ensure we can cover the previous lost:
    // What we will get if successfull is (in points):
    // double gain = (tp - _prevEntry) * lotsize;
    // And we want this gain to cover the lost plus say 10 points:
    if(_totalLost==0.0)
    {
      _prevSize = _lotBaseSize;
    }
    else 
    {
      _prevSize = (_totalLost+_minGain)/MathAbs(tp - _prevEntry);  
    }
    
    // round this to a value lot number:
    _prevSize = normalizeLotSize(_prevSize);
    _bounceCount++;

    logDEBUG(TimeCurrent() <<": Bounce " << _bounceCount <<": Entering "<< (order==ORDER_TYPE_BUY ? "LONG" : "SHORT") <<" position at "<< _prevEntry << " with " << _prevSize << " lots. (totalLost: "<<NormalizeDouble(_totalLost,6)<<")")
    if(!sendDealOrder(_prevOrder,_prevSize,_prevEntry,0.0,tp))
    {
      // Could not place a new order (too much risk ?)
      // So we just close the current position:
      closePosition();
    };
  }

  void handleTick()
  {
    CHECK(_initialized,"Not initialized ?")

    // Check if we need to update the price statistics:
    if(TimeCurrent()-_lastMinute >= 3600)
    {
      // logDEBUG("Updating price statistic...")
      CHECK(CopyRates(_symbol,PERIOD_H1,0,1,_rates)==1,"Cannot copy the latest rates");
      CHECK(CopyBuffer(_ma6Handle,0,0,1,_ma6Val)==1,"Cannot copy MA20 buffer 0");

      updatePriceStatistics(_rates[0],_ma6Val[0]);
    }


    MqlTick latest_price;
    CHECK(SymbolInfoTick(_symbol,latest_price),"Cannot retrieve latest price.")
    double bid = latest_price.bid;

    if(selectPosition())
    {
      // We already have a position opened
      // We just need to monitor the crossing of the zone recovery borders.
      // Check what is the current position:
      bool isBuy = PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      
      if(isBuy && bid > _zoneHigh + _targetProfit)
      {
        // Update the stoploss of the position:
        double nsl = bid-_priceDev/2.0;
        if( nsl > PositionGetDouble(POSITION_SL))
        {
          updateSLTP(nsl);
        } 
      }
      if(!isBuy && bid < _zoneLow - _targetProfit)
      {
        // Update the stoploss of the position:
        double nsl = bid+_priceDev/2.0;
        if( nsl < PositionGetDouble(POSITION_SL))
        {
          updateSLTP(nsl);
        }
      }

      if(!isBuy && bid > _zoneHigh) 
      {
        toggleHedge(ORDER_TYPE_BUY,latest_price.ask);
      }
      if(isBuy && bid < _zoneLow) 
      {
        toggleHedge(ORDER_TYPE_SELL,latest_price.bid);
      }
    }
    else {
      // // Record the max bound value:
      // _maxBounceStats.push_back(_bounceCount);

      // if(_maxBounceStats.front()>0)
      // {
      //   logDEBUG("Max bounce mean: "<< _maxBounceStats.mean()<<", max bounce dev: "<<_maxBounceStats.deviation());
      // }

      // Now check if we should enter a trade...
      // to make a decision, we look at the current price value, relative to the
      // mean price value:
      double price = latest_price.bid;
      double spread = latest_price.ask - latest_price.bid;
      // logDEBUG("Current spread: "<<spread)

      if(_priceDev < 4*spread)
      {
        // Do not consider entering a trade in that case.
        return;
      }

      double delta = price - _ma6Val[0];

      // logDEBUG("Detected valid price deviation. Normalized price:"<< ((delta-_priceMean)/_priceDev))

      _prevSize = 0.0;
      // Record the zone borders:
      _bounceCount = 0;
      _totalLost = 0.0;
      _bandSize = _priceDev;
      _zoneWidth = _bandSize/7.0;
      _targetProfit = _bandSize*3.0/7.0;

      // Ensre that the resulting zone recovery is not two small:
      // double point = _security.getPoint();
      // if(_zoneWidth < 50*point)
      // {
      //   // Do not enter a trade.
      //   return;
      // }

      if((delta - _priceMean) > _priceDev)
      {
        // We should enter a buy position.
        logDEBUG(TimeCurrent()<<": Enter LONG position with band size: "<<_bandSize)
        _zoneHigh = latest_price.ask;
        _zoneLow = _zoneHigh - _zoneWidth;
        toggleHedge(ORDER_TYPE_BUY,latest_price.ask);
      }

      if((delta - _priceMean) < -_priceDev)
      {
        logDEBUG(TimeCurrent()<<": Enter SHORT position with band size: "<<_bandSize)
        _zoneLow = latest_price.bid;
        _zoneHigh = _zoneLow + _zoneWidth;
        toggleHedge(ORDER_TYPE_SELL,latest_price.bid);
      }
    }
  }
};
