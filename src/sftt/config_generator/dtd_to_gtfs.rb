require 'csv'
require 'fileutils'
require_relative 'r'

module Sftt
  module ConfigGenerator
    # Convert zipped National Rail DTD timetable data (https://wiki.openraildata.com/index.php/DTD) to
    # GTFS format.
    class DtdToGtfs
      def initialize(input_dtd_zip, output_gtfs_dir)
        @input_dtd_zip = input_dtd_zip
        @output_gtfs_dir = output_gtfs_dir
      end

      attr_reader :input_dtd_zip, :output_gtfs_dir

      def convert
        raw_zip = output_gtfs_dir + "_raw.zip"
        convert_to_unprocessed_zip(raw_zip)

        system("unzip", "-o", raw_zip, "-d", output_gtfs_dir) or raise 'ZIP extraction failed'
        FileUtils.rm(raw_zip)

        postprocess_clean_transfers
        postprocess_convert_tiploc_to_crs
        postprocess_add_missing_stops
      end

      # Run the UK2GTFS R library to perform most of the conversion.
      private def convert_to_unprocessed_zip(output_gtfs_zip)
        output_gtfs_dir = File.dirname(output_gtfs_zip)
        output_gtfs_name = File.basename(output_gtfs_zip, '.zip')

        R.execute_script(
          'library(UK2GTFS)',
          "gtfs <- atoc2gtfs(path_in = \"#{input_dtd_zip}\", ncores = 3)",
          "gtfs_write(gtfs, folder = \"#{output_gtfs_dir}\", name = \"#{output_gtfs_name}\")"
        )
      end

      # All IDs in the UK2GTFS conversion.
      # Before post-processing, these are TIPLOCs. After, these are CRSes.
      private def stop_ids(flush: false)
        @stop_ids = nil if flush

        unless @stop_ids
          @stop_ids = CSV.new(File.read(output_gtfs_file('stops.txt')), headers: true)
            .map { it['stop_id'] }
            .to_set
        end

        @stop_ids
      end

      # Replace TIPLOC IDs throughout the GTFS dataset with CRS IDs instead.
      private def postprocess_convert_tiploc_to_crs
        stops = CSV.new(File.read(output_gtfs_file('stops.txt')), headers: true)

        # Decide which stop we're going to keep if multiple have the same CRS
        crs_to_stops = {}
        stops.each do |stop|
          crs = stop['stop_code']
          next if crs.nil? || crs.strip.empty?

          crs_to_stops[crs] ||= []
          crs_to_stops[crs] << stop
        end
        crs_to_stop = {}
        crs_to_stops.each do |crs, stops|
          # Some heuristics from 2026 timetable data which seem to give sensible results:
          #   Sometimes the stops have identical names, we can just pick either
          if stops.map { it['stop_code'] }.uniq.length == 1
            crs_to_stop[crs] = stops.uniq.first
            next
          end

          #   Stops with uppercase names are usually random bus stops
          stops = stops.reject { !(/[a-z]/ === it['stop_code']) }
          if stops.length == 1
            crs_to_stop[crs] = stops.first
            next
          end

          #   Some strings indicate a "secondary" station
          secondary_indicators = ['High Level', 'Low Level', 'ELL', 'NLL', 'DC']
          stops = stops.reject { |stop| secondary_indicators.any? { stop['stop_name'].include?(it) } }
          if stops.length == 1
            crs_to_stop[crs] = stops.first
            next
          end

          # Oh no! Pick the first one
          puts "Warning: Still more than one stop for CRS '#{crs}' after filtering"
          crs_to_stop[crs] = stops.first
        end

        tiploc_to_crs = {}
        crs_to_stops.each do |crs, stops|
          stops.each do |stop|
            tiploc_to_crs[stop['stop_id']] = crs
          end
        end

        # Rewrite stops.txt to keep only the "canonical" station definitions, with CRS as the new ID
        CSV.open('stops.txt', 'w') do |writer|
          writer << stops.headers
          crs_to_stop.each do |crs, stop|
            stop['stop_id'] = crs
            writer << stop
          end
        end

        # Rewrite stop_times.txt to reference stops with their new ID
        stop_times = CSV.new(File.read(output_gtfs_file('stop_times.txt')), headers: true)
        stop_times.each.first # Required to populate `#headers`
        CSV.open('stop_times.txt', 'w') do |writer|
          writer << stop_times.headers
          stop_times.each do |stop_time|
            stop_time['stop_id'] = tiploc_to_crs[stop_time['stop_id']]
            unless stop_time['stop_id'].nil?
              writer << stop_time
            end
          end
        end

        # Rewrite transfers.txt to reference stops with their new ID
        transfers = CSV.new(File.read(output_gtfs_file('transfers.txt')), headers: true)
        transfers.each.first # Required to populate `#headers`
        CSV.open('transfers.txt', 'w') do |writer|
          writer << transfers.headers
          transfers.each do |transfer|
            transfer['from_stop_id'] = tiploc_to_crs[transfer['from_stop_id']]
            transfer['to_stop_id'] = tiploc_to_crs[transfer['to_stop_id']]
            unless transfer['from_stop_id'].nil? || transfer['to_stop_id'].nil?
              writer << transfer
            end
          end
        end

        # Flush cached IDs, we just changed them all!
        stop_ids(flush: true)
      end

      # UK2GTFS creates transfers with undefined TIPLOCs, seemingly for stations with multiple TIPLOCs
      # to one CRS. Remove any invalid TIPLOCs so OpenTripPlanner doesn't complain.
      private def postprocess_clean_transfers      
        transfers = CSV.new(File.read(output_gtfs_file('transfers.txt')), headers: true)
        valid_transfers = []
        transfers.each do |transfer|
          if stop_ids.include?(transfer['from_stop_id']) && stop_ids.include?(transfer['to_stop_id'])
            valid_transfers << transfer
          end
        end

        CSV.open(output_gtfs_file('transfers.txt'), 'w', headers: transfers.headers, write_headers: true) do |transfers_writer|
          valid_transfers.each do |transfer|
            transfers_writer << transfer
          end
        end
      end

      # UK2GTFS sometimes misses stops from stops.txt which are then referenced in stop_times.txt.
      # Find these stops and add them so the data is consistent.
      private def postprocess_add_missing_stops
        missing_stops = Set.new

        stop_times = CSV.new(File.read(output_gtfs_file('stop_times.txt')), headers: true)
        stop_times.each do |stop_time|
          stop_id = stop_time['stop_id']
          unless stop_ids.include?(stop_id)
            missing_stops << stop_id
          end
        end

        # TODO: use CSV library, figure out how to append in the same order as headers
        File.open(output_gtfs_file('stops.txt'), 'a') do |stops_writer|
          missing_stops.each do |tiploc|
            # TODO: use real data
            stops_writer.puts [tiploc, tiploc, tiploc, 0, 0].join(',')
          end
        end
      end

      private def output_gtfs_file(name) = File.join(output_gtfs_dir, name)
    end
  end
end
