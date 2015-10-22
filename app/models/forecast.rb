require 'date'

class Forecast < ActiveRecord::Base

  attr_accessor :api_response, :zip_output, :weather_output, :url, :city_slug, :temperature,  :hours,  :humidity,  :heat_index,  :wind_speed,  :wind_chill, :conditions_icon, :discrepancy, :discrepancy_index, :max_discrepancy, :discrepancy_statement, :discrepancy_index_array, :first_discrepancy, :status, :t_shirt_statement, :uv_index, :uv_statement, :all_hours, :max_time, :max_day, :seasonal_index


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

  def city_to_slug # for use in json url
    self.city_slug = self.city.downcase.gsub(" ", "_")
  end

  def to_url # generates url for the json object with all forecast data
    api_token = ENV["weather_api"]
    self.url = "http://api.wunderground.com/api/#{api_token}/hourly/q/#{self.state}/#{self.city_slug}.json"
  end

  def scrape_json # creates a json using generated url

    json = open(url).read
    self.api_response = JSON.parse(json)
  end

  def filter_array_length(array)
    array.values_at(* array.each_index.select {|i| i.even?})
  end
  
  def collect_hours 
    unformatted_hours = hourly_forecast.collect {|hash| hash["FCTTIME"]["hour"]}
  
    self.hours = []
    unformatted_hours = filter_array_length(unformatted_hours)
    unformatted_hours.each do |hour|
      if hour.to_i == 0 
        hour = "midnight"
      elsif hour.to_i.between?(13,23)
        hour = "#{hour.to_i - 12}pm"
      elsif hour.to_i == 12
        hour = "noon"
      else
        hour = "#{hour.to_i}am"
      end
      self.hours << hour
    end
  end

  def hourly_forecast
    api_response["hourly_forecast"]
  end

  def collect_humidity 
    self.humidity = hourly_forecast.collect {|hash| hash["humidity"].to_i}
    self.humidity = filter_array_length(self.humidity) 
  end

  def collect_temperature 
    self.temperature = hourly_forecast.collect {|hash| hash["temp"]["english"].to_i}
    self.temperature = filter_array_length(self.temperature)
  end

  def collect_wind_speed 
    self.wind_speed = hourly_forecast.collect {|hash| hash["wspd"]["english"].to_i}
    self.wind_speed = filter_array_length(self.wind_speed)
  end

  def collect_status 
    self.status = hourly_forecast.collect {|hash| hash["wx"]}
    self.status = filter_array_length(self.status)
  end

  def collect_data
    self.scrape_json
    self.collect_hours
    self.collect_temperature
    self.collect_humidity
    self.collect_heat_index
    self.collect_wind_speed
    self.collect_wind_chill
    self.collect_seasonal_index
    self.collect_status
    self.collect_uv_index
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

  def collect_seasonal_index
    self.seasonal_index = []
    temperature.each_with_index do |temp, index|
      if temp >= 70
        self.seasonal_index << heat_index[index]
      elsif temp >50
        self.seasonal_index << temperature[index]  
      else self.seasonal_index << wind_chill[index]
      end
    end
  end

  def set_time              
    @time = Time.now.to_a[2]
  end

  def now_statement
    humidity_now = humidity[0].to_i # in %
    if sleepy_time?
      "Dear Lord. Don't you sleep? "
    else
      if very_hot?
        if humid?
          "Hot 'n Gross! Like a wet gym sock in a hamper."\
        elsif comfortably_humid?
          "Super hot! But you get a pass on the humidity today."
        else 
          "Pretty dern hot, but at least it's dry!"
        end
      elsif reasonably_hot?
        if humid?
          "Hot and gross! Move to Antarctica, quick."
        elsif comfortably_humid?
          "Eek pretty hot! But at least it's not too humid."
        else
          "Pretty darn hot, with dry heat!"
        end
      elsif warm?
        if humid?
          "It is comfortable out, but very humid!"
        elsif comfortably_humid?
          "Goldilocks approved weather today."
        else
          "Not too hot, maybe a bit dry! Every once in a while, just stop bitching about the weather."
        end
      elsif comfortable?
        "Not exactly warm. Layer up."
      else 
        "COLD, like penguin cold."
      end 
    end 
  end 

  def cold
  
  end
  
  def very_cold_statements
    ["Can't. Move. Face.", "Don't forget to eat your water today!", "Frosty the Snowman was an ameteur.", "In four to six months the weather will be great, promise." ]
  end

  def humid?
    humidity_now >= 60
  end

  def comfortably_humid?  
    humidity_now.between?(43,59)
  end


  def dry_air?
    humidity_now <= 42
  end

  def very_hot?
    temperature_now >= 90
  end

  def reasonably_hot?
    temperature_now >= 80 && temperature_now <= 89
  end
 
  def warm? 
    temperature_now >= 60 && temperature_now <= 79
  end

  def comfortable?
    temperature_now >= 42 && temperature_now <= 59
  end

  def sleepy_time?
    set_time
    @time.between?(23,24) || @time.between?(0,5) 
  end

  def set_conditions_icon # shows an icon for current conditions, such as sunny, overcast, thunderstorms, etc
    self.conditions_icon = hourly_forecast.collect {|hash| hash["icon_url"]}.first
  end

  # discrepancy methods
  def calculate_discrepancy
    self.discrepancy = []
    i = 0
    while i < self.heat_index.length
      num = self.heat_index[i].to_i - self.temperature[i].to_i
      self.discrepancy << num
      i += 1
    end
    self.discrepancy # returns correct array
  end

  def find_discrepancy_max
    self.calculate_discrepancy
    self.max_discrepancy = self.discrepancy.max # returns correct max discrepancy from the array
  end

  def find_discrepancy_index
    self.find_discrepancy_max
    self.discrepancy_index_array = self.discrepancy.each_index.select{|x| self.discrepancy[x] == self.discrepancy.max} # returns array of correct indices
    self.first_discrepancy = self.discrepancy_index_array.first 
    self.all_hours = hourly_forecast.collect {|hash| hash["FCTTIME"]["pretty"]}
    self.discrepancy_index = self.all_hours[self.first_discrepancy] 
    self.max_time = self.discrepancy_index.split(" ")[0]+self.all_hours[self.first_discrepancy].split(" ")[1] # 11am
    if Time.now.to_a[3] == self.discrepancy_index.split(" ")[5].split(",").join("").to_i
      self.max_day = "today"
    else 
      self.max_day = "tomorrow"
    end
  end

  def discrepancy?
    self.find_discrepancy_max
    self.find_discrepancy_index
    if self.find_discrepancy_max >= 7
      self.discrepancy_statement = 
      "It will feel MUCH hotter than what meteorologists said starting around #{self.max_time} #{self.max_day}."
    elsif self.find_discrepancy_max.between?(4,6)
      self.discrepancy_statement = 
      "Watch out! It will feel much hotter than forecasted starting around #{self.max_time} #{self.max_day}."
    else
      self.discrepancy_statement = 
      "In the next 36 hours, it will feel pretty close to what meteorologists are saying."
    end
  end

  def temperature_now
    heat_index[0].to_i
  end

  def humidity_now
    humidity[0].to_i
  end

  def t_shirt_weather? # Sunny above 65 F; Cloudy above 68 F; Rainy above 73 F
     # in F
     # in %
    if daytime? # will only show up if it is daytime
      if temperature_now >= 65 
        if clear_or_sunny?
          self.t_shirt_statement = "It is t-shirt weather for most people."
        elsif temperature_now >= 68 && cloudy?
            self.t_shirt_statement = "T-shirt weather, but a bit overcast."
        else temperature_now >= 73 && thunder?
          self.t_shirt_statement = "T-shirt weather, but don't forget your umbrella."
        end
      elsif temperature_now >= 42
        self.t_shirt_statement = "Not exactly T-shirt weather."
      else 
        self.t_shirt_statement = "LAYERS! Lots of them."
      end
    end
  end

  def status_now
    status[0]
  end

  def thunder? # "Scattered Thunderstorms", "Isolated Thunderstorms", "Thunderstorms", "Heavy Thunderstorms"
    status_now.include?("Thunder") 
  end

  def clear_or_sunny?
    status_now == "Clear" || status_now == "Mostly Sunny" || status_now == "Sunny" || status_now == "Mostly Clear"
  end

  def cloudy?
    status_now == "Partly Cloudy" || status_now == "Mostly Cloudy" || status_now == "Cloudy"
  end

  def daytime?
    set_time
    @time.between?(6,19)
  end

  def collect_uv_index # returns an array of 36 elements
    self.uv_index = hourly_forecast.collect {|hash| hash["uvi"]}
    self.uv_index = filter_array_length(self.uv_index)
  end

  # https://en.wikipedia.org/wiki/Ultraviolet_index
  def need_suncreen? # no message if index is 0,1,2 or if it's night time; uv index is always between 0 and 12
    uv_now = self.uv_index[0].to_i
    if daytime? 
      case uv_now
      when 3..5
        self.uv_statement = "UV index is moderate (#{uv_now}), but we recommend sunscreen."
      when 6..7
        self.uv_statement = "UV index is pretty high (#{uv_now}). Grab your trusty SPF 30+."
      when 8..10
        self.uv_statement = "UV index is really high (#{uv_now}). Cover up."
      when 11..12 # uv index is always between 0 and 12
        self.uv_statement = "UV index is dangerously high right now (#{uv_now}). Cover up. Stay indoors."
      end
    end
  end

  def data_temps
    {
        labels: hours, 
        datasets: [
            {
                label: "Forecasted Temperature, F",
                fillColor: "rgba(220,220,220,0.2)",
                strokeColor: "rgba(0,0,0,1)",
                pointColor: "rgba(0,0,0,1)",
                pointStrokeColor: "#fff",
                pointHighlightFill: "#fff",
                pointHighlightStroke: "rgba(0,0,0,1)",
                data: temperature
            },
            {
                label: "Actual Temperature, F",
                fillColor: "rgba(151,187,205,0.2)",
                strokeColor: "rgba(178,34,34,1)",
                pointColor: "rgba(178,34,34,1)",
                pointStrokeColor: "#fff",
                pointHighlightFill: "#fff",
                pointHighlightStroke: "rgba(151,187,205,1)",
                data: seasonal_index
            }
        ]
    }
  end

  def options_temps
    {animationEasing: "easeOutElastic",
      # generateLegend: true,
      scaleFontColor: "black",
      scaleFontSize: 14,
      responsive: true,
      datasetFill: false,
      width: 475,
      height: 475,
      scaleLineColor: "rgba(0,0,0,1)",
      scaleGridLineColor: "rgba(250,128,114,0.1)"
      }
  end


end
