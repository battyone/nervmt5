#include <nerv/core.mqh>

#include <nerv/rnn/TraderBase.mqh>
#include <nerv/rnn/PredictionSignalFile.mqh>
#include <nerv/rnn/RemoteSignal.mqh>

/*
Class: nvSecurityTrader

Base class representing a trader 
*/
class nvSecurityTrader : public nvTraderBase
{
protected:
  // Last update time value, used to keep track
  // of the last time this trader was updated, to avoid double updates.
  datetime _lastUpdateTime;

  // Prediction signal:
  nvPredictionSignal* _predictors[];

  nvSecurity _security;

  // List of symbol names that are used as input for this trader:
  // By convention, the predicted symbol should always be the first one
  // in the list.
  string _inputs[];

  // Threshold used to check if the signal we received is good enough
  // for an entry:
  double _entryThreshold;

  // Current value of the entry signal:
  double _lastEntrySignal;

  // Level of risk:
  double _riskLevel;

  // open price of the current position if any.
  double _openPrice;

  // True if current position is a buy:
  bool _isBuy;

  // True if the current position has locked profit.
  bool _profitable;

  string _symbol;
  
public:
  /*
    Class constructor.
  */
  nvSecurityTrader(string symbol, double entry)
    : _security(symbol)
  {
    logDEBUG("Creating Security Trader for "<<symbol)

    _symbol = symbol;

    // Add this symbol as input:
    addInputSymbol(symbol);

    // Initialize the last update time:
    _lastUpdateTime = 0;

    // We enter only when the signal abs value is higher than:
    _entryThreshold = entry;

    // Last value of the entry signal:
    _lastEntrySignal = 0.0;

    // 1% of risk:
    _riskLevel = 0.01;

    _isBuy = false;
    _profitable = false;
  }

  /*
    Copy constructor
  */
  nvSecurityTrader(const nvSecurityTrader& rhs) : _security("")
  {
    this = rhs;
  }

  /*
    assignment operator
  */
  void operator=(const nvSecurityTrader& rhs)
  {
    THROW("No copy assignment.")
  }

  /*
    Class destructor.
  */
  ~nvSecurityTrader()
  {
    logDEBUG("Deleting SecurityTrader")
    int len = ArraySize( _predictors );
    for(int i = 0;i<len;++i)
    {
      RELEASE_PTR(_predictors[i]);  
    }

    ArrayResize( _predictors, 0 );
  }

  /*
  Function: addInputSymbol
  
  Method used to add an input symbol
  */
  void addInputSymbol(string symbol)
  {
    // Ensure that this symbol is activated:
    SymbolSelect(symbol,true);
    nvAppendArrayElement(_inputs,symbol);
  }
  
  /*
  Function: addInputSymbols
  
  Method used to add multiple input symbols
  */
  void addInputSymbols(string &symbols[])
  {
    int len = ArraySize( symbols );
    for(int i = 0;i<len;++i)
    {
      addInputSymbol(symbols[i]);
    }
  }
  
  /*
  Function: addPredictor
  
  Add a predictor from a file
  */
  void addPredictor(string file, int minId = -1, int maxId = -1)
  {
    nvPredictionSignal* pred = new nvPredictionSignalFile(file,minId,maxId); //"eval_results_v36.csv"

    // append to the list:
    nvAppendArrayElement(_predictors,pred);
  }
  
  /*
  Function: addRemotePredictor
  
  Add a remote predictor
  */
  void addRemotePredictor(string address)
  {
    nvPredictionSignal* pred = new nvRemoteSignal(address,_inputs);

    // append to the list:
    nvAppendArrayElement(_predictors,pred);
  }
  
  /*
  Function: getPrediction
  
  Method used to build the compound prediction from all predictors:
  */
  double getPrediction(datetime ctime)
  {
    int len = ArraySize( _predictors );
    int count = 0;
    double result = 0.0;

    for(int i=0;i<len;++i)
    {
      double pred = _predictors[i].getPrediction(ctime);
      if(pred!=0.0) {
        count++;
        result += pred;
      }
    }

    return count==0 ? 0.0 : result/count;
  }
  
  /*
  Function: update
  
  Method called to update the state of this trader 
  normally once per minute
  */
  virtual void update(datetime ctime)
  {
    if(_lastUpdateTime>=ctime)
      return; // Nothing to process.

    _lastUpdateTime = ctime;
    // logDEBUG("Update cycle at: " << ctime << " = " << (int)ctime)

    // Retrieve the prediction signal at that time:
    double pred = getPrediction(ctime);

    // Check if we need to close the current position (if any)
    // if the new signal is not strong enough or if it is not
    // going in the same direction as the previous entry signal
    // we just close the position. Otherwise, we let it running
    // with the current trailing stop lost:
    // if(MathAbs(pred)>_entryThreshold || pred *_lastEntrySignal <= 0.0)
    // {
    //   closePosition(_security);
    // }
      
    if(pred!=0.0 && !hasPosition(_security)) {
      openPosition(pred);
    }
  }

