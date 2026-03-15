require 'graphql/client'
require 'graphql/client/http'
require 'net/http'

module Sftt
  module OpenTripPlanner
    class GraphQLConnection
      def initialize
        @http = GraphQL::Client::HTTP.new("http://localhost:8080/otp/routers/default/transmodel/index/graphql") do
          # Keep the HTTP connection alive - we'll be absolutely slamming OpenTripPlanner with requests,
          # this makes a noticeable difference to performance.
          def connection
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = uri.scheme == "https"
            http.keep_alive_timeout = 30
            http
          end
        end
        @schema = GraphQL::Client.load_schema(@http)
        @client = GraphQL::Client.new(schema: @schema, execute: @http)
        parse_queries
      end

      def query_quays
        @client.query(QuaysQuery)
          .to_h['data']['quays']
          .map { it['id'] }
          .sort
      end

      def query_trip(from_quay:, to_quay:, date_time:, search_window:)
        # TODO: transform to Ruby objects
        @client.query(
          TripQuery,
          variables: {
            fromPlace: from_quay,
            toPlace: to_quay,
            dateTime: date_time,
            searchWindow: search_window,
          },
        )
      end

      private def parse_queries
        # `graphql/client` requires that queries are in a constant (???), but we need to connect to
        # the client dynamically because the server won't be running when SFTT starts. Use horrible
        # `const_set` to work around it.

        GraphQLConnection.const_set :QuaysQuery, @client.parse(<<-GRAPHQL)
          query {
            quays { id }
          }
        GRAPHQL

        GraphQLConnection.const_set :TripQuery, @client.parse(<<-GRAPHQL)
          query($fromPlace: String, $toPlace: String, $dateTime: DateTime, $searchWindow: Int) {
            trip(
              from: { place: $fromPlace },
              to: { place: $toPlace },
              dateTime: $dateTime,
              searchWindow:  $searchWindow,
            ) {
              tripPatterns {
                legs {
                  mode
                  distance
                  duration
                  fromPlace { ...PlaceFields }
                  toPlace { ...PlaceFields }
                  authority { id }
                }
              }
            }
          }

          fragment PlaceFields on Place {
            name
            quay { id }
          }
        GRAPHQL
      end
    end
  end
end
