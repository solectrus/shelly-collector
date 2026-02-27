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

DeviceConfig = Data.define(:device_id, :host, :password, :measurement, :invert_power, :influx_mode, :influx_power_data_type)

Config =
  Struct.new(*KEYS) do
    def initialize(**options)
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
      validate_device_configs!
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

    def device_configs
      @device_configs ||= build_device_configs
    end

    def multi_device?
      device_configs.size > 1
    end

    def device_config_for(measurement)
      device_configs.find { |dc| dc.measurement == measurement } || device_configs.first
    end

    attr_writer :logger

    def logger
      @logger ||= NullLogger.new
    end

    def log_config
      logger.info "InfluxDB at #{influx_url}, bucket #{influx_bucket}"
      logger.info ''
      mode_label = shelly_cloud_server ? "cloud via #{shelly_cloud_server}" : 'local'
      header = multi_device? ? 'Devices' : 'Device'
      logger.info "#{header} (#{mode_label}, every #{shelly_interval}s):"
      log_device_list
      logger.info ''
    end

    private

    def local_mode?
      shelly_cloud_server.nil?
    end

    def log_device_list
      labels = device_configs.map { |config| device_label(config) }
      max_width = labels.map(&:length).max

      device_configs.each_with_index do |config, idx|
        flags = device_flags(config)
        suffix = flags.any? ? " (#{flags.join(', ')})" : ''
        logger.info "  #{labels[idx].ljust(max_width)} => #{config.measurement}#{suffix}"
      end
    end

    def device_label(device_config)
      device_config.host ? "http://#{device_config.host}" : device_config.device_id
    end

    def device_flags(device_config)
      flags = []
      flags << 'inverted' if device_config.invert_power
      flags << (device_config.password.present? ? 'auth' : 'no auth') if device_config.host
      flags << device_config.influx_mode.to_s if device_config.influx_mode != :default
      flags << device_config.influx_power_data_type if device_config.influx_power_data_type != 'Float'
      flags
    end

    def primary_device_keys
      local_mode? ? parse_csv(shelly_host) : parse_csv(shelly_device_id)
    end

    def build_device_configs
      keys = primary_device_keys

      per_device_options(keys).map do |(key, measurement, password, invert, mode, data_type)|
        DeviceConfig.new(
          device_id: local_mode? ? nil : key,
          host: local_mode? ? key : nil,
          password:, measurement:, invert_power: invert,
          influx_mode: mode, influx_power_data_type: data_type,
        )
      end
    end

    def per_device_options(keys)
      count = keys.size

      keys.zip(
        parse_csv(influx_measurement),
        local_mode? ? parse_per_device(shelly_password, count, default: nil, &:presence) : Array.new(count),
        parse_per_device(shelly_invert_power, count, default: false) { |v| v.downcase == 'true' },
        parse_per_device(influx_mode, count, default: :default, &:to_sym),
        parse_per_device(influx_power_data_type, count, default: 'Float'),
      )
    end

    def parse_csv(value)
      return [] if value.nil? || value == false

      value.to_s.split(',').map(&:strip)
    end

    def parse_per_device(raw, count, default:)
      return Array.new(count, default) if raw.nil? || raw == default

      values = raw.to_s.split(',', -1).map { |v| block_given? ? yield(v.strip) : v.strip }
      values.size == 1 ? Array.new(count, values.first) : values
    end

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

    def validate_device_configs!
      throw('Cannot use both SHELLY_HOST and SHELLY_CLOUD_SERVER') if shelly_host.present? && shelly_cloud_server.present?

      keys = primary_device_keys
      return if keys.size <= 1

      validate_multi_device_counts!(keys)
      validate_csv_count!('SHELLY_INVERT_POWER', shelly_invert_power, keys)
      validate_csv_count!('INFLUX_MODE', influx_mode, keys)
      validate_csv_count!('INFLUX_POWER_DATA_TYPE', influx_power_data_type, keys)
      validate_csv_count!('SHELLY_PASSWORD', shelly_password, keys) if local_mode?
    end

    def primary_key_name
      local_mode? ? 'SHELLY_HOST' : 'SHELLY_DEVICE_ID'
    end

    def validate_multi_device_counts!(keys)
      measurements = parse_csv(influx_measurement)
      return if keys.size == measurements.size

      throw("#{primary_key_name} count (#{keys.size}) must match INFLUX_MEASUREMENT count (#{measurements.size})")
    end

    def validate_csv_count!(name, raw, keys)
      return if raw.nil? || raw.is_a?(Symbol) || raw == false

      count = raw.to_s.split(',', -1).size
      return if count == 1 || count == keys.size

      throw("#{name} count (#{count}) must match #{primary_key_name} count (#{keys.size}) or be a single value")
    end

    def validate_url!(url)
      uri = URI.parse(url)

      (uri.is_a?(URI::HTTP) && uri.host.present?) || throw("URL is invalid: #{url}")
    end

    def validate_mode!(mode)
      values = mode.is_a?(Symbol) ? [mode] : mode.to_s.split(',').map { |v| v.strip.to_sym }
      values.each do |v|
        %i[default essential].include?(v) || throw("INFLUX_MODE is invalid: #{v}")
      end
    end

    def validate_power_data_type!(data_type)
      data_type.to_s.split(',').map(&:strip).each do |v|
        %w[Float Integer].include?(v) || throw("INFLUX_POWER_DATA_TYPE is invalid: #{v}")
      end
    end

    def self.from_env(**)
      new(
        shelly_host: ENV.fetch('SHELLY_HOST', nil),
        shelly_password: ENV.fetch('SHELLY_PASSWORD', nil),
        shelly_cloud_server: ENV.fetch('SHELLY_CLOUD_SERVER', nil),
        shelly_device_id: ENV.fetch('SHELLY_DEVICE_ID', nil),
        shelly_auth_key: ENV.fetch('SHELLY_AUTH_KEY', nil),
        shelly_interval: ENV.fetch('SHELLY_INTERVAL', nil),
        shelly_invert_power: ENV.fetch('SHELLY_INVERT_POWER', nil),
        influx_host: ENV.fetch('INFLUX_HOST'),
        influx_schema: ENV.fetch('INFLUX_SCHEMA', nil),
        influx_port: ENV.fetch('INFLUX_PORT', nil),
        influx_token: ENV.fetch('INFLUX_TOKEN'),
        influx_org: ENV.fetch('INFLUX_ORG'),
        influx_bucket: ENV.fetch('INFLUX_BUCKET', nil),
        influx_measurement: ENV.fetch('INFLUX_MEASUREMENT', nil),
        influx_mode: ENV.fetch('INFLUX_MODE', nil),
        influx_power_data_type: ENV.fetch('INFLUX_POWER_DATA_TYPE', nil),
        **,
      )
    end
  end
