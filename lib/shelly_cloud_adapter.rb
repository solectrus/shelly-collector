require 'solectrus_record'
require 'forwardable'
require 'faraday'
require 'faraday-request-timer'

class ShellyCloudAdapter
  extend Forwardable
  def_delegators :config, :logger

  def initialize(config:)
    @config = config

    logger.info "Pulling from Shelly (Cloud) for device #{config.shelly_device_id} every #{config.shelly_interval} seconds"
  end

  attr_reader :config

  def connection
    @connection ||= Faraday.new(url: config.shelly_cloud_server) do |f|
      f.adapter Faraday.default_adapter
      f.request :timer
    end
  end

  def solectrus_record(id = 1)
    # Reset cache
    @data = nil
    @raw_response = nil

    parser = ShellyResponseParser.new(raw_response.body, invert_power: config.shelly_invert_power)
    record = parser.solectrus_record(id:, response_duration:)
    logger.info success_message(record)
    record
  rescue StandardError => e
    logger.error failure_message(e)
    nil
  end

  private

  def raw_response
    @raw_response ||= loop do
      response = connection.get('/device/status') do |req|
        req.params['id'] = config.shelly_device_id
        req.params['auth_key'] = config.shelly_auth_key
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

  def success_message(record)
    "\nGot record ##{record.id} at " \
      "#{Time.at(record.time).localtime} " \
      "within #{record.response_duration} ms, " \
      "Power #{record.power.round(1)} W" +
      (", Temperature #{record.temp} °C" if record.temp).to_s
  end

  def failure_message(error)
    "Error getting data from Shelly at #{config.shelly_host}: #{error}"
  end

  def response_duration
    (raw_response.env[:duration] * 1000).round
  end
end
