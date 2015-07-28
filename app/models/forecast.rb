class Forecast < ActiveRecord::Base

  attr_accessor :zip_output, 
              :weather_output, 
              :url, 
              :city_slug, 
              :temperature, 
              :hours, 
              :humidity, 
              :heat_index, 
              :wind_speed, 
              :wind_chill,
              :now_statement,
              :conditions_icon,
              :discrepancy,
              :discrepancy_statement,
              :max_discrepancy_index,
              :max_discrepancy_time_of_day

  def store_location
    self.store_city
    self.store_state
    self.city_to_slug
    self.to_url
  end

  def store_zip_output
    self.zip_output = ZipCodes.identify("#{self.zipcode}")
  end

  def valid_zip? 
     self.zip_output != nil
  end

  def store_city
    self.city = self.zip_output[:city]
  end

  def store_state
    self.state = self.zip_output[:state_code]
  end

  def city_to_slug
    self.city_slug = self.city.downcase.gsub(" ", "_")
  end

  def to_url
    api = ENV["weather_api"]
    self.url = "http://api.wunderground.com/api/#{api}/hourly/q/#{self.state}/#{self.city_slug}.json"
  end

  def scrape_json # creates a json object using appropriate url
    @api_response = open(self.url).read
  end
  
  def collect_hours # returns an array of 36 elements
    unformatted_hours = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["FCTTIME"]["hour"]}
    self.hours = []
    unformatted_hours.each do |hour|
      if hour.to_i.between?(13,23)
        hour = hour.to_i - 12
      elsif hour.to_i == 0
        hour = 12
      else
        hour = hour.to_i
      end
      self.hours << hour.to_s
    end
  end

  def collect_humidity # returns an array of 36 elements
    self.humidity = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["humidity"]}
  end

  def collect_temperature # returns an array of 36 elements
    self.temperature = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["temp"]["english"]}
  end

  def collect_wind_speed # returns an array of 36 elements
    self.wind_speed = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["wspd"]["english"]}
  end

  def collect_data
    self.scrape_json
    self.collect_hours
    self.collect_temperature
    self.collect_humidity
    self.collect_heat_index
    self.collect_wind_speed
    self.collect_wind_chill
    self.set_now_statement
    self.set_conditions_icon
    self.discrepancy?
  end

  # http://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml
  def collect_heat_index
    heat_index_calculator = HeatIndexCalculator.new(self)
    self.heat_index = heat_index_calculator.calculate
  end 

  # http://www.srh.noaa.gov/images/epz/wxcalc/windChill.pdf
  def collect_wind_chill
    wind_chill_calculator = WindChillCalculator.new(self)
    self.wind_chill = wind_chill_calculator.calculate
  end 

  def set_now_statement
    temperature_now = self.temperature[0].to_i # in F
    humidity_now = self.humidity[0].to_i # in %
    time_now = Time.now.to_a[2] # returns ONLY hour in 24 hour format
    if time_now.between?(0,5) || time_now.between?(23,24)
      self.now_statement = "night time. Dear Lord. Don't you sleep? "
    else
      if temperature_now >= 85 
        if humidity_now >= 60
          self.now_statement = "hot and steamy! Move to Antarctica now!"
        else
          self.now_statement = "pretty darn hot!"
        end
      elsif temperature_now.between?(65,84)
        if humidity_now >= 60
          self.now_statement = "not that hot, but super humid!"
        else
          self.now_statement = "not too hot, not too humid! Every once in a while, you can stop bitching about the weather."
        end
      elsif temperature_now.between?(42,64)
        self.now_statement = "not too warm. Layer up."
      else 
        self.now_statement = "COLD. I hope you are a penguin."
      end 
    end 
  end 

  def set_conditions_icon # shows an icon for current conditions, such as clear, overcast etc
    self.conditions_icon = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["icon_url"]}.first
  end

  def calculate_discrepancy
    self.discrepancy = []
    i = 0
    while i < 36
      num = self.heat_index[i].to_i - self.temperature[i].to_i
      self.discrepancy << num
      i += 1
    end
  end

  def discrepancy_max
    self.calculate_discrepancy
    self.discrepancy = self.discrepancy.max
  end

  def find_discrepancy_index
    calculate_discrepancy
    self.max_discrepancy_index = self.discrepancy.find_index(self.discrepancy.max)
  end

  def find_max_discrepancy_time_of_day
    find_discrepancy_index # this should return index we are looking for
    weekday_name_array = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["FCTTIME"]["weekday_name_night_unlang"]}
    self.max_discrepancy_time_of_day = weekday_name_array[self.max_discrepancy_index]
  end

  def discrepancy?
    self.discrepancy_max
    self.find_max_discrepancy_time_of_day
    if self.discrepancy.max >= 7
        self.discrepancy_statement = "Wunderground.com said it will be nice out. They are wrong. It will feel MUCH hotter than that on #{self.max_discrepancy_time_of_day}."
    elsif self.discrepancy.max.between?(4,6)
      self.discrepancy_statement = "Watch out! It will feel much hotter than forecasted on #{self.max_discrepancy_time_of_day}."
    else
      self.discrepancy_statement = "It will feel pretty close to what meteorologists are saying."
    end
  end

end # ends class
