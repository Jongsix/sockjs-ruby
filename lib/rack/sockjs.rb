# encoding: utf-8

require "rack"
require "sockjs"
require "sockjs/adapter"

# Adapters.
require "sockjs/adapters/chunking_test"
require "sockjs/adapters/eventsource"
require "sockjs/adapters/htmlfile"
require "sockjs/adapters/iframe"
require "sockjs/adapters/jsonp"
require "sockjs/adapters/welcome_screen"
require "sockjs/adapters/xhr"

# This is a Rack middleware for SockJS.
#
# @example
#  require "rack/sockjs"
#
#  use SockJS, "/echo" do |connection|
#    connection.subscribe do |session, message|
#      session.send(message)
#    end
#  end
#
#  use SockJS, "/disabled_websocket_echo",
#    disabled_transports: [SockJS::WebSocket] do |connection|
#    # ...
#  end
#
#  use SockJS, "/close" do |connection|
#    connection.session_open do |session|
#      session.close(3000, "Go away!")
#    end
#  end
#
#  run MyApp

module Rack
  class SockJS
    def initialize(app, prefix = "/echo", options = Hash.new, &block)
      @app, @prefix, @options = app, prefix, options

      unless block
        raise "You have to provide SockJS app as the block argument!"
      end

      # Validate options.
      if options[:sockjs_url].nil? && ! options[:disabled_transports].include?(::SockJS::Adapters::IFrame)
        raise RuntimeError.new("You have to provide sockjs_url in options, it's required for the iframe transport!")
      end

      @connection ||= begin
        ::SockJS::Connection.new(&block)
      end
    end

    def call(env)
      matched = env["PATH_INFO"].match(/^#{Regexp.quote(@prefix)}/)

      debug "~ #{env["REQUEST_METHOD"]} #{env["PATH_INFO"].inspect} (matched: #{!! matched})"

      if matched
        prefix        = env["PATH_INFO"].sub(/^#{Regexp.quote(@prefix)}\/?/, "")
        method        = env["REQUEST_METHOD"]
        handler_klass = ::SockJS::Adapter.handler(prefix, method)
        if handler_klass
          debug "~ Handler: #{handler_klass.inspect}"
          handler = handler_klass.new(@connection, @options)
          return handler.handle(env).tap do |response|
            debug "~ Response: #{response.inspect}"
          end
        else
          body = <<-HTML
            <!DOCTYPE html>
            <html>
              <body>
                <h1>Handler Not Found</h1>
                <ul>
                  <li>Prefix: #{prefix.inspect}</li>
                  <li>Method: #{method.inspect}</li>
                  <li>Handlers: #{::SockJS::Adapter.subclasses.inspect}</li>
                </ul>
              </body>
            </html>
          HTML
          [404, {"Content-Type" => "text/html; charset=UTF-8", "Content-Length" => body.bytesize.to_s}, [body]]
        end
      else
        @app.call(env)
      end
    end

    private
    def debug(message)
      STDERR.puts(message)
    end
  end
end
