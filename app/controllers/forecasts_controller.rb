class ForecastsController < ApplicationController

  def new
    @forecast = Forecast.new
  end

  def create
    @forecast = Forecast.new(zipcode: params["forecast"]["zipcode"])
    @forecast.store_zip_output
    if @forecast.valid_zip?
      @forecast.store_location
      @forecast.collect_data
      @forecast.save
      render 'show'
    else 
      flash[:notice] = "Please enter a valid zip code."
      redirect_to new_forecast_path
    end
  end

end



