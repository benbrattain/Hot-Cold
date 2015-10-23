class ForecastsController < ApplicationController

  def new
    @forecast = Forecast.new
  end

  def create
    @forecast = Forecast.new(zipcode: params["forecast"]["zipcode"])
    if @forecast.valid_zip?
      @forecast.save
      redirect_to forecast_path(@forecast)
    else 
      flash[:notice] = "Please enter a valid zip code."
      redirect_to new_forecast_path
    end
  end

  def show
    @forecast = Forecast.find(params[:id])
    @forecast.process_forecast
  end

end



