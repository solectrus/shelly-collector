require 'shelly_response_parser'
require 'solectrus_record'
require 'batch_formatting'
require 'forwardable'
require 'faraday'
require 'faraday-request-timer'
require 'digest_auth'

class ShellyLocalAdapter
  extend Forwardable
  include BatchFormatting

  def_delegators :config, :logger

  GEN1_PATH = '/status'.freeze
  GEN2_PATH = '/rpc/Shelly.GetStatus'.freeze

  TIMEOUT = 10

  DeviceError = Data.define(:host, :message)

  def initialize(config:)
    @config = config
    @mutex = Mutex.new
    @paths = {}
    @connections = {}
  end

  attr_reader :config

  def solectrus_records(id = 1)
    logger.info ''

    @last_records, @last_errors = fetch_all_devices(id)
    @last_records
  end

  def log_batch_results(id, skipped_measurements: [])
    records = @last_records || []
    errors = @last_errors || []
    return unless records.any? || errors.any?

    widths = column_widths(records).merge(host: max_host_width)
    log_device_results(id, records, widths, skipped_measurements)
    errors.each { |e| logger.error error_summary(e, widths[:host]) }
  end

  def solectrus_record(id = 1)
    solectrus_records(id).first
  end

  private

  def fetch_all_devices(id)
    threads = config.device_configs.map do |device_config|
      Thread.new { fetch_device(device_config, id) }
    end

    results = threads.map(&:value)
    [results.grep(SolectrusRecord), results.grep(DeviceError)]
  end

  def fetch_device(device_config, id)
    response = fetch_response(device_config)
    duration = (response.env[:duration] * 1000).round
    parser = ShellyResponseParser.new(response.body, invert_power: device_config.invert_power)
    parser.solectrus_record(id:, response_duration: duration, measurement: device_config.measurement)
  rescue StandardError => e
    DeviceError.new(host: device_config.host, message: e.to_s)
  end

  def fetch_response(device_config)
    connection = connection_for(device_config)
    path = path_for(device_config, connection)
    response = connection.get(path)
    unless response.success?
      hint = response.status == 401 ? ' (password missing or wrong?)' : ''
      raise StandardError, "HTTP #{response.status}#{hint}"
    end

    response
  end

  def connection_for(device_config)
    @mutex.synchronize do
      @connections[device_config.host] ||= build_connection(device_config)
    end
  end

  def build_connection(device_config)
    url = "http://#{device_config.host}"
    Faraday.new(url:) do |f|
      f.adapter Faraday.default_adapter
      f.options.timeout = TIMEOUT
      f.options.open_timeout = TIMEOUT

      if device_config.password.present?
        f.request :digest_auth,
                  username: 'admin',
                  password: device_config.password
      end

      f.request :timer
    end
  end

  def path_for(device_config, connection)
    cached = @mutex.synchronize { @paths[device_config.host] }
    return cached if cached

    path = probe_path(device_config, connection)
    @mutex.synchronize { @paths[device_config.host] = path }
    path
  end

  def probe_path(device_config, connection)
    if can_connect_to?(connection, GEN1_PATH)
      GEN1_PATH
    elsif can_connect_to?(connection, GEN2_PATH)
      GEN2_PATH
    else
      raise StandardError,
            "Device at #{device_config.host} does not respond to #{GEN1_PATH} or #{GEN2_PATH}"
    end
  end

  def can_connect_to?(connection, path)
    result = connection.get(path)
    result.success? || result.status == 401
  rescue StandardError
    false
  end

  def log_device_results(id, records, widths, skipped_measurements)
    return unless records.any?

    if config.multi_device?
      log_records(id, records, widths, skipped_measurements)
    else
      log_single_record(id, records.first, widths, skipped: skipped_measurements.include?(records.first.measurement))
    end
  end

  def log_records(id, records, widths, skipped_measurements)
    logger.info "##{id} - Got #{records.size} records:"
    records.each { |r| log_record_line(r, widths, skipped: skipped_measurements.include?(r.measurement)) }
  end

  def log_single_record(id, record, widths, skipped:)
    line = "##{id} - #{format_values(record, widths)} #{format_duration(record, widths)}"
    if skipped
      logger.info "#{line} [skipped]"
    else
      logger.success line
    end
  end

  def log_record_line(record, widths, skipped:)
    line = device_summary(record, widths)
    if skipped
      logger.info "#{line} [skipped]"
    else
      logger.success line
    end
  end

  def max_host_width
    config.device_configs.map { |dc| "http://#{dc.host}".length }.max
  end

  def column_widths(records)
    {
      power: max_field_length(records) { |r| r.power.round(1).to_s },
      temp: max_field_length(records) { |r| r.temp&.to_s },
      duration: max_field_length(records) { |r| r.response_duration.to_s },
    }
  end

  def host_url(record)
    "http://#{config.device_config_for(record.measurement).host}"
  end

  def device_summary(record, widths)
    host = host_url(record).ljust(widths[:host])
    "  #{host}: #{format_values(record, widths)} #{format_duration(record, widths)}"
  end

  def error_summary(error, host_width)
    host = "http://#{error.host}".ljust(host_width)
    "  #{host}: Error, #{error.message}"
  end

  def format_duration(record, widths)
    "(#{record.response_duration.to_s.rjust(widths[:duration])} ms)"
  end
end
