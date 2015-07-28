class Forecast < ActiveRecord::Base

attr_accessor :zip_output, :weather_output, :url, :city_slug, :temperature, :hours, :humidity, :heat_index, :wind_speed

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
    self.collect_wind_speed
    self.collect_heat_index
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
  # WindChill = 35.74 + (0.6215 × T) − (35.75 × Wind ** 0.16) + (0.4275 × T × Wind ** 0.16)
  def collect_wind_chill

  end

end # ends class
