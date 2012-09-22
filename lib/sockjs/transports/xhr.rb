# encoding: utf-8

require "sockjs/transport"

module SockJS
  module Transports
    class XHRPost < Transport
      register '/xhr', 'POST'

      def handle(request)
        response(request, 200, session: :create) do |response, session|
          unless session.newly_created?
            response.set_content_type(:plain)
            session.process_buffer
          else
            response.set_content_type(:javascript)
            response.set_access_control(request.origin)
            response.set_session_id(request.session_id)

            session.open!
          end
        end
      end
    end

    class XHROptions < Transport
      register '/xhr', 'OPTIONS'

      def handle(request)
        response(request, 204) do |response|
          response.set_allow_options_post
          response.set_cache_control
          response.set_access_control(request.origin)
          response.set_session_id(request.session_id)
          response.finish
        end
      end
    end

    class XHRSendPost < Transport
      register '/xhr_send', 'POST'

      def handle(request)
        response(request, 204, data: request.data.read) do |response, session|
          if session
            # When we use HTTP 204 with Content-Type, Rack::Lint
            # will be bitching about it. That's understandable,
            # as Lint is suppose to make sure that given response
            # is valid according to the HTTP standard. However
            # what's totally sick is that Lint is included by default
            # in the development mode. It'd be really dishonest
            # to change this behaviour, regardless how jelly brain
            # minded it is. Funnily enough users can't deactivate
            # Lint either in development, so we'll have to tell them
            # to hack it. Bloody hell, that just can't be happening!
            response.set_content_type(:plain)
            response.set_access_control(request.origin)
            response.set_session_id(request.session_id)
            response.write_head
          else
            raise SockJS::HttpError.new(404, "Session is not open!") { |response|
              response.set_session_id(request.session_id)
            }
          end
        end

      rescue SockJS::HttpError => error
        error.to_response(self, request)
      end
    end

    class XHRSendOptions < XHROptions
      register '/xhr_send', 'OPTIONS'
    end

    class XHRStreamingPost < Transport
      PREAMBLE ||= "h" * 2048 + "\n"

      register '/xhr_streaming', 'POST'

      def session_class
        SockJS::Session
      end

      def handle(request)
        response(request, 200, session: :create) do |response, session|
          response.set_content_type(:javascript)
          response.set_access_control(request.origin)
          response.set_session_id(request.session_id)
          response.write_head

          # IE requires 2KB prefix:
          # http://blogs.msdn.com/b/ieinternals/archive/2010/04/06/comet-streaming-in-internet-explorer-with-xmlhttprequest-and-xdomainrequest.aspx
          response.write(PREAMBLE)

          if session.newly_created?
            session.open!
          end

          session.wait(response)
        end
      end

      def handle_session_unavailable(error, response)
        response.write(PREAMBLE)
        super(error, response)
      end
    end

    class XHRStreamingOptions < XHROptions
      register '/xhr_streaming', 'OPTIONS'
    end
  end
end
