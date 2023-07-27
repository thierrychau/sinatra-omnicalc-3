require "sinatra"
require "sinatra/reloader"
require "sinatra/cookies"

get("/") do
  "
  <h1>Welcome to your Sinatra App!</h1>
  <p>Define some routes in app.rb</p>
  "
  erb(:landing)
end

get("/umbrella") do
 
  erb(:umbrella)
end

post("/process_umbrella") do
  gmaps_key = ENV.fetch("GMAPS_KEY")
  pirate_weather_key = ENV.fetch("PIRATE_WEATHER_KEY")
  openai_key = ENV.fetch("OPENAI_KEY")

  @user_location = params.fetch("user_location")

  maps_url = "https://maps.googleapis.com/maps/api/geocode/json?address=#{location.gsub(" ", "%20")}&key=#{gmaps_key}"
  raw_maps_response = HTTP.get(maps_url)
  parsed_maps_response = JSON.parse(raw_maps_response)
  loc_result = parsed_maps_response.fetch("results")

  @current_loc_lat = loc_result[0].fetch("geometry").fetch("location").fetch("lat")
  @current_loc_lng = loc_result[0].fetch("geometry").fetch("location").fetch("lng")

  pirate_weather_url = "https://api.pirateweather.net/forecast/#{pirate_weather_key}/#{user_lat},#{user_lng}"
  raw_pirate_weather_response = HTTP.get(pirate_weather_url)
  parsed_pirate_weather_response = JSON.parse(raw_pirate_weather_response)

  currently_hash = parsed_pirate_weather_response.fetch("currently")
  currently_temp_F = currently_hash.fetch("temperature")
  # currently_temp_C = (currently_temp_F - 32) * 5/9
  hourly_hash = parsed_pirate_weather_response.fetch("hourly")
  hourly_summary = hourly_hash.fetch("summary")

  @current_loc_temp = currently_temp_F
  @current_loc_sum = hourly_summary

  precip_threshold = 0.10
  any_precipitation = false
  next_twelve_hours = hourly_hash.fetch("data")[1..12]
  next_twelve_hours_precip_probability_array = []

  next_twelve_hours.each do |next_twelve_hours_hash|

    hour_precip_probability = next_twelve_hours_hash.fetch("precipProbability")

    next_twelve_hours_precip_probability_array.push([hour, (hour_precip_probability*100).round.to_i])

    if hour_precip_probability >= precip_threshold

      any_precipitation = true
    end
  end

  if any_precipitation
    @current_loc_umbrella = "You might want to take an umbrella!"
  else
    @current_loc_umbrella = "You probably won’t need an umbrella today."
  end

  erb(:process_umbrella)
end
