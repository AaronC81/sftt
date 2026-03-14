# TODO: This should also take in tube data, somehow

require 'fileutils'
require 'optparse'

require_relative 'dtd_to_gtfs'
require_relative 'foot_interchange_generator'

input_dir = nil
output_dir = nil

OptionParser.new do |parser|
  parser.on("--input DIR", "Directory with input files") do |dir|
    raise '--input specified more than once' if input_dir
    input_dir = dir
  end

  parser.on("--output DIR", "Directory for generated OpenTripPlanner data files") do |dir|
    raise '--output specified more than once' if output_dir
    output_dir = dir
  end
end.parse!

raise '--input is required' unless input_dir
raise '--output is required' unless output_dir

FileUtils.mkdir_p(output_dir)

INPUT_TIMETABLE_ZIP = File.join(input_dir, 'timetable.zip')
unless File.exist?(INPUT_TIMETABLE_ZIP)
  abort "Input file missing: #{INPUT_TIMETABLE_ZIP}"
end

OUTPUT_TIMETABLE_GTFS_DIR = File.join(output_dir, 'timetable_gtfs')

dtd_to_gtfs = Sftt::ConfigGenerator::DtdToGtfs.new(
  INPUT_TIMETABLE_ZIP,
  OUTPUT_TIMETABLE_GTFS_DIR,
)
dtd_to_gtfs.convert

foot_ix = Sftt::ConfigGenerator::FootInterchangeGenerator.new(OUTPUT_TIMETABLE_GTFS_DIR)
foot_ix.generate(File.join(OTP_DIRECTORY, 'transfers.osm.pbf'))
