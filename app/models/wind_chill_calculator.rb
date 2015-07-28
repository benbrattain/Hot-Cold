class WindChillCalculator

  attr_accessor :forecast, 
                :wind_chill

  def initialize(forecast)
    @forecast = forecast
  end

  def calculate
    i = 0
    self.wind_chill = []
    while i < self.wind_speed.length do
      temp = forecast.temperature[i].to_f
      wind_speed = forecast.wind_speed[i].to_f
      wind_chill_calc = (35.74+(0.6215*temp)-(35.75*(wind_speed**0.16))+(0.4275*temp*(wind_speed**0.16))).to_i
      self.wind_chill << wind_chill_calc
      i += 1
    end # ends while
    self.wind_chill
  end

end