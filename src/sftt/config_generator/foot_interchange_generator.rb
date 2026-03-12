require 'csv'
require 'open3'

module Sftt
  module ConfigGenerator
    # Generate an OpenStreetMap export which imagines that there's a straight footpath between
    # nearby stations.
    # 
    # This enables OpenTripPlanner to generate foot interchanges between stations when they might be
    # appropriate. Without any footpath data, OpenTripPlanner some rather erratic routes in my
    # experience (e.g. loops back to the same station). On the other hand, importing full UK
    # OpenStreetMap exports is far too slow. This is a middle ground! The times won't be accurate,
    # but it will at least produce a correct route.
    class FootInterchangeGenerator
      # Maximum distance for generating a footpath between two stations
      WAY_THRESHOLD_METRES = 10000

      def initialize(input_gtfs_dir)
        @input_gtfs_dir = input_gtfs_dir
      end

      attr_reader :input_gtfs_dir

      def generate(output_file)
        Open3.popen2e('osmosis', '--read-xml', '-', '--write-pbf', output_file) do |stdin, output, thread|
          write_xml(stdin)
          stdin.close

          while (line = output.gets)
            puts line
          end

          exit = thread.value
          unless exit.success?
            raise 'Converting XML to PBF using Osmosis failed'
          end
        end
      end

      private def write_xml(io)
        stations = CSV.read(File.join(input_gtfs_dir, 'stops.txt'), headers: true)

        io.puts '<?xml version="1.0" encoding="UTF-8"?>'
        io.puts '<osm version="0.6">'

        # Generate a node for each station
        stations.each.with_index do |station, i|
          io.puts "<node id=\"#{i+1}\" lat=\"#{station['stop_lat']}\" lon=\"#{station['stop_lon']}\" visible=\"true\" version=\"1\" timestamp=\"2026-03-11T23:50:00Z\">"
          io.puts "  <tag k=\"name\" v=\"#{station['stop_name'].gsub('&', '&amp;')}\" />"
          io.puts '</node>'
        end

        # Generate a way between each station
        stations.each.with_index do |from, from_i|
          stations.each.with_index do |to, to_i|
            next if from_i == to_i

            distance_metres = haversine(
              from['stop_lat'].to_f, from['stop_lon'].to_f,
              to['stop_lat'].to_f, to['stop_lon'].to_f
            )
            next if distance_metres > WAY_THRESHOLD_METRES

            id = 10000 * (from_i + 1) + (to_i + 1)
            io.puts "<way id=\"#{id}\" version=\"1\" timestamp=\"2026-03-11T23:50:00Z\">"
            io.puts "  <nd ref=\"#{from_i+1}\" />"
            io.puts "  <nd ref=\"#{to_i+1}\" />"
            io.puts "  <tag k=\"highway\" v=\"footpath\" />"
            io.puts "</way>"
          end
        end

        io.puts '</osm>'
      end

      # https://www.movable-type.co.uk/scripts/latlong.html
      private def haversine(lat1, lng1, lat2, lng2)
        r = 6371e3.to_f
        phi1 = lat1 * Math::PI / 180
        phi2 = lat2 * Math::PI / 180
        delta_phi = (lat2-lat1) * Math::PI / 180
        delta_lambda = (lng2-lng1) * Math::PI / 180

        a = Math.sin(delta_phi / 2) * Math.sin(delta_phi / 2) +
                Math.cos(phi1) * Math.cos(phi2) *
                Math.sin(delta_lambda / 2) * Math.sin(delta_lambda / 2)
        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))

        r * c
      end
    end
  end
end
