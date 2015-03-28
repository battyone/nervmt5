
#include <nerv/core.mqh>
#include <nerv/math.mqh>
#include <nerv/trades.mqh>
#include <nerv/trade/Strategy.mqh>
#include <nerv/trade/rrl/RRLModel.mqh>

enum EvalPricesMode
{
  REAL_PRICES,
  ARTIFICIAL_PRICES
};

struct nvStrategyEvalConfig
{
  nvStrategyTraits straits;
  nvRRLModelTraits mtraits;

  nvVecd prices;
  nvVecd st_final_wealth;
  nvVecd st_max_dd;
  nvVecd st_num_deals;

  ulong duration;

  bool sendReportMail;

  // When using real prices we need the following entries:
  datetime prices_start_time;
  int prices_step_size;

  int num_prices;
  int num_iterations;

  // Artificial prices parameters:
  double prices_alpha;
  double prices_k;

  // Selection of the prices mode.
  EvalPricesMode prices_mode;

  // Usage of compounded return log:
  bool use_log_prices;
};

class nvStrategyEvaluator
{
public:
  static void reportEvaluationResults(const nvStrategyEvalConfig& cfg);
  static void evaluateStrategy(nvStrategyEvalConfig& cfg);
  static void evaluate(nvStrategyEvalConfig& cfg);
};

void nvStrategyEvaluator::evaluateStrategy(nvStrategyEvalConfig& cfg)
{
  nvStrategy st(cfg.straits);

  st.setModel(new nvRRLModel(cfg.mtraits));

  st.dryrun(cfg.prices);

  // Now retrieve the wealth data from the strategy itself:
  nvVecd* wealth = (nvVecd*)st.getHistoryMap().get("strategy_wealth");
  CHECK_PTR(wealth, "Invalid pointer");
  double fw = wealth.back();
  logDEBUG("Acheived St. final wealth: " << fw);
  cfg.st_final_wealth.push_back(fw);

  // Compute the max drawndown of this run:
  double dd = computeMaxDrawnDown(wealth);
  logDEBUG("Acheived St. max drawdown " << dd);
  cfg.st_max_dd.push_back(dd);
  // Retrieve the number of deals performed:
  nvVecd* ndeals = (nvVecd*)st.getHistoryMap().get("strategy_num_deals");
  CHECK_PTR(ndeals, "Invalid pointer");
  double nd = ndeals.back();
  logDEBUG("Acheived St. num deals: " << nd);
  cfg.st_num_deals.push_back(nd);
}

void nvStrategyEvaluator::reportEvaluationResults(const nvStrategyEvalConfig& cfg)
{
  nvStringStream os;
  os << "St. Wealth mean: " << cfg.st_final_wealth.mean() << "\n";
  os << "St. Wealth deviation: " << cfg.st_final_wealth.deviation() << "\n";
  cfg.st_final_wealth.writeTo("test_final_wealth.txt");

  os << "St. Max DrawDown mean: " << cfg.st_max_dd.mean() << "\n";
  os << "St. Max DrawDown deviation: " << cfg.st_max_dd.deviation() << "\n";
  cfg.st_max_dd.writeTo("test_max_drawdown.txt");

  os << "St. Num deals mean: " << cfg.st_num_deals.mean() << "\n";
  os << "St. Num deals deviation: " << cfg.st_num_deals.deviation() << "\n";
  cfg.st_num_deals.writeTo("test_num_deals.txt");

  os << "\n";

  os << "Evaluation duration: " << formatTime(cfg.duration) << "\n";

  logDEBUG(os.str());

  if (cfg.sendReportMail)
  {
    bool res = SendMail("[MT5] - Strategy evaluation results", os.str());
    CHECK(res, "Cannot send mail.");
  }
}

void nvStrategyEvaluator::evaluate(nvStrategyEvalConfig& cfg)
{
  nvVecd all_prices;

  int count = cfg.num_prices + (cfg.num_iterations-1) * cfg.prices_step_size;

  if(cfg.prices_mode==REAL_PRICES)
  {
    double arr[];
    
    // int res = CopyClose(symbol, period, offset, count, arr);
    int res = CopyClose(cfg.straits.symbol(), cfg.straits.period(), cfg.prices_start_time, count, arr);
    CHECK(res==count,"Only read "<<res<<" elements instead of " << count);

    // build a vector from the prices:
    all_prices = arr;
  }
  else if(cfg.prices_mode==ARTIFICIAL_PRICES) {
      all_prices = nv_generatePrices(count, cfg.prices_alpha, cfg.prices_k, 1.125, 1.15);
  }
  else {
    THROW("Invalid prices mode: "<<(int)cfg.prices_mode);
  }

  if(cfg.use_log_prices)
  {
    all_prices = all_prices.log();
  }

  nvVecd rets = nv_generate_returns(all_prices);
  logDEBUG("Global returns mean: "<<rets.mean()<<", dev:"<<rets.deviation());
  
  cfg.mtraits.fixReturnsMeanDev(rets.mean(),rets.deviation());

  int tsize = cfg.num_prices;
  int step = cfg.prices_step_size;
  int numit = cfg.num_iterations;
  logDEBUG("Number of iterations: "<<numit);

  datetime startTime = TimeLocal();
  logDEBUG("Evaluation started at "<<startTime);

  int poffset = 0;
  for(int i=0;i<numit;++i)
  {
    // Generate a price serie:
    poffset = i*step;
    
    logDEBUG("Performing iteration "<<i<<" with offset="<<poffset);
    Sleep(10);

    cfg.prices = all_prices.subvec(poffset,tsize);

    evaluateStrategy(cfg);

    datetime tick = TimeLocal();
    ulong elapsed = tick - startTime;
    ulong meanDuration = (ulong) ((double)elapsed / (double)(i+1));
    // datetime completionAt = (datetime)(startTime + meanDuration * (ulong)numit);
    datetime completionAt = (datetime)(tick + meanDuration * (ulong)(numit-i+1));

    ulong left = completionAt - tick;

    // convert the number of seconds left to hours/min/secs:
    string timeLeft = formatTime(left);

    logDEBUG("Mean duration: "<<meanDuration<<" seconds. Completion at :"<<completionAt<<" ("<<timeLeft<<" left)");
  }

  cfg.duration = TimeLocal() - startTime;
  reportEvaluationResults(cfg);  
}