# TODO: command-line options
# TODO: include a fixed date/time in the query
# TODO: when tube is supported, may need to differentiate between TIPLOCs or Tube Stations

require 'fileutils'
require 'json'
require 'concurrent'
require_relative 'open_trip_planner'

OUTPUT_DIRECTORY = File.join(__dir__, '..', '..', 'scratch', 'routes')
FileUtils.mkdir_p(OUTPUT_DIRECTORY)

quays = Sftt::OpenTripPlanner::Client
  .query(Sftt::OpenTripPlanner::QuaysQuery)
  .to_h['data']['quays']
  .map { it['id'] }
  .sort

def quay_to_tiploc(quay)
  quay.split(':').last
end

quays.each do |from_quay|
  puts "#{from_quay}"
  all_routes = {}

  thread_pool = Concurrent::FixedThreadPool.new(16)
  quays.each do |to_quay|
    thread_pool.post do
      puts "  -> #{to_quay}"

      response = Sftt::OpenTripPlanner::Client.query(
        Sftt::OpenTripPlanner::TripQuery,
        variables: {
          fromPlace: from_quay,
          toPlace: to_quay,
        }
      )
      
      # TODO: prune to "best" route if there are multiple (e.g. LEEDS -> YORK, many direct trains)
      routes = []
      response.to_h['data']['trip']['tripPatterns'].each do |trip|
        routes << {
          legs: trip['legs']
            .map do |leg| 
              {
                mode: leg['mode'],
                from: quay_to_tiploc(leg['fromPlace']['quay']['id']),
                to: quay_to_tiploc(leg['toPlace']['quay']['id']),
                duration: leg['duration'],
              }
            end
        }
      end
      
      all_routes[quay_to_tiploc(to_quay)] = { routes: }
    end
  end

  thread_pool.shutdown
  thread_pool.wait_for_termination

  File.write(
    File.join(OUTPUT_DIRECTORY, "#{quay_to_tiploc(from_quay)}.json"),
    all_routes.to_json,
  )
end
