class Forecast < ActiveRecord::Base
attr_accessor :zip_output, :weather_output, :url, :city_slug, :temperature, :hours, :humidity



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
  
  def collect_hours
    self.hours = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["FCTTIME"]["hour"]}
  end

  def collect_humidity
    self.humidity = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["humidity"]}
  end

  def collect_temperature
    self.temperature = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["temp"]["english"]}
  end

  def collect_data
    self.scrape_json
    self.collect_hours
    self.collect_temperature
    self.collect_humidity
  end


#   def full_heat_index(temp, rh)
#    (-42.379 + (2.04901523*temp) + (10.14333127*rh) - (0.22475541*temp*rh) - (0.00683783*temp*temp) - (0.05481717*rh*rh) + (0.00122874*temp*temp*rh) + (0.00085282*temp*rh*rh) - (0.00000199*temp*temp*rh*rh)).to_i
# end

# def simple_heat_index(temp, rh)
#   (@simple_hi = 0.5 * (temp + 61 + ((temp-68)*1.2) + (rh*0.094))).to_i
# end

# def low_huminity_high_heat_adjustment(temp,rh)
#   (((13-rh)/4)*((17-((temp-95).abs))/17)**0.5).to_i
# end

# def high_huminity_high_heat_adjustment(temp,rh)
#   (((rh-85)/10) * ((87-temp)/5)).to_i
# end

# def low_huminidity_and_hot?(temp,rh)
#   ((rh < 13) && (temp >= 80) && (temp < 112))
# end

# def high_humidity_and_hot?(temp,rh)
#   ((rh > 85) && (temp >= 80) && (temp <= 87))
# end

# def runner(temp, rh)
#   if (@simple_hi.to_i+temp)/2 >= 80
#     # apply full regression equation with or without adjustments
#     if low_huminidity_and_hot?(temp,rh)
#       puts full_heat_index(temp, rh)-low_huminity_high_heat_adjustment(temp,rh)
#     elsif high_humidity_and_hot?(temp,rh)
#       puts full_heat_index(temp, rh)-high_huminity_high_heat_adjustment(temp,rh)
#     else
#       puts full_heat_index(temp, rh)
#     end
#   else
#     # return simple heat index
#     puts simple_heat_index(temp, rh)
#   end
# end # ends runner


end
