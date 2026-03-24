# Assumes `fetch_tube_info.rb` has run first.
require 'json'
require_relative 'data'

ROUTES_DIR = File.join(__dir__, 'routes')

all_routes = {}

# Returns journey hash, or `nil` if unroutable
def load_fastest_journey(from, to, mode)
  journeys_json = JSON.parse(File.read(File.join(ROUTES_DIR, "#{from}_#{to}_#{mode}.json")))
  return nil unless journeys_json['journeys']

  journeys_json['journeys'].min_by { it['duration'] }
end

CRS_TO_NAPTAN.each do |from_crs, _|
  CRS_TO_NAPTAN.each do |to_crs, _|
    next if from_crs == to_crs || CRS_TO_NAPTAN[from_crs] == CRS_TO_NAPTAN[to_crs]

    puts "#{from_crs} -> #{to_crs}"
    all_routes[from_crs] ||= {}

    # Find only the single best route, that's all we need.
    #
    # The decision process for routing:
    #   1. If it's faster to walk than to travel by tube *INCLUDING TRANSFER TIME*, then walk.
    #   2. Otherwise, emit the travel time by tube *WITHOUT TRANSFER TIME*, for consistency with
    #      rail routing.
    walking_journey = load_fastest_journey(from_crs, to_crs, 'walk')
    tube_transfer_journey = load_fastest_journey(from_crs, to_crs, 'any_with_transfers')
    tube_transferless_journey = load_fastest_journey(from_crs, to_crs, 'any_without_transfers')

    if walking_journey && walking_journey['duration'] <= tube_transfer_journey['duration']
      best_journey = walking_journey
    else
      best_journey = tube_transferless_journey
    end

    best_journey['legs'].each do |leg|
      puts "  #{leg['mode']['id']}: #{leg['departurePoint']['commonName']} -> #{leg['arrivalPoint']['commonName']}, #{leg['duration']} mins, #{leg['routeOptions'].map { it['name'] }.join(' / ')}"
    end

    all_routes[from_crs][to_crs] =
      best_journey['legs'].map do |leg|
        {
          mode: leg.fetch('mode').fetch('id'),
          from: leg.fetch('departurePoint').fetch('commonName'),
          to: leg.fetch('arrivalPoint').fetch('commonName'),
          duration: leg.fetch('duration') * 60, # minutes to seconds
        }
      end
  end
end

File.write(File.join(__dir__, '..', 'tube_routes.json'), all_routes.to_json)
