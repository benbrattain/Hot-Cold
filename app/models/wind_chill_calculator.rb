class WindChillCalculator

  attr_accessor :forecast, 
                :wind_chill

  def initialize(forecast)
    @forecast = forecast
  end

  def calculate
    i = 0
    self.wind_chill = []
    while i < 36 do 
      temp = temp(i)
      wind_speed = wind_speed(i)
      wind_chill_calc = (35.74+(0.6215*temp)-(35.75*(wind_speed**0.16))+(0.4275*temp*(wind_speed**0.16))).to_i
      self.wind_chill << wind_chill_calc
      i += 1
    end 
    self.wind_chill
  end

  def temp(i)
    temp = forecast.temperature[i].to_f
  end

  def wind_speed(i)
    wind_speed = forecast.wind_speed[i].to_f
  end

end