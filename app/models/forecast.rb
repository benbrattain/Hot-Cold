require 'date'

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
                :discrepancy_index,
                :max_discrepancy,
                :discrepancy_statement,
                :first_discrepancy,
                :status,
                :t_shirt_statement,
                :uv_index,
                :uv_statement,
                :all_hours,
                :max_time,
                :max_day,
                :seasonal_index,
                :today,
                :day_in_36_hours,
                :forecast_data,
                :unformatted_hours

  def process_forecast
    store_zip_output
    store_location
    collect_data
  end

  def store_location
    self.store_city
    self.store_state
    self.city_to_slug
    self.to_url
  end

  def zip_output
    ZipCodes.identify("#{self.zipcode}")
  end

  def store_zip_output
    self.zip_output = zip_output
  end

  def valid_zip? 
     zip_output != nil
  end

  def store_city 
    self.city = zip_output[:city]
  end

  def store_state 
    self.state = zip_output[:state_code]
  end

  def city_to_slug 
    self.city_slug = city.downcase.gsub(" ", "_")
  end

  def to_url 
    api_token = ENV["weather_api"]
    self.url = "http://api.wunderground.com/api/#{api_token}/hourly/q/#{state}/#{city_slug}.json"
  end

  def scrape_json 
    api_response = open(url).read
    self.forecast_data = JSON.parse(api_response)
  end

  def filter_array_length(array)
    array.values_at(* array.each_index.select {|i| i.even?})
  end
  
  def collect_unformatted_hours
    self.unformatted_hours = filter_array_length (forecast_data["hourly_forecast"].collect {|hash| hash["FCTTIME"]["hour"].to_i })
  end

  def collect_hours 
    self.hours = []
    collect_unformatted_hours
    unformatted_hours.each do |hour|
      case hour
      when 0 then hour = "midnight"
      when 12 then hour = "noon"
      when 13..23 then hour = "#{hour.to_i - 12}pm" 
      else hour = "#{hour.to_i}am"
      end
      self.hours << hour
    end
  end

  def day_today
    @time.between?(15,24) ? self.today = "tonight" : self.today = "today"
  end

  def day_in_36_hours
    @time.between?(1,12) ? self.day_in_36_hours = "tomorrow" : self.day_in_36_hours = "the day after tomorrow"
  end

  def collect_humidity 
    self.humidity = forecast_data["hourly_forecast"].collect {|hash| hash["humidity"]}
    self.humidity = filter_array_length(self.humidity)
  end

  def collect_temperature 
    self.temperature = forecast_data["hourly_forecast"].collect {|hash| hash["temp"]["english"].to_i}
    self.temperature = filter_array_length(self.temperature)
  end

  def collect_wind_speed 
    self.wind_speed = forecast_data["hourly_forecast"].collect {|hash| hash["wspd"]["english"].to_i}
    self.wind_speed = filter_array_length(self.wind_speed)
  end

  def collect_status 
    self.status = forecast_data["hourly_forecast"].collect {|hash| hash["wx"]}
    self.status = filter_array_length(self.status)
  end

  def collect_data
    scrape_json
    store_zip_output
    collect_hours
    collect_temperature
    collect_humidity
    collect_heat_index
    collect_wind_speed
    collect_wind_chill
    collect_seasonal_index
    collect_status
    collect_uv_index
    set_now_statement
    set_conditions_icon
    discrepancy?
    t_shirt_weather?
    need_suncreen?
    day_today
    day_in_36_hours
    collect_unformatted_hours
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
      elsif temp > 50
        self.seasonal_index << temperature[index]  
      else self.seasonal_index << wind_chill[index]
      end
    end
  end

  def set_time              
    @time = Time.now.to_a[2]
  end

  def set_now_statement
   temperature_now = temperature[0].to_i 
   humidity_now = humidity[0].to_i 
   if sleepy_time?
      sleepy_time_array = ["Night time. Dear Lord. Don't you sleep?", "Why are you not in bed?!", "Up late, are we?"]
      self.now_statement = sleepy_time_array.sample
   else
     if very_hot? && humid?
          if clear_or_sunny?
            hot_and_humid_array = ["Mother Nature forgot her meds today.", "Hot and gross! Like a wet gym sock left out in a hamper.", "Like hot molasses.", "I am done reporting the weather. This sucks.", "No greenhouse necessary.", "You are my Sunshine."]
            self.now_statement = hot_and_humid_array.sample
          else
            hot_and_humid_array = ["Mother Nature off her meds today.", "Hot and gross! Like a wet gym sock left out in a hamper.", "Like hot molasses.", "I am done reporting the weather. This sucks.", "No greenhouse necessary."]
            self.now_statement = hot_and_humid_array.sample
          end
     elsif very_hot? && comfortably_humid?
        if clear_or_sunny?
          hot_and_ok_array = ["Make sure to hydrate.", "Extremely hot! But at least not too humid.", "I don't know everything, but I do know it's nice out.", "You are the sunshine of my life."]
          self.now_statement = hot_and_ok_array.sample
        else
          hot_and_ok_array = ["Make sure to hydrate.", "Extremely hot! But no sticking to the bus seat today.", "I don't know everything, but I do know it's nice out."]
          self.now_statement = hot_and_ok_array.sample
        end
     elsif very_hot?
         hot_and_dry_array = ["Where are you, Death Valley?!", "HOT.DRY. Are you on Venus?", "Insert amazing weather forecast here. Sorry, it sucks out.", "Weather is misbehaving.", "Only leave the indoors for emergency beer runs."]
         self.now_statement = hot_and_dry_array.sample
     elsif reasonably_hot? && humid?
         hot_and_humid_array = ["Hot and gross! Consider a move to Antarctica.", "I hear Lake Titicaca is very pleasant this time of year.", "New goal: become a penguin and move somewhere cold.", "Buy a dehumidifier and turn your AC on. Don't move until the weather changes."]
         self.now_statement = hot_and_humid_array.sample
     elsif reasonably_hot? && comfortably_humid?
         hot_and_comfortable_array = ["Eek pretty hot! But at least it's not too humid.", "Hot. Not Muggy. Go play outdoors.", "HOT. Be happy it is not humid.", "Pool party time!!!"] 
         self.now_statement = hot_and_comfortable_array.sample
     elsif reasonably_hot?
        if clear_or_sunny?
          reasonably_hot_array = ["Pretty darn hot, with dry heat!", "I feel like an old sweatshirt, fresh out of a dryer.", "Like being inside a bread oven, minus yummy bread.", "Hot'n'Dry.", "You are the sunshine of my life."]  
          self.now_statement = reasonably_hot_array.sample    
        else
          reasonably_hot_array = ["Pretty darn hot, with dry heat!", "I feel like an old sweatshirt, fresh out of a dryer.", "Like being inside a bread oven, minus yummy bread.", "Hot'n'Dry."]  
          self.now_statement = reasonably_hot_array.sample
        end
     elsif warm? && humid?
         warm_and_humid_array = ["Decent weather out, but so humid you could grow moss.", "It would be SO much nicer if it were not as humid.", "Thick'n'humid."]
         self.now_statement = warm_and_humid_array.sample
     elsif warm? && comfortably_humid?
          if clear_or_sunny?
            pleasant_array = ["Pleasant as shit out.", "Weather working for YOU today.", "Goldilocks approved weather today", "Bottle this weather and save it for a rainy day.", "Wow, the weather is totally nice!", "You are my sunshine, my only sunshine."]
            self.now_statement = pleasant_array.sample
          else
            pleasant_array = ["Pleasant as shit out.", "Weather working for YOU today.", "Goldilocks approved weather today", "Bottle this weather and save it for a rainy day.", "Wow, the weather is totally nice!"]
            self.now_statement = pleasant_array.sample
          end
     elsif warm?
         warm_and_dry_array = ["Every once in a while, you can stop bitching about the weather. Today is that day. You are that person.", "My job is easy today. Now go enjoy yo'selves!", "Mmmm, good weather."]
         self.now_statement = warm_and_dry_array.sample
     elsif comfortable?
       comfortable_array = ["Not exactly warm. Layer up.", "Don't you wish you were somewhere warm right now?", "I hear mulled wine is nice for this weather.", "Hot tea. Lots of it. Maybe with some whisky."]
       self.now_statement = comfortable_array.sample
     else 
       cold_array = ["COLD. Like penguin cold.", "Break out your trusty Uggs ladies/Bufaloe pelts gents.", "'Tis the season to winterize yourself.", "Bout time to look into that Bahamas vacation."]
       self.now_statement = cold_array.sample
     end 
   end 
 end

  def temperature_now
    seasonal_index[0].to_i
  end

  def humidity_now
    humidity[0].to_i
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

  def current_temp_dif?
    temperature[0] != seasonal_index[0]
  end

  def set_conditions_icon 
    self.conditions_icon = forecast_data["hourly_forecast"][0]["icon_url"]
  end

  def calculate_discrepancy
    self.discrepancy = []
    i = 0
    while i < self.heat_index.length
      num = self.heat_index[i].to_i - self.temperature[i].to_i
      self.discrepancy << num
      i += 1
    end
    self.discrepancy 
  end

  def find_discrepancy_max
    calculate_discrepancy
    if discrepancy.any?{|x| x <= -3 }
      self.max_discrepancy = discrepancy.min
    else
      self.max_discrepancy = discrepancy.max
    end
  end

  def find_discrepancy_index
    find_discrepancy_max
    discrepancy_index_array = discrepancy.each_index.select{|x| self.discrepancy[x] == self.discrepancy.max} # returns array of correct indices
    self.first_discrepancy = discrepancy_index_array.first 
    self.all_hours = forecast_data["hourly_forecast"].collect {|hash| hash["FCTTIME"]["pretty"]}
    self.discrepancy_index = self.all_hours[self.first_discrepancy] 
    self.max_time = self.discrepancy_index.split(" ")[0]+self.all_hours[self.first_discrepancy].split(" ")[1] 
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
    elsif self.find_discrepancy_max < 0
      self.discrepancy_statement = 
      "It will feel cooler than it actually is today."
    else
      self.discrepancy_statement = 
      "In the next 36 hours, it will feel pretty close to what meteorologists are saying."
    end
  end

  def t_shirt_weather? # Sunny above 65 F; Cloudy above 68 F; Rainy above 73 F
     # in F
     # in %
    if daytime? # will only show up if it is daytime
      if temperature_now >= 65 
        if clear_or_sunny?
          self.t_shirt_statement = "It is T-shirt weather for most people."
        elsif temperature_now >= 68 && cloudy?
            self.t_shirt_statement = "T-shirt weather, but a bit overcast."
        elsif temperature_now >= 73 && thunder?
          self.t_shirt_statement = "T-shirt weather, but don't forget your umbrella."
        end
      elsif temperature_now >= 42
        self.t_shirt_statement = "Not really T-shirt weather, sorry."
      else 
        self.t_shirt_statement = "LAYERS! Lots of them."
      end
    end
  end

  def wind_statement
    if wind_speed[0] > 1
      "Winds are currently at #{wind_speed[0]} mph."
    else "Winds are calm"
    end
  end

  def thunder? # "Scattered Thunderstorms", "Isolated Thunderstorms", "Thunderstorms", "Heavy Thunderstorms", etc
    status_now = status[0]
    status_now.downcase.include?("thunder") 
  end

  def clear_or_sunny?
    status_now = status[0]
    status_now == "Clear" || status_now == "Mostly Sunny" || status_now == "Sunny" || status_now == "Mostly Clear"
  end

  def cloudy? # "Partly Cloudy" || status_now == "Mostly Cloudy" || status_now == "Cloudy"
    status_now = status[0]
    status_now.downcase.include?("cloud")
  end

  def daytime?
    set_time
    @time.between?(6,19)
  end

  def collect_uv_index # returns an array of 36 elements
    self.uv_index = forecast_data["hourly_forecast"].collect {|hash| hash["uvi"]}
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
    {
      animationEasing: "easeOutElastic",
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

end # ends class
