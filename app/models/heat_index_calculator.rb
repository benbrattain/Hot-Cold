class HeatIndexCalculator

  attr_accessor :forecast, 
                :heat_index

  def initialize(forecast)
    @forecast = forecast
  end

  def calculate
    i = 0
    self.heat_index = []
    while i < forecast.temperature.length do
      temp = temp(i)
      humidity = humidity(i)
      simple_heat_index = simple_heat_index(temp, humidity)
      full_heat_index = full_heat_index(temp, humidity)
      dry_and_hot_adjustment = dry_and_hot_adjustment(temp, humidity)
      humid_and_hot_adjustment = humid_and_hot_adjustment(temp, humidity)
      
      if hot?(simple_heat_index, temp)
        if hot_and_dry?(temp, humidity) 
          self.heat_index << (full_heat_index-dry_and_hot_adjustment).to_i
        elsif hot_and_humid?(temp, humidity) 
          self.heat_index << (full_heat_index-humid_and_hot_adjustment).to_i
        else 
          self.heat_index << full_heat_index
        end
      else
        self.heat_index << simple_heat_index
      end # ends outer nested loop
        i += 1
    end # ends while
    self.heat_index
  end

  def temp(i)
    temp = forecast.temperature[i].to_f
  end

  def humid_and_hot_adjustment(temp, humidity)
    ((humidity-85)/10) * ((87-temp)/5)
  end 

  def hot?(simple_heat_index, temp)
    (simple_heat_index+temp)/2 >= 80
  end

  def hot_and_dry?(temp, humidity)
    (humidity < 13) && (temp >= 80) && (temp < 112)
  end

  def hot_and_humid?(temp, humidity)
    (humidity > 85) && (temp >= 80) && (temp <= 87)
  end

  def dry_and_hot_adjustment(temp, humidity)
    ((13-humidity)/4)*(((17-((temp-95).abs))/17)**0.5)
  end

  def humidity(i)
    humidity = forecast.humidity[i].to_f
  end

  def simple_heat_index(temp, humidity)
    (0.5 * (temp + 61 + ((temp-68)*1.2) + (humidity*0.094))).to_i
  end

  def full_heat_index(temp, humidity)
    (-42.379 + (2.04901523*temp) + 
    (10.14333127*humidity) - 
    (0.22475541*temp*humidity) - 
    (0.00683783*temp*temp) - 
    (0.05481717*humidity*humidity) + 
    (0.00122874*temp*temp*humidity) + 
    (0.00085282*temp*humidity*humidity) - 
    (0.00000199*temp*temp*humidity*humidity))
    .to_i
  end
end