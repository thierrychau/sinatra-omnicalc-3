require "sinatra"
require "sinatra/reloader"
require "sinatra/cookies"
require "http"
require "sinatra/cookies"

gmaps_key = ENV.fetch("GMAPS_KEY")
pirate_weather_key = ENV.fetch("PIRATE_WEATHER_KEY")
openai_key = ENV.fetch("OPENAI_KEY")

get("/") do

  erb(:landing)
end

get("/umbrella") do
 
  erb(:umbrella_form)
end

post("/process_umbrella") do
  @user_location = params.fetch("user_location")

  maps_url = "https://maps.googleapis.com/maps/api/geocode/json?address=#{@user_location.gsub(" ", "+")}&key=#{gmaps_key}"
  raw_maps_response = HTTP.get(maps_url)
  parsed_maps_response = JSON.parse(raw_maps_response)

  @current_loc_lat = parsed_maps_response.dig("results",0,"geometry","location", "lat")
  @current_loc_lng = parsed_maps_response.dig("results",0,"geometry","location", "lng")

  pirate_weather_url = "https://api.pirateweather.net/forecast/#{pirate_weather_key}/#{@current_loc_lat},#{@current_loc_lng}"
  raw_pirate_weather_response = HTTP.get(pirate_weather_url)
  parsed_pirate_weather_response = JSON.parse(raw_pirate_weather_response)

  currently_hash = parsed_pirate_weather_response.fetch("currently")
  currently_temp_F = currently_hash.fetch("temperature")
  currently_summary = currently_hash.fetch("summary")
  # currently_temp_C = (currently_temp_F - 32) * 5/9
  hourly_hash = parsed_pirate_weather_response.fetch("hourly")
  hourly_summary = hourly_hash.fetch("summary")

  @current_loc_temp = currently_temp_F
  @current_loc_sum = currently_summary

  precip_threshold = 0.10
  any_precipitation = false
  next_twelve_hours = hourly_hash.fetch("data")[1..12]

  next_twelve_hours.each do |next_twelve_hours_hash|

    hour_precip_probability = next_twelve_hours_hash.fetch("precipProbability")

    if hour_precip_probability >= precip_threshold

      any_precipitation = true
    end
  end

  if any_precipitation
    @current_loc_umbrella = "You might want to take an umbrella!"
  else
    @current_loc_umbrella = "You probably won't need an umbrella."
  end

  erb(:umbrella_results)
end

get("/message") do
 
  erb(:message_form)
end

post("/process_single_message") do
  @user_message = params.fetch("the_message")
  @chatgpt_response = ask_chatgpt(@user_message)

  erb(:message_results)
end

get("/chat") do
  if cookies.has_key?("counter") == false
    cookies.store("counter", 0)
  end

  erb(:chat) 
end

post("/add_message_to_chat") do
  counter = cookies.fetch("counter")

  cookies.store("message_#{counter}", params.fetch("user_message"))
  cookies.store("gpt_response_#{counter}", ask_chatgpt(params.fetch("user_message")))
  cookies["counter"] = cookies["counter"].to_i + 1

  redirect :chat
end

post("/clear_chat") do
  cookies.keys.each do |key|
    cookies.delete(key)
  end

  redirect :chat
end


# OPEN AI API REQUEST AND RESPONSE
def ask_chatgpt(prompt)

  request_headers_hash = {
    "Authorization" => "Bearer #{ENV.fetch("OPENAI_KEY")}",
    "content-type" => "application/json"
  }

  request_body_hash = {
    "model" => "gpt-3.5-turbo",
    "messages" => [
      {
        "role" => "system",
        "content" => "You are a helpful assistant who talks like Shakespeare."
      },
      {
        "role" => "user",
        "content" => prompt
      }
    ]
  }

  request_body_json = JSON.generate(request_body_hash)

  raw_response = HTTP.headers(request_headers_hash).post(
    "https://api.openai.com/v1/chat/completions",
    :body => request_body_json
  ).to_s

  parsed_response = JSON.parse(raw_response)
  
  chatgpt_response = parsed_response.dig("choices", 0, "message", "content")

  return chatgpt_response
end
