require 'solectrus_record'
require 'forwardable'
require 'faraday'
require 'faraday-request-timer'

class ShellyGen3Adapter
  extend Forwardable
  def_delegators :config, :logger

  def initialize(config:)
    @config = config

    logger.info "Pulling from your Shelly (Gen3) at #{config.shelly_url}#{path} every #{config.shelly_interval} seconds"
  end

  attr_reader :config

  def connection
    @connection ||= Faraday.new(url: config.shelly_url) do |f|
      f.adapter Faraday.default_adapter
      f.request :timer
    end
  end

  def solectrus_record(id = 1)
    # Reset cache
    @data = nil
    @raw_response = nil

    SolectrusRecord.new(id:, time:, payload: record_hash).tap do |record|
      logger.info success_message(record)
    end
  rescue StandardError => e
    logger.error failure_message(e)
    nil
  end

  private

  def record_hash
    {
      temp:,
      power:,
      power_a:,
      power_b:,
      power_c:,
      response_duration:,
    }.compact
  end

  def path
    '/rpc/Shelly.GetStatus'
  end

  def raw_response
    @raw_response ||= begin
      response = connection.get(path)
      raise StandardError, response.status unless response.success?

      response
    end
  end

  def data
    @data ||= JSON.parse(raw_response.body)
  end

  def success_message(record)
    "\nGot record ##{record.id} at " \
      "#{Time.at(record.time).localtime} " \
      "within #{record.response_duration} ms, " \
      "Power #{record.power.round(1)} W "
  end

  def failure_message(error)
    "Error getting data from Shelly at #{config.shelly_url}: #{error}"
  end

  def response_duration
    (raw_response.env[:duration] * 1000).round
  end

  def time
    data.dig('sys', 'unixtime')
  end

  def temp
    # does not exist in Shelly PM Mini Gen. 3
  end

  def power
    data.dig('pm1:0', 'apower')
  end

  def power_a
    # does not exist in Shelly PM Mini Gen. 3
  end

  def power_b
    # does not exist in Shelly PM Mini Gen. 3
  end

  def power_c
    # does not exist in Shelly PM Mini Gen. 3
  end
end
