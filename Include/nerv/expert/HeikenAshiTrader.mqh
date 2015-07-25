#include <nerv/core.mqh>
#include <nerv/expert/PeriodTrader.mqh>
#include <nerv/math.mqh>

/*
This trader will implement a trader based on Heiken Ashi indicators
and a moving average, in addition with a simple risk management layer.
*/

class HeikenAshiTrader : public nvPeriodTrader
{
protected:
  int _ma20Handle;
  int _ha4Handle;
  int _ha1Handle;

  double _ma20Val[];
  double _ha4Dir[];
  double _ha1Dir[];
  double _ha1High[];
  double _ha1Low[];

  double _trailingRatio;
  double _currentTarget;
  double _currentRiskPoints;
  double _slOffset;
  double _riskLevel;
  double _targetRatio;

public:
  HeikenAshiTrader(const nvSecurity& sec, ENUM_TIMEFRAMES period) : nvPeriodTrader(sec,period)
  {
    // Init the indicators:
    _ma20Handle=iMA(_symbol,_period,20,0,MODE_EMA,PRICE_CLOSE);
    _ha4Handle=iCustom(_symbol,PERIOD_H4,"Examples\\Heiken_Ashi");
    CHECK(_ha4Handle>0,"Invalid Heiken Ashi 4H handle")
    _ha1Handle=iCustom(_symbol,_period,"Examples\\Heiken_Ashi");
    CHECK(_ha1Handle>0,"Invalid Heiken Ashi 1H handle")

    // Trailing stop ratio:
    _trailingRatio = 0.5;
    _targetRatio = 2.0;
    _currentTarget = 0.0;
    _currentRiskPoints = 0.0;
    _slOffset = 10*_point;

    // factor of risk on the current balance:
    _riskLevel = 0.01; // 0.01 is 1% of value at risk.
  }

  ~HeikenAshiTrader()
  {
    IndicatorRelease(_ma20Handle);
    IndicatorRelease(_ha4Handle);
    IndicatorRelease(_ha1Handle);
  }

  bool checkBuyConditions(double& sl)
  {
    // Check major trend:
    if(_ha4Dir[0]>0.5)
    {
      // The major trend is down, so we should not buy.
      return false;
    }

    // Check moving average slope:
    if(_ma20Val[0]>_ma20Val[1] || _ma20Val[1]>_ma20Val[2] || _ma20Val[2]>_ma20Val[3])
    {
      // MA trend is incorrect.
      return false;
    }

    // check that the first dir is correct, and then we have 2 down HA candles and then
    // again an up candle:
    if(_ha1Dir[0]<0.5 && _ha1Dir[1]>0.5 && _ha1Dir[2]>0.5 && _ha1Dir[3]<0.5)
    {
      // This is a value signal, thus we should buy:
      sl = MathMin(_ha1Low[1],_ha1Low[2]);
      return true;
    }

    if(_ha1Dir[1]<0.5 && _ha1Dir[2]>0.5 && _ha1Dir[3]<0.5)
    {
      // This is a value signal, thus we should buy:
      sl = _ha1Low[2];
      return true;
    }

    return false;
  }

  bool checkSellConditions(double& sl)
  {
    // Check major trend:
    if(_ha4Dir[0]<0.5)
    {
      // The major trend is down, so we should not buy.
      return false;
    }

    // Check moving average slope:
    if(_ma20Val[0]<_ma20Val[1] || _ma20Val[1]<_ma20Val[2] || _ma20Val[2]<_ma20Val[3])
    {
      // MA trend is incorrect.
      return false;
    }

    // check that the first dir is correct, and then we have 2 down HA candles and then
    // again an up candle:
    if(_ha1Dir[0]>0.5 && _ha1Dir[1]<0.5 && _ha1Dir[2]<0.5 && _ha1Dir[3]>0.5)
    {
      // This is a value signal, thus we should buy:
      sl = MathMin(_ha1High[1],_ha1High[2]);
      return true;
    }

    if(_ha1Dir[1]>0.5 && _ha1Dir[2]<0.5 && _ha1Dir[3]>0.5)
    {
      // This is a value signal, thus we should buy:
      sl = _ha1High[2];
      return true;
    }

    return false;
  }
  
