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
                :discrepancy_index_array,
                :first_discrepancy,
                :status,
                :t_shirt_statement,
                :uv_index,
                :uv_statement,
                :all_hours,
                :max_time,
                :max_day,
                :seasonal_index

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

  def filter_array_length(array)
    array.values_at(* array.each_index.select {|i| i.even?})
  end
  
  def collect_hours 
    unformatted_hours = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["FCTTIME"]["hour"]}
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

  def collect_humidity 
    self.humidity = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["humidity"]}
    self.humidity = filter_array_length(self.humidity)
  end

  def collect_temperature 
    self.temperature = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["temp"]["english"]}
    self.temperature = filter_array_length(self.temperature)
  end

  def collect_wind_speed 
    self.wind_speed = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["wspd"]["english"]}
    self.wind_speed = filter_array_length(self.wind_speed)
  end

  def collect_status 
    self.status = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["wx"]}
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
    self.collect_correct_weather_for_season
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

  def collect_correct_weather_for_season
    if DateTime.now<DateTime.new(2015,10,15)
      self.seasonal_index = collect_heat_index
    else
      self.seasonal_index = collect_wind_chill
    end
  end

  def set_time              
    @time = Time.now.to_a[2]
  end

  def set_now_statement
   temperature_now = self.temperature[0].to_i 
   humidity_now = self.humidity[0].to_i 
   if sleepy_time?
      sleepy_time_array = ["Night time. Dear Lord. Don't you sleep?", "Why are you not in bed?!", "Up late, are we?"]
      self.now_statement = sleepy_time_array[rand(0..sleepy_time_array.length-1)]
   else
     if very_hot? && humid?
          if clear_or_sunny?
            hot_and_humid_array = ["Mother Nature forgot her meds today.", "Hot and gross! Like a wet gym sock left out in a hamper.", "Like hot molasses.", "I am done reporting the weather. This sucks.", "No greenhouse necessary.", "You are my Sunshine."]
            self.now_statement = hot_and_humid_array[rand(0..hot_and_humid_array.length-1)]
          else
            hot_and_humid_array = ["Mother Nature forgot her meds today.", "Hot and gross! Like a wet gym sock left out in a hamper.", "Like hot molasses.", "I am done reporting the weather. This sucks.", "No greenhouse necessary."]
            self.now_statement = hot_and_humid_array[rand(0..hot_and_humid_array.length-1)]
          end
     elsif very_hot? && comfortably_humid?
        if clear_or_sunny?
          hot_and_ok_array = ["Make sure to hydrate.", "Extremely hot! But at least not too humid.", "I don't know everything, but I do know it's nice out.", "You are the sunshine of my life."]
          self.now_statement = hot_and_ok_array[rand(0..hot_and_ok_array.length-1)]
        else
          hot_and_ok_array = ["Make sure to hydrate.", "Extremely hot! But at least not too humid.", "I don't know everything, but I do know it's nice out."]
          self.now_statement = hot_and_ok_array[rand(0..hot_and_ok_array.length-1)]
        end
     elsif very_hot?
         hot_and_dry_array = ["Where are you, Death Valley?!", "HOT.DRY. Are you on Venus?", "Insert amazing weather forecast here. Sorry, it sucks out.", "Weather is misbehaving.", "Only leave the indoors for emergency beer runs."]
         self.now_statement = hot_and_dry_array[rand(0..hot_and_dry_array.length-1)]
     elsif reasonably_hot? && humid?
         hot_and_humid_array = ["Hot and gross! Consider a move to Antarctica.", "I hear Lake Titicaca is nice this time of year.", "New goal: become a penguin and move somewhere cold.", "Buy a dehumidifier and turn your AC on. Don't move until the weather changes."]
         self.now_statement = hot_and_humid_array[rand(0..hot_and_humid_array.length-1)]
     elsif reasonably_hot? && comfortably_humid?
         hot_and_comfortable_array = ["Eek pretty hot! But at least it's not too humid.", "Hot. Not Muggy. Go play outdoors.", "HOT. Be happy it is not humid.", "Pool party time!!!"] 
         self.now_statement = hot_and_comfortable_array[rand(0..hot_and_comfortable_array.length-1)]
     elsif reasonably_hot?
        if clear_or_sunny?
          reasonably_hot_array = ["Pretty darn hot, with dry heat!", "I feel like an old sweatshirt, fresh out of a dryer.", "Like being inside a bread oven, minus yummy bread.", "Hot'n'Dry.", "You are the sunshine of my life."]  
          self.now_statement = reasonably_hot_array[rand(0..reasonably_hot_array.length-1)]    
        else
          reasonably_hot_array = ["Pretty darn hot, with dry heat!", "I feel like an old sweatshirt, fresh out of a dryer.", "Like being inside a bread oven, minus yummy bread.", "Hot'n'Dry."]  
          self.now_statement = reasonably_hot_array[rand(0..reasonably_hot_array.length-1)]
        end
     elsif warm? && humid?
         warm_and_humid_array = ["Decent weather out, but so humid you could grow moss.", "It would be SO much nicer if it were not as humid.", "Thick'n'humid."]
         self.now_statement = warm_and_humid_array[rand(0..warm_and_humid_array.length-1)]
     elsif warm? && comfortably_humid?
          if clear_or_sunny?
            pleasant_array = ["Pleasant as shit out.", "Silky and smooth out", "Goldilocks approves of the weather totay", "Next app idea: how to make an app to re-live this weather at will.", "Good day for Groundhog Day part II.", "Wow, the weather is nice for once!", "You are my sunshine, my only sunshine."]
            self.now_statement = pleasant_array[rand(0..pleasant_array.length-1)]
          else
            pleasant_array = ["Pleasant as shit out.", "Silky and smooth out", "Goldilocks approves of the weather totay", "Next app idea: how to make an app to re-live this weather at will.", "Good day for Groundhog Day part II.", "Wow, the weather is nice for once!"]
            self.now_statement = pleasant_array[rand(0..pleasant_array.length-1)]
          end
     elsif warm?
         warm_and_dry_array = ["Every once in a while, just stop bitching about the weather.", "We all know it's hot and dry. Stop complaining.", "Good time for a cold beer."]
         self.now_statement = warm_and_dry_array[rand(0..warm_and_dry_array.length-1)]
     elsif comfortable?
       comfortable_array = ["Not exactly warm. Layer up.", "Don't you wish you were somewhere warm right now?", "I hear mulled wine is nice for this weather.", "Hot tea. Lots of it. Maybe with some whisky."]
       self.now_statement = comfortable_array[rand(0..comfortable_array.length-1)]
     else 
       cold_array = ["COLD. I hope you are a penguin.", "Bring out your trusty Uggs", "'Tis the season to winterize yourself.", "Time to look into a Bahamas vacation?"]
       self.now_statement = cold_array[rand(0..cold_array.length-1)]
     end 
   end 
 end

  def humid?
    humidity_now = self.humidity[0].to_i
    humidity_now >= 60
  end

  def comfortably_humid?
    humidity_now = self.humidity[0].to_i
    humidity_now.between?(43,59)
  end


  def dry_air?
    humidity_now = self.humidity[0].to_i
    humidity_now <= 42
  end

  def very_hot?
    temperature_now = self.heat_index[0].to_i
    temperature_now >= 90
  end

  def reasonably_hot?
    temperature_now = self.heat_index[0].to_i
    temperature_now >= 80 && temperature_now <= 89
  end
 
  def warm? 
    temperature_now = self.heat_index[0].to_i
    temperature_now >= 60 && temperature_now <= 79
  end

  def comfortable?
    temperature_now = self.heat_index[0].to_i
    temperature_now >= 42 && temperature_now <= 59
  end

  def sleepy_time?
    set_time
    @time.between?(23,24) || @time.between?(0,5) 
  end

  def set_conditions_icon 
    self.conditions_icon = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["icon_url"]}.first
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
    self.calculate_discrepancy
    # binding.pry
    if self.discrepancy.any?{|x| x <= -3 }
      self.max_discrepancy = self.discrepancy.min
    else
      self.max_discrepancy = self.discrepancy.max
    end
  end

  def find_discrepancy_index
    self.find_discrepancy_max
    self.discrepancy_index_array = self.discrepancy.each_index.select{|x| self.discrepancy[x] == self.discrepancy.max} # returns array of correct indices
    self.first_discrepancy = self.discrepancy_index_array.first 
    self.all_hours = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["FCTTIME"]["pretty"]}
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
      "Lucky you. It will feel cooler than it actually is."
    else
      self.discrepancy_statement = 
      "In the next 36 hours, it will feel pretty close to what meteorologists are saying."
    end
  end

  def t_shirt_weather? # Sunny above 65 F; Cloudy above 68 F; Rainy above 73 F
    temperature_now = self.heat_index[0].to_i # in F
    humidity_now = self.humidity[0].to_i # in %
    status_now = self.status[0]
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
        self.t_shirt_statement = "Not exactly T-shirt weather, huh?"
      else 
        self.t_shirt_statement = "LAYERS! Lots of them."
      end
    end
  end

  def thunder? # "Scattered Thunderstorms", "Isolated Thunderstorms", "Thunderstorms", "Heavy Thunderstorms"
    status_now = self.status[0]
    status_now.include?("Thunder") 
  end

  def clear_or_sunny?
    status_now = self.status[0]
    status_now == "Clear" || status_now == "Mostly Sunny" || status_now == "Sunny" || status_now == "Mostly Clear"
  end

  def cloudy?
    status_now = self.status[0]
    status_now == "Partly Cloudy" || status_now == "Mostly Cloudy" || status_now == "Cloudy"
  end

  def daytime?
    set_time
    @time.between?(6,19)
  end

  def collect_uv_index # returns an array of 36 elements
    self.uv_index = JSON.parse(@api_response)["hourly_forecast"].collect {|hash| hash["uvi"]}
    self.uv_index = filter_array_length(self.uv_index)
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
