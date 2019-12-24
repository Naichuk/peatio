require 'memoist'
require 'faraday'
require 'better-faraday'

module Peatio
  module Monero
    class Client
      Error = Class.new(StandardError)
      class ConnectionError < Error; end

      class ResponseError < Error
        def initialize(code, msg)
          @code = code
          @msg = msg
        end

        def message
          "#{@msg} (#{@code})"
        end
      end

      extend Memoist

      def initialize(endpoint)
        @json_rpc_endpoint = URI.parse(endpoint)
      end

      def json_rpc(path, method, params = {})
        params.merge!(method: method) unless method.nil?
        http = Curl.post(@json_rpc_endpoint.to_s + "/#{path}", params.to_json) do |curl|
          curl.headers["Content-Type"] = "application/json"
          curl.headers["Accept"] = "application/json"
          curl.http_auth_types = :digest
          curl.username = @json_rpc_endpoint.user
          curl.password = @json_rpc_endpoint.password
          curl.verbose = true
        end
        response = JSON.parse(http.body)
        response['error'].tap { |e| raise ResponseError.new(e['code'], e['message']) if e }
        response.fetch('result', nil).nil? ? response : response.fetch('result')

      rescue => e
        if e.is_a?(Error)
          raise e
        elsif e.is_a?(Faraday::Error)
          raise ConnectionError, e
        else
          raise Error, e
        end
      end

      private

      def connection
        Faraday.new(@json_rpc_endpoint).tap do |connection|
          unless @json_rpc_endpoint.user.blank?
            connection.basic_auth(@json_rpc_endpoint.user,
                                  @json_rpc_endpoint.password)
          end
        end
      end
      memoize :connection
    end
  end
end
