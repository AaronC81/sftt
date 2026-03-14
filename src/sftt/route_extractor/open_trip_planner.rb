require 'graphql/client'
require 'graphql/client/http'

module Sftt
  module OpenTripPlanner
    HTTP = GraphQL::Client::HTTP.new("http://localhost:8080/otp/routers/default/transmodel/index/graphql") do
      # Keep the HTTP connection alive - we'll be absolutely slamming OpenTripPlanner with requests,
      # this makes a noticeable difference to performance.
      def connection
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.keep_alive_timeout = 30
        http
      end
    end
    Schema = GraphQL::Client.load_schema(HTTP)
    Client = GraphQL::Client.new(schema: Schema, execute: HTTP)

    TripQuery = Client.parse <<-GRAPHQL
      query($fromPlace: String, $toPlace: String) {
        trip(
          from: { place: $fromPlace },
          to: { place: $toPlace },

          # TODO: make these customisable from the CLI
          dateTime: "2026-03-11T11:00:00.000Z",
          searchWindow: 120,
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

    QuaysQuery = Client.parse(<<-GRAPHQL)
      query {
        quays { id }
      }
    GRAPHQL
  end
end
