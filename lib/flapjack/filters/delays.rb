#!/usr/bin/env ruby

require 'flapjack'

require 'flapjack/data/check_state'
require 'flapjack/filters/base'

module Flapjack
  module Filters

    # * If the service event’s state is a failure, and the time since the last state change
    #   is below a threshold (e.g. 30 seconds), then don't alert
    # * If the service event’s state is a failure, and the time since the last alert is below a
    #   threshold (5 minutes), and the last notification state is the same as the current state, then don’t alert
    #
    # OLD:
    # * If the service event’s state is a failure, and the time since the ok => failure state change
    #   is below a threshold (e.g. 30 seconds), then don't alert
    # * If the service event’s state is a failure, and the time since the last alert is below a
    #   threshold (5 minutes), and the last notification was not a recovery, then don’t alert
    class Delays
      include Base

      def block?(event, check, opts = {})
        initial_failure_delay = check.initial_failure_delay
        if initial_failure_delay.nil? || (initial_failure_delay < 1)
          initial_failure_delay = opts[:initial_failure_delay]
          if initial_failure_delay.nil? || (initial_failure_delay < 1)
            initial_failure_delay = Flapjack::DEFAULT_INITIAL_FAILURE_DELAY
          end
        end

        repeat_failure_delay = check.repeat_failure_delay
        if repeat_failure_delay.nil? || (repeat_failure_delay < 1)
          repeat_failure_delay = opts[:repeat_failure_delay]
          if repeat_failure_delay.nil? || (repeat_failure_delay < 1)
            repeat_failure_delay = Flapjack::DEFAULT_REPEAT_FAILURE_DELAY
          end
        end

        label = 'Filter: Delays:'

        unless event.service? && Flapjack::Data::CheckState.failing_states.include?( event.state )
          @logger.debug("#{label} pass - not a service event in a failure state")
          return false
        end

        unless Flapjack::Data::CheckState.failing_states.include?( check.state )
          @logger.debug("#{label} check is not failing...")
          return false
        end

        last_change        = check.states.last
        last_notif         = check.last_notification

        last_change_time   = last_change  ? last_change.timestamp  : nil
        last_problem_alert = check.last_problem_alert
        last_alert_state   = last_notif.nil? ? nil :
          (last_notif.respond_to?(:state) ? last_notif.state : 'acknowledgement')

        current_time = Time.now
        current_state_duration = last_change_time.nil?   ? nil : (current_time - last_change_time)
        time_since_last_alert  = last_problem_alert.nil? ? nil : (current_time - last_problem_alert)

        @logger.debug("#{label} last_problem_alert: #{last_problem_alert || 'nil'}, " +
                      "last_change: #{last_change_time || 'nil'}, " +
                      "current_state_duration: #{current_state_duration || 'nil'}, " +
                      "time_since_last_alert: #{time_since_last_alert || 'nil'}, " +
                      "last_alert_state: [#{last_alert_state}], " +
                      "event.state: [#{event.state}], " +
                      "last_alert_state == event.state ? #{last_alert_state == event.state}")

        if current_state_duration < initial_failure_delay
          @logger.debug("#{label} block - duration of current failure " +
                     "(#{current_state_duration}) is less than failure_delay (#{initial_failure_delay})")
          return true
        end

        if !(last_problem_alert.nil? || time_since_last_alert.nil?) &&
          (time_since_last_alert < repeat_failure_delay) &&
          (last_alert_state == event.state)

          @logger.debug("#{label} block - time since last alert for " +
                        "current problem (#{time_since_last_alert}) is less than " +
                        "repeat_failure_delay (#{repeat_failure_delay}) and last alert state (#{last_alert_state}) " +
                        "is equal to current event state (#{event.state})")
          return true
        end

        @logger.debug("#{label} pass - not blocking because neither of the time comparison " +
                      "conditions were met")
        return false

      end
    end
  end
end
