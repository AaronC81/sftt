# Assumes `fetch_tube_info.rb` has run first.
require 'json'
require_relative 'data'

all_routes = {}

routes_dir = File.join(__dir__, 'routes')
Dir.entries(routes_dir).each do |entry|
  next if entry.start_with?('.')

  from_crs, to_crs = File.basename(entry, '.json').split('_')
  next if from_crs == to_crs || CRS_TO_NAPTAN[from_crs] == CRS_TO_NAPTAN[to_crs]

  puts "#{from_crs} -> #{to_crs}"
  all_routes[from_crs] ||= {}

  # Find only the single best route, that's all we need.
  journeys_json = JSON.parse(File.read(File.join(routes_dir, entry)))
  shortest_journey = journeys_json['journeys'].min_by { it['duration'] }

  shortest_journey['legs'].each do |leg|
    puts "  #{leg['mode']['id']}: #{leg['departurePoint']['commonName']} -> #{leg['arrivalPoint']['commonName']}, #{leg['duration']} mins, #{leg['routeOptions'].map { it['name'] }.join(' / ')}"
  end

  all_routes[from_crs][to_crs] =
    shortest_journey['legs'].map do |leg|
      {
        mode: leg.fetch('mode').fetch('id'),
        from: leg.fetch('departurePoint').fetch('commonName'),
        to: leg.fetch('arrivalPoint').fetch('commonName'),
        duration: leg.fetch('duration') * 60, # minutes to seconds
      }
    end
end

File.write(File.join(__dir__, '..', 'tube_routes.json'), all_routes.to_json)
