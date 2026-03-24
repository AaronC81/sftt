require 'json'
require 'fileutils'
require_relative 'data'

TFL_APP_KEY = ENV['SFTT_TFL_APP_KEY'] or abort 'missing API key'

def fetch_tfl_routes(from_naptan, to_naptan, modes:, include_entrance_walking:)
  result = `curl \"https://api.tfl.gov.uk/Journey/JourneyResults/#{from_naptan}/to/#{to_naptan}?app_key=#{TFL_APP_KEY}&mode=#{modes}&routeBetweenEntrances=#{include_entrance_walking ? 'true' : 'false'}&date=20260323&time=1030\"`
  raise 'curl failed' unless $?.success?
  result
end

FileUtils.mkdir_p(File.join(__dir__, 'routes'))
CRS_TO_NAPTAN.each do |from_crs, from_naptan|
  CRS_TO_NAPTAN.each do |to_crs, to_naptan|
    puts "#{from_crs} -> #{to_crs}"

    threads = [
      Thread.new do
        File.write(
          File.join(__dir__, 'routes', "#{from_crs}_#{to_crs}_any_without_transfers.json"),
          fetch_tfl_routes(from_naptan, to_naptan, modes: 'tube,elizabeth-line,walking', include_entrance_walking: false),
        )
      end,
      Thread.new do
        File.write(
          File.join(__dir__, 'routes', "#{from_crs}_#{to_crs}_any_with_transfers.json"),
          fetch_tfl_routes(from_naptan, to_naptan, modes: 'tube,elizabeth-line,walking', include_entrance_walking: true),
        )
      end,
      Thread.new do
        File.write(
          File.join(__dir__, 'routes', "#{from_crs}_#{to_crs}_walk.json"),
          fetch_tfl_routes(from_naptan, to_naptan, modes: 'walking', include_entrance_walking: false),
        )
      end,
    ]
    threads.map(&:join)
  end
end
