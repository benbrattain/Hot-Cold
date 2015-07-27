class ForecastsController < ApplicationController

  def index
    @forecast = Forecast.new
  end

  def create
      @forecast = Forecast.create(zipcode: params["forecast"]["zipcode"])
      @forecast.store_zip_output
      if @forecast.valid_zip?
        @forecast.store_location
        @forecast.collect_data
        @forecast.save
        render "forecasts/create.html.erb"
      else 
        flash[:notice] = "Please enter a valid zip code."
        redirect_to root_path
      end
  end

end



