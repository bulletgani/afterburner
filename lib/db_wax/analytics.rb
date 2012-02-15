require 'resque'

module Analytics
  MAX_ANALYTICS_DATA_FIELDS = 12

  def self.included(base)
    base.send(:cattr_accessor, :analytics)
    base.instance_eval do
      self.analytics = AnalyticsHelper.new(self)
    end
  end

  class AnalyticsHelper

    attr_accessor :handler

    def initialize(handler)
      @handler = handler
    end

    def method_missing(m, *args, &block)
      data = args.first.is_a?(Hash) ? args.first : {}
      user = ApiResponse.current.current_user if ApiResponse.current
      data.merge!('user_id' => user ? user.id : data['user_id'])
      data.merge!('event_id' => m.to_s)
      data.merge!('platform' => 'FB')
      source = data['src'] || data['ref'] || 'unknown'
      data.merge!('src' => source) if source
      Analytics::VeerWorker.new.record(data)
      ::Rails.logger.debug "ANALYTICS #{m} #{data.inspect}"
    end

  end

  class AbstractWorker

    class << self;
      attr_accessor :required_fields, :all_data;
    end

    def initialize()
      @system_time = DateTime.now
      @required_fields = []
      @optional_fields = []
      @defaults = {}
      @method = 'unknown'
    end

    def all_fields
      @required_fields + @optional_fields
    end

    def record(data)

      data = @defaults.merge(data)
      data.stringify_keys!

      event_id = data['event_id']

      @required_fields.each do |required|
        unless data.has_key?(required.to_s)
          ::Rails.logger.warn "Missing required parameter #{required}; stats not sent."
          return
        end
      end

      send_data = {
          'product' => "veer_#{::Rails.env}",
          'platform' => 'FB',
          'method' => @method,
          'system_time' => @system_time,
      }.merge(data)

      #all_fields.each do |var|
      #  if data.has_key?(var)
      #    ::Rails.logger.debug " Stats data: #{ var }: #{ data[var] }"
      #    send_data[var.to_s] = data.delete(var)
      #  end
      #end

      #::Rails.logger.warn "ANALYTICS IMPORTANT: #{event_id} Remaining (not logged) parameters: #{data.inspect}" unless data=={}

      x = ::Analytics.rearrange_data(send_data)
      begin
        Resque.enqueue(self.class, x);
      rescue Exception => e
        ::Rails.logger.warn e.message
        ::Rails.logger.warn "Unable to connect to Redis; stats not recorded."
      end

    end

    def self.perform(data)
      begin
        nil #TODO
      rescue Timeout::Error => e
        begin
          ::Rails.logger.warn e.message
          ::Rails.logger.warn "RESQUE-Trying to re-enqueue timed out task."
          Resque.enqueue(Analytics::Worker, data);
        rescue Exception => e2
          ::Rails.logger.warn e2.message
          ::Rails.logger.warn "RESQUE-Unable to re-enqueue; stats not recorded."
        end
      rescue Exception => e3
        ::Rails.logger.warn e3.message
        ::Rails.logger.warn "RESQUE-Unable to execute task; stats not recorded."
      end
    end

  end

  class VeerWorker < AbstractWorker
    @queue = :analytics

    def initialize
      super
      @required_fields = %w(platform user_id event_id)
      @optional_fields = %w(source_user_id target_user_id x y fip_id from to)
      #FIXME is optional_fields necessary, now that we have analytics.yml?
      @defaults = {
          'platform' => 'FB'
      }
      @method = 'recordEvent'
    end

  end

  REQUIRED_KEYS = %w(product platform event_id system_time user_id)

  # discard any keys not mentioned in config/analytics.yml
  # return an ordered list, length no greater than MAX_ANALYTICS_DATA_FIELDS
  # if there is more data than that, the last data will all be packed into the last db field as a json blob
  def self.rearrange_data(data)
    event_id = data['event_id']
    event_config = event_data_conf[event_id]
    unless event_config
      ::Rails.logger.debug "ANALYTICS No event config for #{event_id} ... add it!"
      return []
    end
    ordered_keys = event_config['data']
    ordered_keys = ordered_keys.blank? ? REQUIRED_KEYS : (REQUIRED_KEYS + ordered_keys)
    ordered_values = ordered_keys.collect { |k| data[k] }
    # if keys are too many to fit one-to-one in sql fields...
    if ordered_values.length > MAX_ANALYTICS_DATA_FIELDS
      # squish last few into a json blob
      num_to_leave_alone = MAX_ANALYTICS_DATA_FIELDS-1
      keys_to_squish = ordered_keys[num_to_leave_alone..-1]
      ordered_values = ordered_values[0...num_to_leave_alone]
      squished_hash = keys_to_squish.inject({}) { |h, k| h[k] = data[k] }
      ordered_values[num_to_leave_alone] = squished_hash.to_json
    end
    ordered_values
  end

  def self.priority_of(event_id)
    event_data_conf[event_id]['priority']
  end

  def self.event_data_conf
    @event_data_conf ||= YAML.load(
        File.read(
            File.join(
                ::Rails.root, 'config', 'analytics.yml'
            )))
    @event_data_conf
  end

end
