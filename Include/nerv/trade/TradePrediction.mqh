
#include <nerv/core.mqh>
#include <nerv/math.mqh>

/*
Base class representing the data that can be passed to the RRL model class.
*/
class nvTradePrediction : public nvObject
{
protected:
  double _signal;
  double _confidence;

public:
  /* Default constructor,
  assign default values.*/
  nvTradePrediction();

  /* Copy constructor, will copy the values from the original */
  nvTradePrediction(const nvTradePrediction &rhs);

  /* Assignment operator. */
  nvTradePrediction *operator=(const nvTradePrediction &rhs);

  /* Assign a signal to this prediction. */
  nvTradePrediction* signal(double sig);

  /* Retrieve the signal assigned to this prediction. */
  double signal() const;

  /* Assign aconfidence to this prediction. */
  nvTradePrediction* confidence(double conf);

  /* Retrieve the confidence assigned to this prediction. */
  double confidence();
};


///////////////////////////////// implementation part ///////////////////////////////

nvTradePrediction::nvTradePrediction()
  : _signal(0.0),
  _confidence(0.0)
{
}

nvTradePrediction::nvTradePrediction(const nvTradePrediction &rhs)
{
  this = rhs;
}

nvTradePrediction *nvTradePrediction::operator=(const nvTradePrediction &rhs)
{
  _signal = rhs._signal;
  _confidence = rhs._confidence;
  return GetPointer(this);
}

nvTradePrediction* nvTradePrediction::signal(double sig)
{
  _signal = sig;
  return GetPointer(this);
}

double nvTradePrediction::signal() const
{
  return _signal;
}

nvTradePrediction* nvTradePrediction::confidence(double conf)
{
  _confidence = conf;
  return GetPointer(this);
}

double nvTradePrediction::confidence()
{
  return _confidence;
}
