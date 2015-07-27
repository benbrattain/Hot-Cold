class Forecast < ActiveRecord::Base

attr_accessor :zip_output, :weather_output, :url, :city_slug, :temperature, :hours, :humidity, :heat_index

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

  def collect_data
    self.scrape_json
    self.collect_hours
    self.collect_temperature
    self.collect_humidity
    self.collect_heat_index
  end

  def collect_heat_index

    i = 0
    temp_array = self.temperature
    humidity_array = self.humidity
    heat_index_array = []

    while i < self.temperature.length do

      temp = temp_array[i].to_f
      rh = humidity_array[i].to_f

      simple_heat_index = (0.5 * (temp + 61 + ((temp-68)*1.2) + (rh*0.094.to_f))).to_i
      full_heat_index = (-42.379 + (2.04901523*temp) + (10.14333127*rh) - (0.22475541*temp*rh) - (0.00683783*temp*temp) - (0.05481717*rh*rh) + (0.00122874*temp*temp*rh) + (0.00085282*temp*rh*rh) - (0.00000199*temp*temp*rh*rh)).to_i
      
      if  (simple_heat_index+temp)/2 >= 80 
        # if low humidity and hot, use full_heat_index and appropriate adjustment
        if ((rh < 13) && (temp >= 80) && (temp < 112))
          heat_index_array << (full_heat_index-(((13-rh)/4)*((17-((temp-95).abs))/17)**0.5).to_i)
          # if high humidity and hot 
        elsif ((rh > 85) && (temp >= 80) && (temp <= 87))
          heat_index_array << (full_heat_index-(((rh-85)/10) * ((87-temp)/5)).to_i)
          # all other scenarios -- use a full heat index
        else 
          heat_index_array << full_heat_index
        end
      else # use a simple heat index
        heat_index_array << simple_heat_index
      end # ends outer nested loop
        i += 1
    end # ends while
    # binding.pry
    self.heat_index = heat_index_array
  end # ends calculate_heat_index

end # ends class
