# TODO: This should also take in tube data, somehow
# TODO: add command-line options for directories

require 'fileutils'

require_relative 'dtd_to_gtfs'
require_relative 'foot_interchange_generator'

INPUT_DIRECTORY = File.join(__dir__, '..', 'inputs')

OTP_DIRECTORY = File.join(__dir__, '..', 'scratch', 'otp')
FileUtils.mkdir_p(OTP_DIRECTORY)

INPUT_TIMETABLE_ZIP = File.join(INPUT_DIRECTORY, 'timetable.zip')
unless File.exist?(INPUT_TIMETABLE_ZIP)
  abort "Input file missing: #{INPUT_TIMETABLE_ZIP}"
end

OUTPUT_TIMETABLE_GTFS_DIR = File.join(OTP_DIRECTORY, 'timetable_gtfs')

dtd_to_gtfs = Sftt::ConfigGenerator::DtdToGtfs.new(
  INPUT_TIMETABLE_ZIP,
  OUTPUT_TIMETABLE_GTFS_DIR,
)
dtd_to_gtfs.convert

foot_ix = Sftt::ConfigGenerator::FootInterchangeGenerator.new(OUTPUT_TIMETABLE_GTFS_DIR)
foot_ix.generate(File.join(OTP_DIRECTORY, 'transfers.osm.pbf'))
