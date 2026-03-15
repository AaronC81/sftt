# TODO: command-line options
# TODO: include a fixed date/time in the query
# TODO: when tube is supported, may need to differentiate between CRSes or Tube Stations

require 'fileutils'
require 'json'
require 'concurrent'
require 'optparse'
require 'time'

require_relative '../common/open_trip_planner'

otp_config_dir = nil
otp_jar = nil
output_file = nil

to_station = nil
date = Time.now.iso8601
search_window = 120

load = false
memory = 16

OptionParser.new do |parser|
  parser.on("--otp-config DIR", "Directory with OpenTripPlanner config") do |dir|
    raise '--otp-config specified more than once' if otp_config_dir
    otp_config_dir = dir
  end

  parser.on("--otp-jar FILE", "Path to OpenTripPlanner JAR file") do |jar|
    raise '--otp-jar specified more than once' if otp_jar
    otp_jar = jar
  end

  parser.on("--output FILE", "Path to route JSON file to generate") do |file|
    raise '--output specified more than once' if output_file
    output_file = file
  end

  parser.on("--to ID", "CRS of destination station to calculate routes to") do |id|
    raise '--to specified more than once' if to_station
    to_station = id
  end

  parser.on("--date DATE", "ISO 8601 datetime for routing start time. Default now") do |d|
    raise '--date specified more than once' if date
    date = d
  end

  parser.on("--window WINDOW", "Number of minutes to search after the --date. Default #{search_window}") do |window|
    raise '--window specified more than once' if search_window
    search_window = Integer(window)
  end
  
  parser.on("--load", "Load an existing graph from --otp-config instead of building it") do
    load = true
  end

  parser.on("--memory GB", "Number of gigabytes of memory to allocate for OpenTripPlanner. Default #{memory}") do |mem|
    memory = Integer(mem)
  end
end.parse!

raise '--otp-config is required' unless otp_config_dir
raise '--otp-jar is required' unless otp_jar
raise '--output is required' unless output_file
raise '--to is required' unless to_station
raise '--date is required' unless date

otp_server = Sftt::OpenTripPlanner::Server.new(otp_jar, otp_config_dir)
if load
  otp_server.start(memory:, load_graph: true)
else
  otp_server.start(memory:, build_graph: true)
end
at_exit do
  otp_server.stop
end

otp = Sftt::OpenTripPlanner::GraphQLConnection.new
quays = otp.query_quays
puts "Loaded #{quays.length} quays"

def quay_to_crs(quay)
  quay.split(':').last
end

# Assuming that there's only one transit source so the prefix is `1:`
to_quay = "1:#{to_station}"
unless quays.include?(to_quay)
  raise 'unknown --to station'
end

all_routes = {}
exceptions = []
thread_pool = Concurrent::FixedThreadPool.new(16)
quays.each do |from_quay|
  thread_pool.post do
    begin
      puts "  #{from_quay}"

      response = otp.query_trip(from_quay, to_quay)
      
      # TODO: prune to "best" route if there are multiple (e.g. LEEDS -> YORK, many direct trains)
      routes = []
      response.to_h['data']['trip']['tripPatterns'].each do |trip|
        routes << {
          legs: trip['legs']
            .map do |leg| 
              {
                mode: leg['mode'],
                from: quay_to_crs(leg['fromPlace']['quay']['id']),
                to: quay_to_crs(leg['toPlace']['quay']['id']),
                duration: leg['duration'],
              }
            end
        }
      end
      
      all_routes[quay_to_crs(from_quay)] = { routes: }
    rescue => e
      exceptions << e
    end
  end
end

thread_pool.shutdown
thread_pool.wait_for_termination

if exceptions.any?
  puts "#{exceptions.length} exception(s) occurred while processing routes:"
  exceptions.each do |e|
    puts "  - #{e}"
  end
  abort
end

File.write(output_file, all_routes.to_json)
