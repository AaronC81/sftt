require_relative 'graphql_connection'

module Sftt
  module OpenTripPlanner
    class Server
      def initialize(jar, config_dir)
        @jar = jar
        @config_dir = config_dir
      end

      # Start server and wait for GraphQL API to be ready
      def start(build_graph: false, load_graph: false)
        raise ArgumentError, 'you must either build a graph, or load a built graph' unless build_graph ^ load_graph

        raise 'already running' if @pid
        if build_graph
          graph_args = ['--build', '--save']
        else
          graph_args = ['--load']
        end
        @pid = spawn('java', '-Xmx16G', '-jar', @jar, *graph_args, '--serve', @config_dir)

        wait_for_graphql
      end

      def stop
        raise 'not running' unless @pid
        Process.kill(@pid)
        @pid = nil
      end

      # Wait until the server is accepting GraphQL connections
      private def wait_for_graphql(attempts: 240, delay: 1)
        attempts.times do
          unless alive?
            raise "OpenTripPlanner process exited unexpectedly while waiting for API"
          end

          begin
            OpenTripPlanner::GraphQLConnection.new.query_quays
            return
          rescue => e
            # OK - presumably hasn't started yet
            puts "Waiting for API start: #{e}"
          end
          sleep delay
        end

        raise "OpenTripPlanner did not start API in time"
      end

      def alive?
        return false unless @pid

        # https://stackoverflow.com/a/3568291/2626000
        begin
          Process.getpgid(@pid)
          true
        rescue Errno::ESRCH
          false
        end
      end
    end
  end
end