  void handleBar()
  {
    // When handling a new bar, we first check if we are already in a position or not:
    if(!selectPosition())
    {
      // If we are not in a position we check what the indicators tell us:
      // Retrieve the indicator values:
      CHECK(CopyBuffer(_ha4Handle,4,0,1,_ha4Dir)==1,"Cannot copy HA4 buffer 4");
      CHECK(CopyBuffer(_ma20Handle,0,0,4,_ma20Val)==4,"Cannot copy MA20 buffer 0");
      CHECK(CopyBuffer(_ha1Handle,1,0,4,_ha1High)==4,"Cannot copy HA1 buffer 1");
      CHECK(CopyBuffer(_ha1Handle,2,0,4,_ha1High)==4,"Cannot copy HA1 buffer 2");
      CHECK(CopyBuffer(_ha1Handle,4,0,4,_ha1Dir)==4,"Cannot copy HA1 buffer 4");

      double sl = 0.0;
      MqlTick latest_price;
      CHECK(SymbolInfoTick(_symbol,latest_price),"Cannot retrieve latest price.")

      // Check if we have buy conditions:
      if(checkBuyConditions(sl))
      {
        // Should place a buy order:
        // Check how many points we have at risk:
        sl -= _slOffset;
        _currentRiskPoints = latest_price.ask - sl;
        double lot = computeLotSize(_currentRiskPoints);
        _currentTarget = latest_price.ask + _currentRiskPoints*_targetRatio;

        if(lot>0)
        {
          logDEBUG(TimeCurrent() <<": Entering LONG position at "<< latest_price.ask << " with " << lot << " lots.")
          if(!sendDealOrder(ORDER_TYPE_BUY,lot,latest_price.ask,sl,0.0))
          {
            logERROR("Cannot place BUY order!");
          };
          return;
        }
      }

      // Check if we have sell conditions:
      if(checkSellConditions(sl))
      {
        // Should place a buy order:
        // Check how many points we have at risk:
        sl += _slOffset;
        _currentRiskPoints = sl - latest_price.bid ;
        double lot = computeLotSize(_currentRiskPoints);
        _currentTarget = latest_price.bid - _currentRiskPoints*_targetRatio;

        if(lot>0)
        {
          logDEBUG(TimeCurrent() <<": Entering SHORT position at "<< latest_price.bid << " with " << lot << " lots.")
          if(!sendDealOrder(ORDER_TYPE_SELL,lot,latest_price.bid,sl,0.0))
          {
            logERROR("Cannot place SELL order!");
          };
          return;
        }
      }
    }
  }

  double computeLotSize(double riskPoints)
  {
    // We do not want to risk more that X percent of our current balance
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double VaR = balance*_riskLevel;
    // We how that what we risk loosing in money is: p = l * riskPoints
    // Thus we should have:
    double lsize = VaR/riskPoints;
    return normalizeLotSize(lsize); // This may return 0 if the risk tolerance is too low. 
  }

  double normalizeLotSize(double lot)
  {
    return MathFloor(lot*100)/100;
  }

  void handleTick()
  {
    // if there is a position opened, we check if we need to update the trailing stop:
    if(selectPosition())
    {

      MqlTick latest_price;
      CHECK(SymbolInfoTick(_symbol,latest_price),"Cannot retrieve latest price.")
      double currentPrice = latest_price.bid;

      double sl = PositionGetDouble(POSITION_SL);
      bool isBuy = PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;

      double trail = _currentRiskPoints*_trailingRatio;

      // If there is an open position then we also know how many points
      // we initially put at risk, and how many we targeted:
      if(isBuy && currentPrice > (_currentTarget+trail))
      {
        // We may consider increasing the stop loss here:
        double nsl = currentPrice-trail;
        if (nsl > sl)
        {
          updateSLTP(nsl);
        }
      }

      if(!isBuy && currentPrice < (_currentTarget-trail))
      {
        // We may consider increasing the stop loss here:
        double nsl = currentPrice+trail;
        if (nsl < sl)
        {
          updateSLTP(nsl);
        }
      }
    } 
  }
};
