require 'shelly_adapter'
require 'blank'
require 'null_logger'

KEYS = %i[
  shelly_host
  shelly_interval
  influx_schema
  influx_host
  influx_port
  influx_token
  influx_org
  influx_bucket
  influx_measurement
].freeze

DEFAULTS = {
  influx_schema: :http,
  influx_port: 8086,
  influx_measurement: 'Consumer',
}.freeze

Config =
  Struct.new(*KEYS, keyword_init: true) do
    def initialize(*options)
      super

      set_defaults_and_types
      validate!
    end

    def set_defaults_and_types
      convert_types
      set_defaults
      limit_interval
    end

    def convert_types
      # Strip blanks
      KEYS.each do |key|
        self[key] = self[key].presence
      end

      # Symbols
      %i[influx_schema].each do |key|
        self[key] = self[key]&.to_sym
      end

      # Integer
      %i[shelly_interval influx_port].each do |key|
        self[key] = self[key]&.to_i
      end
    end

    def set_defaults
      DEFAULTS.each do |key, value|
        self[key] ||= value
      end

      self[:shelly_interval] ||= 5
    end

    def limit_interval
      minimum = 5

      self[:shelly_interval] = minimum if shelly_interval < minimum
    end

    def validate!
      validate_influx_settings!
      validate_interval!(shelly_interval)
    end

    def influx_url
      "#{influx_schema}://#{influx_host}:#{influx_port}"
    end

    def shelly_url
      "http://#{shelly_host}"
    end

    def adapter
      @adapter ||=
        ShellyAdapter.new(config: self)
    end

    attr_writer :logger

    def logger
      @logger ||= NullLogger.new
    end

    private

    def validate_interval!(interval)
      (interval.is_a?(Integer) && interval.positive?) || throw("SHELLY_INTERVAL is invalid: #{interval}")
    end

    def validate_influx_settings!
      %i[
        influx_schema
        influx_host
        influx_port
        influx_org
        influx_bucket
        influx_token
        influx_measurement
      ].each do |key|
        self[key].present? || throw("#{key.to_s.upcase} is missing")
      end

      validate_url!(influx_url)
    end

    def validate_url!(url)
      uri = URI.parse(url)

      (uri.is_a?(URI::HTTP) && uri.host.present?) || throw("URL is invalid: #{url}")
    end

    def self.from_env(options = {})
      new(
        {
          shelly_host: ENV.fetch('SHELLY_HOST', nil),
          shelly_interval: ENV.fetch('SHELLY_INTERVAL', nil),
          influx_host: ENV.fetch('INFLUX_HOST'),
          influx_schema: ENV.fetch('INFLUX_SCHEMA', nil),
          influx_port: ENV.fetch('INFLUX_PORT', nil),
          influx_token: ENV.fetch('INFLUX_TOKEN'),
          influx_org: ENV.fetch('INFLUX_ORG'),
          influx_bucket: ENV.fetch('INFLUX_BUCKET', nil),
          influx_measurement: ENV.fetch('INFLUX_MEASUREMENT', nil),
        }.merge(options),
      )
    end
  end
