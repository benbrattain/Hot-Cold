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
                :max_discrepancy_time_of_day,
                :status,
                :t_shirt_statement,
                :uv_index,
                :uv_statement

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

  def collect_humidity 
    self.humidity = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["humidity"]}
  end

  def collect_temperature 
    self.temperature = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["temp"]["english"]}
  end

  def collect_wind_speed 
    self.wind_speed = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["wspd"]["english"]}
  end

  def collect_status 
    self.status = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["wx"]}
  end

  def collect_data
    self.scrape_json
    self.collect_hours
    self.collect_temperature
    self.collect_humidity
    self.collect_heat_index
    self.collect_wind_speed
    self.collect_wind_chill
    self.collect_status
    self.collect_uv_index
    self.set_now_statement
    self.set_conditions_icon
    self.discrepancy?
    self.t_shirt_weather?
    self.need_suncreen?
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

  def set_time              
    @time = Time.now.to_a[2]
  end

  def set_now_statement
    temperature_now = self.temperature[0].to_i # in F
    humidity_now = self.humidity[0].to_i # in %
    if sleepy_time?
      self.now_statement = "night time. Dear Lord. Don't you sleep? "
    else
      if very_hot?
        if humid?
          self.now_statement = "hot and gross! Kind of like a wet gym sock left out in a hamper."
        else
          self.now_statement = "pretty darn hot! Sort of like a pizza oven."
        end
      elsif reasonably_hot?
        if humid?
          self.now_statement = "hot and gross! Consider a move to Antarctica."
        else
          self.now_statement = "pretty darn hot!"
        end
      elsif warm?
        if humid?
          self.now_statement = "supposedly comfortable temperature-wise, but it is very humid!"
        else
          self.now_statement = "not too hot, not too humid! Every once in a while, you can stop bitching about the weather."
        end
      elsif comfortable?
        self.now_statement = "not exactly warm. Layer up."
      else 
        self.now_statement = "COLD. I hope you are a penguin."
      end 
    end 
  end 

  def humid?
    humidity_now = self.humidity[0].to_i
    humidity_now >= 65
  end

  def very_hot?
    temperature_now = self.temperature[0].to_i
    temperature_now >= 90
  end

  def reasonably_hot?
    temperature_now = self.temperature[0].to_i
    temperature_now >= 80 && temperature_now <= 89
  end
 
  def warm? 
    temperature_now = self.temperature[0].to_i
    temperature_now >= 60 && temperature_now <= 79
  end

  def comfortable?
    temperature_now = self.temperature[0].to_i
    temperature_now >= 42 && temperature_now <= 59
  end

  def sleepy_time?
    set_time
    @time.between?(23,24) || @time.between?(0,5) 
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
    find_discrepancy_index 
    weekday_name_array = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["FCTTIME"]["weekday_name_night_unlang"]}
    self.max_discrepancy_time_of_day = weekday_name_array[self.max_discrepancy_index]
  end

  def discrepancy?
    self.discrepancy_max
    self.find_max_discrepancy_time_of_day
    if self.discrepancy.max >= 7
        self.discrepancy_statement = "Wunderground.com said it will be nice out, but it will feel MUCH hotter than what they said on #{self.max_discrepancy_time_of_day}."
    elsif self.discrepancy.max.between?(4,6)
      self.discrepancy_statement = "Watch out! It will feel much hotter than forecasted on #{self.max_discrepancy_time_of_day}."
    else
      self.discrepancy_statement = "It will feel pretty close to what meteorologists are saying in the next 36 hours."
    end
  end

  def t_shirt_weather?
    # Sunny above 65 F 
    # Cloudy above 68 F 
    # Rainy above 73 F
    temperature_now = self.temperature[0].to_i # in F
    humidity_now = self.humidity[0].to_i # in %
    status_now = self.status[0]
    if daytime? # will only show up if it is daytime
      if temperature_now >= 65 
        if ( status_now == "Clear" || status_now == "Mostly Sunny" || status_now == "Sunny" || status_now == "Mostly Clear")
          self.t_shirt_statement = "It is T-shirt weather for most people."
        elsif temperature_now >= 68 && (status_now == "Partly Cloudy" || status_now == "Mostly Cloudy" || status_now == "Cloudy")
            self.t_shirt_statement = "Probably T-shirt weather: a bit overcast."
        else temperature_now >= 73 && (status_now == "Scattered Thunderstorms" || status_now == "Isolated Thunderstorms")
          self.t_shirt_statement = "T-shirt weather, but bring a rain jacket."
        end
      elsif temperature_now >= 42
        self.t_shirt_statement = "Not exactly T-shirt weather."
      else 
        self.t_shirt_statement = "LAYERS! Lots of them."
      end
    end
  end

  def daytime?
    set_time
    @time.between?(6,19)
  end

  def collect_uv_index # returns an array of 36 elements
    self.uv_index = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["uvi"]}
  end

  # https://en.wikipedia.org/wiki/Ultraviolet_index
  def need_suncreen? # no message if index is 0,1,2 or if it's night time; uv index is always between 0 and 12
    uv_now = self.uv_index[0].to_i
    if daytime? 
      case uv_now
      when 3..5
        self.uv_statement = "UV index is moderate, but we recommend sunscreen."
      when 6..7
        self.uv_statement = "UV index is pretty high. Grab your trusty SPF 30+."
      when 8..10
        self.uv_statement = "UV index is really high. Cover up."
      when 11..12 # uv index is always between 0 and 12
        self.uv_statement = "UV index is dangerously high right now. Cover up. Stay indoors."
      end
    end
  end

end # ends class
