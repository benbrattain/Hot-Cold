class CreateForecasts < ActiveRecord::Migration
  def change
    create_table :forecasts do |t|
      t.string :zipcode
      t.string :city
      t.string :state
      t.timestamps null: false
    end
  end
end
