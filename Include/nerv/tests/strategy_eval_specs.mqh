
#include <nerv/unit/Testing.mqh>
#include <nerv/core.mqh>
#include <nerv/trades.mqh>

BEGIN_TEST_PACKAGE(strategy_eval_specs)

BEGIN_TEST_SUITE("Strategy evaluation")

BEGIN_TEST_CASE("should support evaluation of strategy")

  nvStrategyEvalConfig cfg;

 	cfg.straits.symbol("EURUSD").period(PERIOD_M1);
  cfg.straits.historyLength(0);
  cfg.straits.autoWriteHistory(false); 
  cfg.straits.id("test1_eur");
	
  // Keep history:
  cfg.mtraits.historyLength(0);
  // Do not write history data to disk.
  cfg.mtraits.autoWriteHistory(false); 
  cfg.mtraits.id("test1_eur");

  // Settings:
  double tcost = 0.000001;
  cfg.straits.warmUpLength(0);
  cfg.straits.signalThreshold(0.0);
  cfg.straits.signalAdaptation(0.01); // This as no effect for now => Signal EMA not used.
  cfg.straits.signalMeanLength(100);
  cfg.straits.transactionCost(tcost);
  
  cfg.mtraits.transactionCost(tcost);  
  cfg.mtraits.batchTrainLength(2000);
  cfg.mtraits.batchTrainFrequency(500);
  cfg.mtraits.onlineTrainLength(-1);
  cfg.mtraits.lambda(0.0);
  cfg.mtraits.numInputReturns(10);
  cfg.mtraits.maxIterations(30);

  cfg.mtraits.trainMode(TRAIN_STOCHASTIC_GRADIENT_DESCENT);
  cfg.mtraits.warmInit(true);
  cfg.mtraits.numEpochs(15);
  cfg.mtraits.learningRate(0.01);

  cfg.prices_mode = REAL_PRICES;
  cfg.prices_start_time =  D'21.02.2015 12:00:00';
  cfg.prices_step_size = 500;
  cfg.num_prices = 20000;
  // cfg.num_prices = 10000;
  cfg.num_iterations = 161;
  // cfg.num_iterations = 4;

  cfg.sendReportMail = true;

  nvStrategyEvaluator::evaluate(cfg);
END_TEST_CASE()

XBEGIN_TEST_CASE("should support computing long term profit")
  nvStrategyTraits straits;
  straits.symbol("EURUSD").period(PERIOD_M1);
  straits.historyLength(0);
  straits.autoWriteHistory(false); 
  straits.id("test1_eur");
  
  // Prepare the model traits:
  nvRRLModelTraits mtraits;

  // Keep history:
  mtraits.historyLength(0);
  // Do not write history data to disk.
  mtraits.autoWriteHistory(false); 
  mtraits.id("test1_eur");

  // Settings:
  double tcost = 0.000001;
  straits.warmUpLength(0);
  straits.signalThreshold(0.0);
  straits.signalAdaptation(0.01); // This as no effect for now => Signal EMA not used.
  straits.signalMeanLength(100);
  straits.transactionCost(tcost);
  
  mtraits.transactionCost(tcost);  
  mtraits.batchTrainLength(2000);
  mtraits.batchTrainFrequency(500);
  mtraits.onlineTrainLength(-1);
  mtraits.lambda(0.0);
  mtraits.numInputReturns(10);
  mtraits.maxIterations(30);

  mtraits.trainMode(TRAIN_STOCHASTIC_GRADIENT_DESCENT);
  mtraits.warmInit(true);
  mtraits.numEpochs(15);
  mtraits.learningRate(0.01);

  // int offset = 0;
  datetime starttime = D'21.10.2014 12:00:00';
  // logDEBUG("Current time GMT: "<<TimeGMT());
  // logDEBUG("Current time Local: "<<TimeLocal());

  int count = 100000;

  double arr[];
  // int res = CopyClose(symbol, period, offset, count, arr);
  int res = CopyClose(straits.symbol(), straits.period(), starttime, count, arr);
  REQUIRE_EQUAL(res,count);

  // build a vector from the prices:
  nvVecd all_prices(arr);

  nvVecd rets = all_prices.subvec(1,all_prices.size()-1) - all_prices.subvec(0,all_prices.size()-1);
  logDEBUG("Global returns mean: "<<rets.mean()<<", dev:"<<rets.deviation());
  
  mtraits.fixReturnsMeanDev(rets.mean(),rets.deviation());

  nvVecd prices = all_prices;

  nvStrategy st(straits);

  st.setModel(new nvRRLModel(mtraits));

  st.dryrun(prices);

  {
    // Now retrieve the wealth data from the strategy itself:
    nvVecd* wealth = (nvVecd*)st.getHistoryMap().get("strategy_wealth");
    REQUIRE_VALID_PTR(wealth);
    double fw = wealth.back();
    logDEBUG("Long St. final wealth: "<<fw);
    wealth.writeTo("test_long_strategy_wealth.txt");

    // Compute the max drawndown of this run:
    double dd = computeMaxDrawnDown(wealth);
    logDEBUG("Long St. max drawdown "<<dd);
  }

  {
    // Retrieve the number of deals performed:
    nvVecd* ndeals = (nvVecd*)st.getHistoryMap().get("strategy_num_deals");
    REQUIRE_VALID_PTR(ndeals);
    double nd = ndeals.back();
    logDEBUG("Long St. num deals: "<<nd);
  }

  all_prices.writeTo("test_long_strategy_prices.txt");

END_TEST_CASE()

END_TEST_SUITE()

END_TEST_PACKAGE()