  /*
  Function: openPosition
  
  Method used to open a position given a signal value
  */
  void openPosition(double signal)
  {
    // we are not currently in a trade so we check if we should enter one:
    if(MathAbs(signal)<=_entryThreshold)
      return; // Should not enter anything.

    logDEBUG("Using prediction signal " << signal)

    // the prediction is good enough, so we place a trade:
    _lastEntrySignal = signal;
    
    string symbol = _security.getSymbol();

    // Get the current spread to define the number of lost points:
    double spread = nvGetSpread(symbol);

    // double lot = evaluateLotSize(spread*2.0,1.0,signal);
    double lot = evaluateLotSize(100,1.0,signal);
    // double lot = evaluateLotSize(100,1.0,signal > 0.0 ? 0.5 : -0.5);

    double sl = 0.0; //spread*nvGetPointSize(symbol);
    double tp = 0.0; //spread*nvGetPointSize(symbol);

    MqlTick last_tick;
    CHECK(SymbolInfoTick(symbol,last_tick),"Cannot retrieve last tick");
    
    _openPrice = signal > 0 ? last_tick.ask : last_tick.bid;
    _isBuy = signal > 0;

    // Send the order:
    int otype = signal>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    sendDealOrder(_security, otype, lot, 0.0, sl, tp);

    // Initialy not profitable.
    _profitable = false;
  }
  
  /*
  Function: evaluateLotSize
  
  Main method of this class used to evaluate the lot size that should be used for a potential trade.
  */
  double evaluateLotSize(double numLostPoints, double traderWeight, double confidence)
  {
    CHECK_RET(0.0<=traderWeight && traderWeight <= 1.0,0.0,"Invalid trader weight: "<<traderWeight);

    string symbol = _security.getSymbol();

    // First we need to convert the current balance value in the desired profit currency:
    string quoteCurrency = nvGetQuoteCurrency(symbol);
    double balance = nvGetBalance(quoteCurrency);

    // Now we determine what fraction of this balance we can risk:
    double VaR = balance * _riskLevel * traderWeight * MathAbs(confidence); // This is given in the quote currency.

    // Now we can compute the final lot size:
    // The worst lost we will achieve in the quote currency is:
    // VaR = lost = lotsize*contract_size*num_point
    // thus we need lotsize = VaR/(contract_size*numPoints) = VaR / (point_value * numPoints)
    // Also: we should prevent the lost point value to go too low !!
    double lotsize = VaR/(nvGetPointValue(symbol)*MathMax(numLostPoints,1.0));
    
    logDEBUG("Normalizing lotsize="<<lotsize<<", with lostPoints="<<numLostPoints<<", VaR="<<VaR
      <<", balance="<<balance<<", quoteCurrency="<<quoteCurrency<<", confidence="<<confidence
      <<", weight="<<traderWeight<<", riskLevel="<<_riskLevel);

    // logDEBUG("Margin call level: "<<marginCall<<", margin stop out: "<<marginStopOut);

    // We should not allow the trader to enter a deal with too big lot size,
    // otherwise, we could soon not be able to trade anymore.
    // So we should also apply the risk level trader weight and confidence level on this max lot size:
    // if (lotsize>5.0)
    // {
    //   logDEBUG("Clamping lot size to 5.0")
    //   lotsize = 5.0;
    // }

    // Compute the new margin level:
    // double marginLevel = lotsize>0.0 ? 100.0*(equity+dealEquity)/(currentMargin+dealMargin) : 0.0;

    // if(lotsize>maxlot) { //0 && marginLevel<=marginCall
    //   logDEBUG("Detected margin call conditions: "<<lotsize<<">="<<maxlot);
    // }

    // finally we should normalize the lot size:
    lotsize = nvNormalizeLotSize(lotsize,symbol);

    return lotsize;
  }

  virtual double getTrailDelta(MqlTick& last_tick)
  {
    return last_tick.ask - last_tick.bid;
  }

  virtual void checkPosition()
  {
    // No op.
  }

  void onTick()
  {
    if(!hasPosition(_security))
      return; // nothing to do.

    checkPosition();

    if(!hasPosition(_security))
      return; // nothing to do.

    string symbol = _security.getSymbol();

    // We have an open position.
    // Get the current tick data:
    MqlTick last_tick;
    CHECK(SymbolInfoTick(symbol,last_tick),"Cannot retrieve last tick");

    double spread = last_tick.ask - last_tick.bid;

    double sl = PositionGetDouble(POSITION_SL);

    // Maximum number of lost spread:
    double maxLost = 10.0;

    double trail = getTrailDelta(last_tick);

    if(trail<0.0)
      return; // Nothing to trail.

    if(_isBuy)
    {
      // We are in a long position:
      // secure the gain if the current values are high enough:
      double diff = last_tick.bid - _openPrice;
      double nsl = last_tick.bid - trail;
      if(diff>0.0 && nsl>sl) {
        updateSLTP(_security,nsl);
        _profitable = true;
      }
      // if(diff < -maxLost*spread) 
      // {
      //   closePosition(_security);
      // }
    }
    else {
      double diff = _openPrice - last_tick.ask;
      double nsl = last_tick.bid + trail;
      if(diff>0.0 && (nsl<sl || sl==0.0)) {
        updateSLTP(_security,nsl);
        _profitable = true;
      }
      // if(diff < -maxLost*spread) 
      // {
      //   closePosition(_security);
      // }
    }
  }
};
