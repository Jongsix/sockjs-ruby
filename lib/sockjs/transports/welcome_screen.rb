# encoding: utf-8

require "sockjs/transport"

module SockJS
  module Transports
    class WelcomeScreen < Transport
      def handle(request)
        response(request, 200) do |response|
          response.set_content_type(:plain)
          response.finish("Welcome to SockJS!\n")
        end
      end
    end
  end
end
