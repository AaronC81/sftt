require 'json'

module Sftt
  # Replace subsections of OpenTripPlanner routes with faster TFL-powered (bus/tube) alternatives.
  module TflReplace
    ROUTES = JSON.parse(File.read(File.join(__dir__, '..', '..', '..', 'data', 'tube_routes.json')))

    # Mutate a `legs` array (like JSON format) to improve TFL links.
    def self.process_route(legs)
      # TODO: Check how this handles KGX/SPX. currently a 5 min walk

      # We're specifically looking for legs that transfer within London, e.g.
      #
      #    Crewe -> Euston ; Euston -> Waterloo ; Waterloo -> Southampton
      #                      ^^^^^^^^^^^^^^^^^^
      # 
      first_index = legs.index { |leg| london_station?(leg[:from]) }
      last_index = legs.rindex { |leg| london_station?(leg[:to]) }

      if first_index.nil? || last_index.nil?
        return
      end
      if last_index < first_index
        return
      end

      from = legs[first_index][:from]
      to = legs[last_index][:to]
      original_duration = legs[first_index..last_index].map { it[:duration] }.sum

      if tfl_route_duration(from, to) < original_duration
        puts "[TfL] Replacing leg '#{from} -> #{to}' with faster TfL transfer"
        legs[first_index..last_index] = tfl_route_to_sftt_legs(from, to)
      end
    end

    def self.tfl_route_to_sftt_legs(from_crs, to_crs)
      legs = ROUTES[from_crs][to_crs]
        .map do |leg|
          {
            mode: leg['mode'],
            from: "##{leg['from']}",
            to: "##{leg['to']}",
            duration: leg['duration'],
          }
        end

      # Replace very first and very last point with CRS so route links up nicely
      legs.first[:from] = from_crs
      legs.last[:to] = to_crs

      legs
    end

    def self.tfl_route_duration(from_crs, to_crs)
      unless ROUTES[from_crs][to_crs]
        puts "[TfL] Failed to find possibly-better route for leg '#{from_crs} -> #{to_crs}'"
        return 9999999999
      end

      ROUTES[from_crs][to_crs]
        .map { |leg| leg['duration'] }
        .sum
    end

    def self.london_station?(id) = ROUTES.has_key?(id)
  end
end
