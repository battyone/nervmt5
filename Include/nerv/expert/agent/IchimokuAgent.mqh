#include <nerv/core.mqh>
#include <nerv/expert/TradingAgent.mqh>

/*
Class: nvIchimokuAgent

Class used as a base class to represent a trading agent in a given
currency trader.
*/
class nvIchimokuAgent : public nvTradingAgent
{

protected:
  int _ichiHandle;
  double _tenkanVal[];
  double _kijunVal[];
  double _senkouAVal[];
  double _senkouBVal[];
  double _chinkouVal[];
  MqlRates _rates[];

public:
  /*
    Class constructor.
  */
  nvIchimokuAgent(nvCurrencyTrader* trader) : nvTradingAgent(trader)
  {
    _agentType = TRADE_AGENT_ICHIMOKU;
    _agentCapabilities = TRADE_AGENT_ENTRY_EXIT; // No support by default.
    _ichiHandle = 0;
    randomize();
  }

  /*
    Copy constructor
  */
  nvIchimokuAgent(const nvIchimokuAgent& rhs) : nvTradingAgent(rhs)
  {
    this = rhs;
  }

  /*
    assignment operator
  */
  void operator=(const nvIchimokuAgent& rhs)
  {
    THROW("No copy assignment.")
  }

  /*
    Class destructor.
  */
  ~nvIchimokuAgent()
  {
    if(_ichiHandle>0) {
      IndicatorRelease(_ichiHandle);
    }
  }
 
  /*
  Function: randomize
  
  Method called to randomize the values of the parameters for this agent.
  */
  virtual void randomize()
  {
    randomizeLag(AGENT_MAX_LAG);
    randomizePeriod(PERIOD_H1,PERIOD_D1);
  }
  
  /*
  Function: clone
  
  Method called to clone this agent
  */
  virtual nvTradingAgent* clone()
  {
    // We should not be able to clone this base class by default:
    nvTradingAgent* agent = new nvIchimokuAgent(_trader);
    return agent;
  }
  
  /*
  Function: initialize
  
  Method called to initialize this trader on due time
  */
  virtual void initialize()
  {
    // At this point we can initialize the agent ressources:
    _ichiHandle=iIchimoku(_symbol,_period,9,26,52);
    CHECK(_ichiHandle>0,"Invalid Ichimoku handle");

    ArraySetAsSeries(_tenkanVal,true);
    ArraySetAsSeries(_kijunVal,true);
    ArraySetAsSeries(_senkouAVal,true);
    ArraySetAsSeries(_senkouBVal,true);
    ArraySetAsSeries(_chinkouVal,true);
    ArraySetAsSeries(_rates,true);

  }

  /*
  Function: checkBuyConditions
  
  Helper method to check for buy conditions for ichimoku
  */
  bool checkBuyConditions()
  {
    // We can only buy when the close price is above the cloud:
    if(_rates[0].close < _senkouAVal[0] || _rates[0].close < _senkouBVal[0])
    {
      return false;
    }

    // We should also ensure that the kijun itself is above the cloud:
    if(_kijunVal[0] <= _senkouAVal[0] || _kijunVal[0] <= _senkouBVal[0])
    {
      return false;
    }

    // We must also ensure that tenkan sen line is above the kijun sen line at that time:
    if(_tenkanVal[0] <= _kijunVal[0])
    {
      return false;
    }

    return true;
    // TODO: we could also add a signal from the chinkou line here    
  }
  
  /*
  Function: checkSellConditions
  
  Helper method used to check for sell conditions
  */
  bool checkSellConditions()
  {
    // We can only sell when the close price is above the cloud:
    if(_rates[0].close > _senkouAVal[0] || _rates[0].close > _senkouBVal[0])
    {
      return false;
    }

    // We should also ensure that the kijun itself is under the cloud:
    if(_kijunVal[0] >= _senkouAVal[0] || _kijunVal[0] >= _senkouBVal[0])
    {
      return false;
    }

    // We must also ensure that tenkan sen line is above the kijun sen line at that time:
    if(_tenkanVal[0] >= _kijunVal[0])
    {
      return false;
    }

    return true;
    // TODO: we could also add a signal from the chinkou line here    
  }
  
  /*
  Function: collectData
  
  Method used to retrieve the current relevant data for decision evaluation
  */
  void collectData()
  {
    int num = 2;
    CHECK(CopyRates(_symbol,_period,1,30,_rates)==30,"Cannot copy the latest rates");
    CHECK(CopyBuffer(_ichiHandle,0,1,num,_tenkanVal)==num,"Cannot copy Ichimoku buffer 0");
    CHECK(CopyBuffer(_ichiHandle,1,1,num,_kijunVal)==num,"Cannot copy Ichimoku buffer 1");
    CHECK(CopyBuffer(_ichiHandle,2,1,4,_senkouAVal)==4,"Cannot copy Ichimoku buffer 2");
    CHECK(CopyBuffer(_ichiHandle,3,1,4,_senkouBVal)==4,"Cannot copy Ichimoku buffer 3");
    CHECK(CopyBuffer(_ichiHandle,4,1,30,_chinkouVal)==30,"Cannot copy Ichimoku buffer 4");

  }
  
  /*
  Function: computeEntryDecision
  
  Method called to compute the entry decision taking into account the lag of this agent.
  This method should be reimplemented by derived classes that can provide entry decision.
  */
  virtual double computeEntryDecision(datetime time)
  {
    // Entry is only called when we are not in a position, so we should have no position
    // here:
    CHECK_RET(_trader.hasOpenPosition()==false,0.0,"Should not have an open position here");

    if(checkBuyConditions()) {
      return 1.0; // produce a buy signal.
    }

    if(checkSellConditions()) {
      return -1.0; // produce a sell signal
    }

    // Produce no signal at all:
    return 0.0;
  }
  
  /*
  Function: computeExitDecision
  
  Method called to compute the exit decision taking into account the lag of this agent.
  This method should be reimplemented by derived classes that can provide exit decision. 
  */
  virtual double computeExitDecision(datetime time)
  {
    // TODO: Provide implementation
    THROW("No implementation");
    return 0.0;
  }
};
