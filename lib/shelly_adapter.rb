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

  def raw_response
    @raw_response ||= begin
      response = connection.get '/rpc/Shelly.GetStatus'
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
      "Power #{record.power} W, " \
      "Temperature #{record.temp} °C"
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
    data.dig('temperature:0', 'tC') || data.dig('switch:0', 'temperature', 'tC')
  end

  def power
    data.dig('em:0', 'total_act_power') || data.dig('switch:0', 'apower')
  end

  def power_a
    data.dig('em:0', 'a_act_power')
  end

  def power_b
    data.dig('em:0', 'b_act_power')
  end

  def power_c
    data.dig('em:0', 'c_act_power')
  end
end
