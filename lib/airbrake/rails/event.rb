# frozen_string_literal: true

module Airbrake
  module Rails
    # Event is a wrapper around ActiveSupport::Notifications::Event.
    #
    # @since v9.0.3
    # @api private
    class Event
      # @see https://github.com/rails/rails/issues/8987
      HTML_RESPONSE_WILDCARD = "*/*"

      # @return [Integer]
      MILLISECOND = 1000

      include Airbrake::Loggable

      def initialize(*args)
        @event = ::ActiveSupport::Notifications::Event.new(*args)
      end

      def method
        @event.payload[:method]
      end

      def response_type
        response_type = @event.payload[:format]
        response_type == HTML_RESPONSE_WILDCARD ? :html : response_type
      end

      def params
        @event.payload[:params]
      end

      def sql
        @event.payload[:sql]
      end

      def db_runtime
        @db_runtime ||= @event.payload[:db_runtime] || 0
      end

      def view_runtime
        @view_runtime ||= @event.payload[:view_runtime] || 0
      end

      def time
        # On Rails 7+ `ActiveSupport::Notifications::Event#time` returns an
        # instance of Float. It represents monotonic time in milliseconds.
        # Airbrake Ruby expects that the provided time is in seconds. Hence,
        # we need to convert it from milliseconds to seconds. In the
        # versions below Rails 7, time is an instance of Time.
        #
        # Relevant commit:
        # https://github.com/rails/rails/commit/81d0dc90becfe0b8e7f7f26beb66c25d84b8ec7f
        #
        # Ensure this conversion is applied exclusively for Rails 7.0
        return @event.time / MILLISECOND if rails_7_0?

        @event.time
      end

      def groups
        groups = {}
        groups[:db] = db_runtime if db_runtime > 0
        groups[:view] = view_runtime if view_runtime > 0
        groups
      end

      def status_code
        return @event.payload[:status] if @event.payload[:status]

        if @event.payload[:exception]
          status = ::ActionDispatch::ExceptionWrapper.status_code_for_exception(
            @event.payload[:exception].first,
          )
          status = 500 if status == 0

          return status
        end

        # The ActiveSupport event doesn't have status only in two cases:
        #   - an exception was thrown
        #   - unauthorized access
        # We have already handled the exception so what's left is unauthorized
        # access. There's no way to know for sure it's unauthorized access, so
        # we are rather optimistic here.
        401
      end

      def duration
        @event.duration
      end

      def rails_7_0?
        ::Rails::VERSION::MAJOR == 7 && ::Rails::VERSION::MINOR == 0
      end
    end
  end
end
