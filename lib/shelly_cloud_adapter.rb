require 'shelly_response_parser'
require 'solectrus_record'
require 'batch_formatting'
require 'forwardable'
require 'faraday'
require 'faraday-request-timer'
require 'json'

class ShellyCloudAdapter
  extend Forwardable
  include BatchFormatting

  def_delegators :config, :logger

  BATCH_SIZE = 10

  # The Shelly Cloud reports a device as online while still serving the last
  # cached status. If that status is older than this, the device has stopped
  # reporting (lost connection): skip it instead of writing a stale value with
  # the current timestamp. Generous on purpose - healthy devices report only on
  # change and may legitimately stay quiet for a while.
  STALE_AFTER = 5 * 60 # seconds

  def initialize(config:)
    @config = config
  end

  attr_reader :config

  def connection
    @connection ||= Faraday.new(url: config.shelly_cloud_server) do |f|
      f.adapter Faraday.default_adapter
      f.request :timer
    end
  end

  def solectrus_records(id = 1)
    logger.info ''
    @last_records = config.multi_device? ? fetch_multi(id) : fetch_single(id)
  rescue StandardError => e
    logger.error failure_message(e)
    @last_records = []
  end

  def log_batch_results(id, skipped_measurements: [])
    records = @last_records || []
    return unless records.any?

    widths = column_widths(records)
    if config.multi_device?
      log_records(id, records, widths, skipped_measurements)
    else
      log_single_record(id, records.first, widths, skipped: skipped_measurements.include?(records.first.measurement))
    end
  end

  def solectrus_record(id = 1)
    solectrus_records(id).first
  end

  private

  # V1 API - single device
  def fetch_single(id)
    device_config = config.device_configs.first
    response = fetch_v1(device_config)
    return [] if offline_v1?(response, device_config)

    duration = (response.env[:duration] * 1000).round
    parser = ShellyResponseParser.new(response.body, invert_power: device_config.invert_power)
    record = parser.solectrus_record(id:, response_duration: duration, measurement: device_config.measurement)
    fresh?(record, device_config) ? [record] : []
  end

  # Only skip on an explicit `online: false` - responses without the flag
  # should not be discarded.
  def offline_v1?(response, device_config)
    return false unless JSON.parse(response.body).dig('data', 'online') == false

    logger.warn "Device #{device_config.device_id} is offline"
    true
  end

  def fetch_v1(device_config)
    loop do
      response = connection.get('/device/status') do |req|
        req.params['id'] = device_config.device_id
        req.params['auth_key'] = config.shelly_auth_key
      end
      break response if response.success?

      handle_error_response(response)
    end
  end

  # V2 API - multiple devices
  def fetch_multi(id)
    batches = config.device_configs.each_slice(BATCH_SIZE).to_a

    records = batches.each_with_index.flat_map do |batch, index|
      sleep(1) if index.positive?
      fetch_and_parse_batch(batch, id)
    end

    records.compact
  end

  def fetch_and_parse_batch(batch, id)
    response = fetch_v2(batch)
    duration = (response.env[:duration] * 1000).round
    body = JSON.parse(response.body)

    batch.filter_map do |device_config|
      parse_device_response(body, device_config, id, duration)
    end
  end

  def parse_device_response(body, device_config, id, duration)
    device_data = find_online_device(body, device_config)
    return unless device_data

    parser = ShellyResponseParser.new(
      device_data['status'].to_json,
      invert_power: device_config.invert_power,
    )
    record = parser.solectrus_record(id:, response_duration: duration, measurement: device_config.measurement)
    record if fresh?(record, device_config)
  end

  def find_online_device(body, device_config)
    device_data = body.find { |d| d['id'] == device_config.device_id }

    if device_data.nil?
      logger.warn "Device #{device_config.device_id} not found in batch response"
      return nil
    end

    unless device_data['online'] == 1
      logger.warn "Device #{device_config.device_id} is offline"
      return nil
    end

    device_data
  end

  # Reject records whose data is older than STALE_AFTER. The cloud can report a
  # device as online while serving a cached status from hours ago; writing that
  # value with the collection timestamp would fabricate data. Without a device
  # timestamp the age is unknown - accept the record.
  def fresh?(record, device_config)
    return true unless record.device_time

    age = record.time - record.device_time
    return true if age <= STALE_AFTER

    logger.warn "Device #{device_config.device_id} data is stale (#{age}s old), skipping"
    false
  end

  def fetch_v2(batch)
    device_ids = batch.map(&:device_id)

    loop do
      response = connection.post('/v2/devices/api/get') do |req|
        req.params['auth_key'] = config.shelly_auth_key
        req.headers['Content-Type'] = 'application/json'
        req.body = { ids: device_ids, select: ['status'] }.to_json
      end
      break response if response.success?

      handle_error_response(response)
    end
  end

  def handle_error_response(response)
    case response.status
    when 429
      wait_time = rand(10..30)
      logger.warn "Rate limit hit (429), waiting #{wait_time} seconds before retry..."
      sleep(wait_time)
    else
      raise StandardError, response.status
    end
  end

  def log_records(id, records, widths, skipped_measurements)
    logger.info "##{id} - Got #{records.size} records:"
    records.each { |r| log_record_line(r, widths, skipped: skipped_measurements.include?(r.measurement)) }
  end

  def log_single_record(id, record, widths, skipped:)
    line = "##{id} - #{format_values(record, widths)}"
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

  def column_widths(records)
    {
      device_id: max_field_length(records) { |r| device_id_for(r) },
      power: max_field_length(records) { |r| r.power.round(1).to_s },
      temp: max_field_length(records) { |r| r.temp&.to_s },
    }
  end

  def device_id_for(record)
    config.device_config_for(record.measurement).device_id
  end

  def device_summary(record, widths)
    device_id = device_id_for(record).ljust(widths[:device_id])
    "  #{device_id}: #{format_values(record, widths)}"
  end

  def failure_message(error)
    "Error getting data from Shelly Cloud: #{error}"
  end
end
