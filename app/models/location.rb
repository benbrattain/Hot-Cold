class Location < ActiveRecord::Base

  attr_accessor :zipcode, 
                :latitude, 
                :longitude

  reverse_geocoded_by :latitude, :longitude do |obj,results|
    if geo = results.first
      # obj.city    = geo.city
      obj.zipcode = geo.postal_code
      # obj.country = geo.country_code
    end
  end

  after_validation :reverse_geocode  # auto-fetch coordinates

end