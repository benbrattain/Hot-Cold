class Forecast < ActiveRecord::Base
attr_accessor :zip_output, :weather_output, :url, :city_slug, :temperature, :hours, :humidity



  def store_location
    self.store_city
    self.store_state
    self.city_to_slug
    self.to_url
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


end
