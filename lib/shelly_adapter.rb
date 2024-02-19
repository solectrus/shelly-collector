require 'solectrus_record'
require 'forwardable'
require 'faraday'
require 'faraday-request-timer'

class ShellyAdapter
  extend Forwardable
  def_delegators :config, :logger

  def initialize(config:)
    @config = config

    logger.info "Pulling from your Shelly at #{config.shelly_url} every #{config.shelly_interval} seconds"
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

    SolectrusRecord.new(id, record_hash).tap do |record|
      logger.info success_message(record)
    end
  rescue StandardError => e
    logger.error failure_message(e)
    nil
  end

  private

  def record_hash
    {
      measure_time:,
      temp:,
      power:,
      response_duration:,
    }
  end

  def raw_response
    @raw_response ||= begin
      response = connection.get '/rpc/Shelly.GetStatus'
      raise Error, response.status unless response.success?

      response
    end
  end

  def data
    @data ||= JSON.parse(raw_response.body)
  end

  def success_message(record)
    "\nGot record ##{record.id} at " \
      "#{Time.at(record.measure_time).localtime} " \
      "within #{record.response_duration} ms, " \
      "Power #{record.power} W, " \
      "Temperature #{record.temp} °C"
  end

  def failure_message(error)
    "Error getting data from Shelly at #{config.shelly_url}: #{error}"
  end

  def response_duration
    (raw_response.env[:duration] * 1000).round
  end

  def measure_time
    data.dig('sys', 'unixtime')
  end

  def temp
    data.dig('temperature:0', 'tC')
  end

  def power
    data.dig('em:0', 'total_act_power')
  end
end
