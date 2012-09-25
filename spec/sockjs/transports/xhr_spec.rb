#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/transports/xhr"

describe "XHR" do
  around :each do |example|
    EM.run{
      example.run
      EM.stop
    }
  end

  describe SockJS::Transports::XHRPost do
    transport_handler_eql "/xhr", "POST"

    describe "#handle(request)" do
      let(:transport) do
        connection = SockJS::Connection.new {}
        session = FakeSession.new({}, :open)
        connection.sessions["b"] = session
        described_class.new(connection, {})
      end

      let(:request) do
        FakeRequest.new.tap do |request|
          request.session_key = Array.new(7) { rand(256) }.pack("C*").unpack("H*").first
          request.path_info = "/xhr"
        end
      end

      let(:response) do
        transport.handle(request)
      end

      context "with a session" do
        let(:request) do
          FakeRequest.new.tap do |request|
            request.path_info = "/xhr"
            request.session_key = "b"
          end
        end

        it "should respond with HTTP 200" do
          response.status.should eql(200)
        end

        it "should respond with plain text MIME type" do
          response.headers["Content-Type"].should match("text/plain")
        end

        it "should run user code" do
          session = transport.connection.sessions["b"]
          session.stub!(:process_buffer).and_return("msg")

          response
        end
      end

      context "without a session" do
        it "should create one and send an opening frame" do
          response # Run the handler.
          response.chunks.last.should eql("o\n")
        end

        it "should respond with HTTP 200" do
          response.status.should eql(200)
        end

        it "should respond with javascript MIME type" do
          response.headers["Content-Type"].should match("application/javascript")
        end

        it "should set access control" do
          response.headers["Access-Control-Allow-Origin"].should eql(request.origin)
          response.headers["Access-Control-Allow-Credentials"].should eql("true")
        end

        it "should set session ID" do
          cookie = response.headers["Set-Cookie"]
          cookie.should match("JSESSIONID=#{request.session_id}; path=/")
        end
      end
    end
  end





  describe SockJS::Transports::XHROptions do
    transport_handler_eql "/xhr", "OPTIONS"

    describe "#handle(request)" do
      let(:transport) do
        described_class.new(Object.new, Hash.new)
      end

      let(:request) do
        FakeRequest.new
      end

      let(:response) do
        transport.handle(request)
      end

      it "should respond with HTTP 204" do
        response.status.should eql(204)
      end

      it "should set access control" do
        response.headers["Access-Control-Allow-Origin"].should eql(request.origin)
        response.headers["Access-Control-Allow-Credentials"].should eql("true")
      end

      it "should set cache control to be valid for the next year" do
        time = Time.now + 31536000

        response.headers["Cache-Control"].should eql("public, max-age=31536000")
        response.headers["Expires"].should eql(time.gmtime.to_s)
        response.headers["Access-Control-Max-Age"].should eql("1000001")
      end

      it "should set Allow header to OPTIONS, POST" do
        response.headers["Allow"].should eql("OPTIONS, POST")
      end
    end
  end





  describe SockJS::Transports::XHRSendPost do
    transport_handler_eql "/xhr_send", "POST"

    describe "#handle(request)" do
      let(:session) do
        FakeSession.new({}, :open)
      end

      let(:transport) do
        connection = SockJS::Connection.new {}
        connection.sessions["b"] = session
        described_class.new(connection, {})
      end

      let(:request) do
        FakeRequest.new.tap do |request|
          request.session_key = rand(1 << 32).to_s
          request.path_info = "/xhr_send"
        end
      end

      let(:response) do
        transport.handle(request)
      end

      context "with a session" do
        let(:request) do
          FakeRequest.new.tap do |request|
            request.path_info = "/xhr_send"
            request.session_key = 'b'
            request.data = '"message"'
          end
        end

        it "should respond with HTTP 204" do
          response.status.should eql(204)
        end

        it "should respond with plain text MIME type" do
          response.headers["Content-Type"].should match("text/plain")
        end

        it "should set session ID" do
          cookie = response.headers["Set-Cookie"]
          cookie.should match("JSESSIONID=#{request.session_id}; path=/")
        end

        it "should set access control" do
          response.headers["Access-Control-Allow-Origin"].should eql(request.origin)
          response.headers["Access-Control-Allow-Credentials"].should eql("true")
        end

        it "should call session.receive_message(request, data)" do
          session.stub!(:receive_message)

          response
        end
      end

      context "without a session" do
        it "should respond with HTTP 404" do
          response.status.should eql(404)
        end

        it "should respond with plain text MIME type" do
          response.headers["Content-Type"].should match("text/plain")
        end

        it "should return error message in the body" do
          response # Run the handler.
          response.chunks.last.should match(/Session is not open\!/)
        end
      end
    end
  end





  describe SockJS::Transports::XHRSendOptions do
    transport_handler_eql "/xhr_send", "OPTIONS"

    describe "#handle(request)" do
      let(:transport) do
        described_class.new(Object.new, Hash.new)
      end

      let(:request) do
        FakeRequest.new
      end

      let(:response) do
        transport.handle(request)
      end

      it "should respond with HTTP 204" do
        response.status.should eql(204)
      end

      it "should set access control" do
        response.headers["Access-Control-Allow-Origin"].should eql(request.origin)
        response.headers["Access-Control-Allow-Credentials"].should eql("true")
      end

      it "should set cache control to be valid for the next year" do
        time = Time.now + 31536000

        response.headers["Cache-Control"].should eql("public, max-age=31536000")
        response.headers["Expires"].should eql(time.gmtime.to_s)
        response.headers["Access-Control-Max-Age"].should eql("1000001")
      end

      it "should set Allow header to OPTIONS, POST" do
        response.headers["Allow"].should eql("OPTIONS, POST")
      end
    end
  end





  describe SockJS::Transports::XHRStreamingPost do
    transport_handler_eql "/xhr_streaming", "POST"

    describe "#handle(request)" do
      let(:transport) do
        connection = SockJS::Connection.new {}
        transport  = described_class.new(connection, Hash.new)

        def transport.try_timer_if_valid(*)
        end

        transport
      end

      let(:request) do
        FakeRequest.new.tap do |request|
          request.path_info = "/a/b/xhr_streaming"
          request.session_key = "b"
        end
      end

      let(:response) do
        transport.handle(request)
      end

      it "should respond with HTTP 200" do
        response.status.should eql(200)
      end

      it "should respond with javascript MIME type" do
        response.headers["Content-Type"].should match("application/javascript")
      end

      it "should set access control" do
        response.headers["Access-Control-Allow-Origin"].should eql(request.origin)
        response.headers["Access-Control-Allow-Credentials"].should eql("true")
      end

      it "should set session ID" do
        cookie = response.headers["Set-Cookie"]
        cookie.should match("JSESSIONID=#{request.session_id}; path=/")
      end
    end
  end





  describe SockJS::Transports::XHRStreamingOptions do
    transport_handler_eql "/xhr_streaming", "OPTIONS"

    describe "#handle(request)" do
      let(:transport) do
        described_class.new(Object.new, Hash.new)
      end

      let(:request) do
        FakeRequest.new
      end

      let(:response) do
        transport.handle(request)
      end

      it "should respond with HTTP 204" do
        response.status.should eql(204)
      end

      it "should set access control" do
        response.headers["Access-Control-Allow-Origin"].should eql(request.origin)
        response.headers["Access-Control-Allow-Credentials"].should eql("true")
      end

      it "should set cache control to be valid for the next year" do
        time = Time.now + 31536000

        response.headers["Cache-Control"].should eql("public, max-age=31536000")
        response.headers["Expires"].should eql(time.gmtime.to_s)
        response.headers["Access-Control-Max-Age"].should eql("1000001")
      end

      it "should set Allow header to OPTIONS, POST" do
        response.headers["Allow"].should eql("OPTIONS, POST")
      end
    end
  end
end
