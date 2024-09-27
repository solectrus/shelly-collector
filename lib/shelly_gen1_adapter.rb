require 'solectrus_record'
require 'forwardable'
require 'faraday'
require 'faraday-request-timer'

class ShellyGen1Adapter
  extend Forwardable
  def_delegators :config, :logger

  def initialize(config:)
    @config = config

    logger.info "Pulling from your Shelly (Gen1) at #{config.shelly_url}#{path} every #{config.shelly_interval} seconds"
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
      power:,
      power_a:,
      power_b:,
      power_c:,
      response_duration:,
    }.compact
  end

  def path
    '/status'
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
      "Power #{record.power} W"
  end

  def failure_message(error)
    "Error getting data from Shelly at #{config.shelly_url}: #{error}"
  end

  def response_duration
    (raw_response.env[:duration] * 1000).round
  end

  def time
    data['unixtime']
  end

  def power
    data['total_power'] || (power_a.to_f + power_b.to_f + power_c.to_f)
  end

  def power_a
    data.dig('emeters', 0, 'power')
  end

  def power_b
    data.dig('emeters', 1, 'power')
  end

  def power_c
    data.dig('emeters', 2, 'power')
  end
end
