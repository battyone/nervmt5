
#include <nerv/core.mqh>
#include <nerv/trades.mqh>
#include <nerv/trade/rrl/RRLModelTraits.mqh>

class nvRRLCostFunction_DDR : public nvCostFunctionBase
{
protected:
  nvRRLModelTraits _traits;

  nvVecd _returns;
  nvVecd _nrets;

public:
  nvRRLCostFunction_DDR(const nvRRLModelTraits &traits, const nvVecd &returns);

  virtual void computeCost();
  virtual double train(const nvVecd &initx, nvVecd &xresult);
};


//////////////////////////////////// implementation part ///////////////////////////
nvRRLCostFunction_DDR::nvRRLCostFunction_DDR(const nvRRLModelTraits &traits, const nvVecd &returns)
  : nvCostFunctionBase(traits.numInputReturns()+2)
{
  _traits = traits;
  _returns = returns;
  _nrets = returns.stdnormalize();
}

double nvRRLCostFunction_DDR::train(const nvVecd &initx, nvVecd &xresult)
{
  return train_cg(_traits,initx,xresult);
}

void nvRRLCostFunction_DDR::computeCost()
{
  // Train the model with the given inputs for a given number of epochs.
  double tcost = _traits.transactionCost();
  uint size = _returns.size();

  nvVecd theta = _x;
  uint nm = theta.size();
  uint ni = nm - 2;

  CHECK(size >= ni, "Not enough return values: " << size << "<" << ni);

  // Compute the number of samples we have:
  uint ns = size - ni + 1;
  CHECK(ns >= 2, "We need at least 2 samples to perform batch training.");

  // Initialize the rvec:
  nvVecd rvec(ni);

  double Ft, Ft_1, rt, rtn, Rt, A, DD, dsign;
  Ft_1 = A = DD = 0.0;

  // dF0 is a zero vector.
  nvVecd dFt_1(nm);
  nvVecd dFt(nm);
  nvVecd dRt(nm);

  nvVecd sumdRt(nm);
  nvVecd sumRtdRt(nm);

  nvVecd params(nm);

  params.set(0, 1.0);

  // Iterate on each sample:
  for (uint i = 0; i < size; ++i)
  {
    rtn = _nrets[i];
    rt = _returns[i];

    // push a new value on the rvec:
    rvec.push_back(rtn);
    if (i < ni - 1)
      continue;

    //logDEBUG("On iteration " << i <<" rt="<<rt<<", rtn="<<rtn);

    // if (i == 0 && ctx.useInitialSignal) {
    //   // Force the initial Ft_1 value:
    //   Ft_1 = ctx.initialSignal;
    // }

    // Prepare the parameter vector:
    params.set(1, Ft_1);
    params.set(2, rvec);

    // The rvec is ready for usage, so we build a prediction:
    //double val = params*theta;
    //logDEBUG("Pre-tanh value: "<<val);
    Ft = nv_tanh(params * theta);
    //logDEBUG("Prediction at "<<i<<" is: Ft="<<Ft);

    // if (i == size - 1 && _traits.useFinalSignal()) {
    //   // Force the final Ft value:
    //   Ft = _traits.finalSignal();
    // }

    // From that we can build the new return value:
    Rt = Ft_1 * rt - tcost * MathAbs(Ft - Ft_1);
    //logDEBUG("Return at "<<i<<" is Rt=" << Rt);

    // Increment the value of A and B:
    A += Rt;
    B += Rt * Rt;

    // we can compute the new derivative dFtdw
    dFt = (params + dFt_1 * theta[1]) * (1.0 - Ft * Ft);

    // Now we can compute dRtdw:
    dsign = tcost * nv_sign(Ft - Ft_1);
    dRt = dFt_1 * (rt + dsign) - dFt * dsign;

    sumdRt += dRt;
    sumRtdRt += dRt * Rt;

    // Update the recurrent values:
    Ft_1 = Ft;
    dFt_1 = dFt;
  }

  //logDEBUG("Done with all samples.");

  //logDEBUG("Num samples: " << ns);

  // Rescale A and B:
  A /= ns;
  B /= ns;

  //logDEBUG("A="<<A<<", B="<<B);

  // Rescale sumdRt and sumRtdRt:
  sumdRt *= 1.0 / ns;
  sumRtdRt *= 2.0 / ns; // There is a factor of 2 to keep in mind here.

  CHECK(B - A * A != 0.0, "Invalid values for A=" << A << " and B=" << B);

  // Now we can compute the derivatives of the sharpe ratio with respect to A and B:
  double dSdA = B / pow(B - A * A, 1.5);
  double dSdB = -0.5 * A / pow(B - A * A, 1.5);

  // finally we can compute the sharpe ratio derivative:
  _grad = (sumdRt * dSdA + sumRtdRt * dSdB) * (-1.0);

  // Compute the current sharpe ratio:
  double sr = A / MathSqrt(B - A * A);
  _cost = -sr;
}
