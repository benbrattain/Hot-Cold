# Hot-or-Cold

## Description

http://theweatherproject.herokuapp.com/

What's the temperature like outside and what does it actually feel like? Do you need sunscreen (well, you always benefit from sunscreen) and can you get away with wearing a T-shirt? Do you need your umbrella? 

Most importantly, what will it really feel like outside in the next 36 hours? Handy for planning your day and outdoors exercise.

We tell you using our scientifically calculated heat index and wind chill factors, depending on the season. 

## Background

Flatiron School Project Mode Week 1. The goal was to create a functioning app from ideation to execution and presenting to others within 5 days.

This app is meant to solve an existing problem -- we often find that weather forecasts are not really hepful at telling us what it actually feels outside now and, more importantly, what will it feel outside in the next day or so.

## Features

Wunderground.com API | JSON format
Chart.js for charting
Bootstrap for front-end
Deployed to Heroku
ZipCodes gem for conversion of zipcodes to city and state

This app creates a Forecast object using a valid zip code. It converts a zip code into verbal city and state that are slugified to generate a url for Wunderground.com API. A JSON object with API data is then used to generate an array of actual 36 hours forecast as well as the 'real-feel' temperature (heat index or windchill depending on the current date).

## Usage

Enter your U.S. zip code (the app will check if it's valid), and we will tell you all you need to know to right now and for the next 36 hours. 

## Development/Contribution

We welcome all ideas on refactoring code | contributing weather scenarios | T-shirt weather feedback.

## Future

What features are you currently working on? Only mention things that you
actually are implementing. No pie-in-the-sky-never-gonna-happen stuff.

## Author

Anna Ershova, Benjamin Brattain, Travis Emmett

## License

We are is MIT Licensed. See LICENSE for details.
