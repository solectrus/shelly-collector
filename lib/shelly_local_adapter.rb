require 'shelly_response_parser'
require 'solectrus_record'

require 'forwardable'
require 'faraday'
require 'faraday-request-timer'
require 'digest_auth'

class ShellyLocalAdapter
  extend Forwardable
  def_delegators :config, :logger

  GEN1_PATH = '/status'.freeze
  GEN2_PATH = '/rpc/Shelly.GetStatus'.freeze

  def initialize(config:)
    @config = config

    logger.info "Pulling from your Shelly at #{shelly_url} every #{config.shelly_interval} seconds"
  end

  attr_reader :config

  def connection
    @connection ||= Faraday.new(url: shelly_url) do |f|
      f.adapter Faraday.default_adapter

      if config.shelly_password.present?
        f.request :digest_auth,
                  username: 'admin',
                  password: config.shelly_password
      end

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

  def raw_response
    @raw_response ||= begin
      response = connection.get(path)
      raise StandardError, response.status unless response.success?

      response
    end
  end

  def shelly_url
    "http://#{config.shelly_host}"
  end

  def path
    @path ||=
      if can_connect_to?(GEN1_PATH)
        GEN1_PATH
      elsif can_connect_to?(GEN2_PATH)
        GEN2_PATH
      else
        raise StandardError,
              "The device at #{shelly_url} does not not respond to #{GEN1_PATH} or #{GEN2_PATH}"
      end
  end

  def can_connect_to?(path)
    result = connection.get(path)
    result.success? || result.status == 401
  rescue StandardError
    false
  end

  def success_message(record)
    "\nGot record ##{record.id} at " \
      "#{Time.at(record.time).localtime} " \
      "within #{record.response_duration} ms, " \
      "Power #{record.power.round(1)} W" +
      (", Temperature #{record.temp} °C" if record.temp).to_s
  end

  def failure_message(error)
    "Error getting data from Shelly at #{shelly_url}: #{error}"
  end

  def response_duration
    (raw_response.env[:duration] * 1000).round
  end
end
