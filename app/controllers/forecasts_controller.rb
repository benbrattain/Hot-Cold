class ForecastsController < ApplicationController

  def index
  @forecast = Forecast.new
  end

  def create
    @forecast = Forecast.create(zipcode: params["forecast"]["zipcode"])
    @forecast.zip_output = ZipCodes.identify("#{@forecast.zipcode}")
    @forecast.store_location
    api_response = open(@forecast.url).read
    @forecast.hours = JSON.parse(api_response)["hourly_forecast"].collect {|hash| hash["FCTTIME"]["hour"]}
    @forecast.humidity = JSON.parse(api_response)["hourly_forecast"].collect {|hash| hash["humidity"]}
    @forecast.temperature = JSON.parse(api_response)["hourly_forecast"].collect {|hash| hash["temp"]["english"]}
    @forecast.save
    render "forecasts/create.html.erb"
  end
end
