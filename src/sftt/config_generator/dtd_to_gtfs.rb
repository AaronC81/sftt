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

      # All TIPLOCs in the UK2GTFS conversion.
      private def tiplocs
        unless @tiplocs
          @tiplocs = CSV.new(File.read(output_gtfs_file('stops.txt')), headers: true)
            .map { it['stop_id'] }
            .to_set
        end

        @tiplocs
      end

      # UK2GTFS creates transfers with undefined TIPLOCs, seemingly for stations with multiple TIPLOCs
      # to one CRS. Remove any invalid TIPLOCs so OpenTripPlanner doesn't complain.
      private def postprocess_clean_transfers      
        transfers = CSV.new(File.read(output_gtfs_file('transfers.txt')), headers: true)
        valid_transfers = []
        transfers.each do |transfer|
          if tiplocs.include?(transfer['from_stop_id']) && tiplocs.include?(transfer['to_stop_id'])
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
          unless tiplocs.include?(stop_id)
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
