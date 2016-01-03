/*
Implementation of RNN trader.

This trader will read the prediction data from a csv file
and then use those predictions to place orders.
*/

#property copyright "Copyright 2015, Nervtech"
#property link      "http://www.nervtech.org"

#property version   "1.00"

#property tester_file "eval_results_v36.csv"

#include <nerv/unit/Testing.mqh>
#include <nerv/core.mqh>
#include <nerv/rnn/RNNTrader.mqh>

input int   gTimerPeriod=1;  // Timer period in seconds

nvRNNTrader* trader = NULL;

// Initialization method:
int OnInit()
{
  logDEBUG("Initializing Nerv RNN Expert.")

  nvLogManager* lm = nvLogManager::instance();
  string fname = "rnn_ea_v01.log";
  nvFileLogger* logger = new nvFileLogger(fname);
  lm.addSink(logger);
  
  trader = new nvRNNTrader();

  // Initialize the timer:
  CHECK_RET(EventSetTimer(gTimerPeriod),0,"Cannot initialize timer");
  return 0;
}

// Uninitialization:
void OnDeinit(const int reason)
{
  logDEBUG("Uninitializing Nerv RNN Expert.")
  EventKillTimer();

  // Destroy the trader:
  RELEASE_PTR(trader);
}

// OnTick handler:
void OnTick()
{
  trader.onTick();
}

void OnTimer()
{
  // We call the timer every second because we don't know if we are
  // on sec 0, and this is what we should compute here:
  datetime ctime = TimeCurrent();
  MqlDateTime dts;
  TimeToStruct(ctime,dts);

  // Zero the number of seconds:
  ctime = ctime - dts.sec;

  // Sent to the trader to see if an update cycle is required:
  trader.update(ctime);
}
