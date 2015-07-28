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
              :discrepancy

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

  def scrape_json
    @api_response = open(self.url).read
  end
  
  def collect_hours # returns an array of 36 elements
    self.hours = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["FCTTIME"]["hour"]}
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
    self.discrepancy_max
  end

  # http://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml
  def collect_heat_index
    i = 0
    self.heat_index = []
    while i < self.temperature.length do
      temp = self.temperature[i].to_f
      humidity = self.humidity[i].to_f
      simple_heat_index = (0.5 * (temp + 61 + ((temp-68)*1.2) + (humidity*0.094))).to_i
      full_heat_index = (-42.379 + (2.04901523*temp) + (10.14333127*humidity) - (0.22475541*temp*humidity) - (0.00683783*temp*temp) - (0.05481717*humidity*humidity) + (0.00122874*temp*temp*humidity) + (0.00085282*temp*humidity*humidity) - (0.00000199*temp*temp*humidity*humidity)).to_i
      dry_and_hot_adjustment = (((13-humidity)/4)*(((17-((temp-95).abs))/17)**0.5))  
      humid_and_hot_adjustment = ((humidity-85)/10) * ((87-temp)/5)
      if  (simple_heat_index+temp)/2 >= 80
        if ((humidity < 13) && (temp >= 80) && (temp < 112)) # especially dry and hot
          self.heat_index << (full_heat_index-dry_and_hot_adjustment).to_i
        elsif ((humidity > 85) && (temp >= 80) && (temp <= 87)) # especially humid and hot
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
  end # ends calculate_heat_index

  # http://www.srh.noaa.gov/images/epz/wxcalc/windChill.pdf
  def collect_wind_chill
    i = 0
    self.wind_chill = []
    while i < self.wind_speed.length do
      temp = self.temperature[i].to_f
      wind_speed = self.wind_speed[i].to_f
      wind_chill_calc = (35.74+(0.6215*temp)-(35.75*(wind_speed**0.16))+(0.4275*temp*(wind_speed**0.16))).to_i
      self.wind_chill << wind_chill_calc
      i += 1
    end # ends while
    self.wind_chill
  end # ends collect_wind_chill

  def set_now_statement
    temperature_now = self.temperature[0].to_i # in F
    humidity_now = self.humidity[0].to_i # in %
    time_now = Time.now.to_a[2] # returns ONLY hour in 24 hour format
    if time_now.between?(0,5) || time_now.between?(23,24)
      self.now_statement = "night time. Go to bed."
    else
      if temperature_now >= 85 
        if humidity_now >= 60
          self.now_statement = "hot and steamy!"
        else
          self.now_statement = "pretty darn hot!"
        end
      else
        if humidity_now >= 60
          self.now_statement = "not that hot, but super humid!"
        else
          self.now_statement = "not too hot, not too humid!"
        end
      end 
    end # ends time
    # self.wind_speed
  end # end set_now_statement

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

  def discrepancy?
    self.discrepancy_max
    if self.discrepancy > 3
      "Watch out! There is a difference of it will feel much hotter than forecasted."
  end



  # def get_time
  #   hour = Time.now.to_a[2]
  #   if hour.between?(0,12 )
  #     formatted_time = "#{hour}am"
  #   else
  #     formatted_time = "#{hour-12}am"
  #   end
  # end

end # ends class
