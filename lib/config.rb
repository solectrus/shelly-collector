require 'shelly_local_adapter'
require 'shelly_cloud_adapter'
require 'blank'
require 'null_logger'

KEYS = %i[
  shelly_host
  shelly_cloud_server
  shelly_device_id
  shelly_auth_key
  shelly_interval
  shelly_invert_power
  shelly_password
  influx_schema
  influx_host
  influx_port
  influx_token
  influx_org
  influx_bucket
  influx_measurement
  influx_mode
  influx_power_data_type
].freeze

DEFAULTS = {
  shelly_interval: 5,
  shelly_invert_power: false,
  influx_schema: :http,
  influx_port: 8086,
  influx_measurement: 'Consumer',
  influx_mode: :default,
  influx_power_data_type: 'Float',
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
    end

    def limit_interval
      minimum = 2

      self[:shelly_interval] = minimum if shelly_interval < minimum
    end

    def validate!
      validate_influx_settings!
      validate_interval!(shelly_interval)
      validate_power_data_type!(influx_power_data_type)
    end

    def influx_url
      "#{influx_schema}://#{influx_host}:#{influx_port}"
    end

    def adapter
      @adapter ||=
        if shelly_cloud_server
          ShellyCloudAdapter.new(config: self)
        else
          ShellyLocalAdapter.new(config: self)
        end
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
      validate_mode!(influx_mode)
    end

    def validate_url!(url)
      uri = URI.parse(url)

      (uri.is_a?(URI::HTTP) && uri.host.present?) || throw("URL is invalid: #{url}")
    end

    def validate_mode!(mode)
      %i[default essential].include?(mode) || throw("INFLUX_MODE is invalid: #{mode}")
    end

    def validate_power_data_type!(data_type)
      %w[Float Integer].include?(data_type) || throw("INFLUX_POWER_DATA_TYPE is invalid: #{data_type}")
    end

    def self.from_env(options = {}) # rubocop:disable Metrics/AbcSize
      new(
        {
          shelly_host: ENV.fetch('SHELLY_HOST', nil),
          shelly_password: ENV.fetch('SHELLY_PASSWORD', nil),
          shelly_cloud_server: ENV.fetch('SHELLY_CLOUD_SERVER', nil),
          shelly_device_id: ENV.fetch('SHELLY_DEVICE_ID', nil),
          shelly_auth_key: ENV.fetch('SHELLY_AUTH_KEY', nil),
          shelly_interval: ENV.fetch('SHELLY_INTERVAL', nil),
          shelly_invert_power: ENV.fetch('SHELLY_INVERT_POWER', nil).to_s&.downcase == 'true',
          influx_host: ENV.fetch('INFLUX_HOST'),
          influx_schema: ENV.fetch('INFLUX_SCHEMA', nil),
          influx_port: ENV.fetch('INFLUX_PORT', nil),
          influx_token: ENV.fetch('INFLUX_TOKEN'),
          influx_org: ENV.fetch('INFLUX_ORG'),
          influx_bucket: ENV.fetch('INFLUX_BUCKET', nil),
          influx_measurement: ENV.fetch('INFLUX_MEASUREMENT', nil),
          influx_mode: ENV.fetch('INFLUX_MODE', nil)&.to_sym,
          influx_power_data_type: ENV.fetch('INFLUX_POWER_DATA_TYPE', nil),
        }.merge(options),
      )
    end
  end
