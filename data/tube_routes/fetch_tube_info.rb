require 'json'
require_relative 'data'

TFL_APP_KEY = ENV['SFTT_TFL_APP_KEY'] or abort 'missing API key'

FileUtils.mkdir_p(File.join(__dir__, 'routes'))
CRS_TO_NAPTAN.each do |from_crs, from_naptan|
  CRS_TO_NAPTAN.each do |to_crs, to_naptan|
    puts "#{from_crs} -> #{to_crs}"

    result = `curl \"https://api.tfl.gov.uk/Journey/JourneyResults/#{from_naptan}/to/#{to_naptan}?app_key=#{TFL_APP_KEY}&mode=tube,walking,bus&routeBetweenEntrances=false&date=20260315&time=1030\"`
    raise 'curl failed' unless $?.success?

    File.write(File.join(__dir__, 'routes', "#{from_crs}_#{to_crs}.json"), result)
  end
end
