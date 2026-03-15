# TODO: This should also take in tube data, somehow

require 'fileutils'
require 'optparse'

require_relative 'dtd_to_gtfs'
require_relative 'foot_interchange_generator'
require_relative '../common/open_trip_planner'

input_dir = nil
output_dir = nil

otp_jar = nil
otp_pause = false
memory = 16

OptionParser.new do |parser|
  parser.on("--input DIR", "Directory with input files") do |dir|
    raise '--input specified more than once' if input_dir
    input_dir = dir
  end

  parser.on("--output DIR", "Directory for generated OpenTripPlanner data files") do |dir|
    raise '--output specified more than once' if output_dir
    output_dir = dir
  end

  parser.on("--otp-jar FILE", "Path to OpenTripPlanner JAR file, if you'd like to build a graph") do |jar|
    raise '--otp-jar specified more than once' if otp_jar
    otp_jar = jar
  end

  parser.on("--otp-pause", "Wait for confirmation before closing OpenTripPlanner after building graph, if you'd like to perform spot-checks") do
    otp_pause = true
  end

  parser.on("--memory GB", "Number of gigabytes of memory to allocate for OpenTripPlanner. Default #{memory}") do |mem|
    memory = Integer(mem)
  end
end.parse!

raise '--input is required' unless input_dir
raise '--output is required' unless output_dir
raise '--otp-pause is invalid without --otp-jar' if otp_pause && !otp_jar
raise '--memory is invalid without --otp-jar' if memory && !otp_jar

FileUtils.mkdir_p(output_dir)

INPUT_TIMETABLE_ZIP = File.join(input_dir, 'timetable.zip')
unless File.exist?(INPUT_TIMETABLE_ZIP)
  abort "Input file missing: #{INPUT_TIMETABLE_ZIP}"
end

# Build rail network GTFS
OUTPUT_TIMETABLE_GTFS_DIR = File.join(output_dir, 'timetable_gtfs')
dtd_to_gtfs = Sftt::ConfigGenerator::DtdToGtfs.new(
  INPUT_TIMETABLE_ZIP,
  OUTPUT_TIMETABLE_GTFS_DIR,
)
dtd_to_gtfs.convert

# Generate foot interchanges
foot_ix = Sftt::ConfigGenerator::FootInterchangeGenerator.new(OUTPUT_TIMETABLE_GTFS_DIR)
foot_ix.generate(File.join(output_dir, 'transfers.osm.pbf'))

if otp_jar
  # Generate graph
  otp_server = Sftt::OpenTripPlanner::Server.new(otp_jar, output_dir)
  otp_server.start(memory:, build_graph: true)
  if otp_pause
    puts "=================================================================="
    puts "OpenTripPlanner graph build complete."
    puts "Because you passed --otp-pause, the server is still running."
    puts "  http://localhost:8080"
    puts "Press Enter to stop it."
    puts "=================================================================="
    $stdin.gets
  end
  otp_server.stop
end
