require 'solectrus_record'

class ShellyResponseParser
  def initialize(json)
    @data = JSON.parse(json)
  end
  attr_reader :data

  def solectrus_record(id: 1, response_duration: nil)
    SolectrusRecord.new(id:, response_duration:, time:, payload: record_hash)
  end

  private

  def record_hash
    {
      temp:,
      power:,
      power_a:,
      power_b:,
      power_c:,
    }.compact
  end

  def time
    data['unixtime'] ||
      data.dig('sys', 'unixtime') ||
      device_status['ts']
  end

  def temp
    data.dig('temperature:0', 'tC') ||
      data.dig('switch:0', 'temperature', 'tC') ||
      device_status&.dig('temperature:0', 'tC') ||
      device_status&.dig('switch:0', 'temperature', 'tC')
  end

  def power # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    data['total_power'] ||
      data.dig('pm1:0', 'apower') ||
      data.dig('em:0', 'total_act_power') ||
      data.dig('switch:0', 'apower') ||
      device_status&.dig('em:0', 'total_act_power') ||
      device_status&.dig('switch:0', 'apower') ||
      phases_total
  end

  def phases_total
    power_a.to_f + power_b.to_f + power_c.to_f
  end

  def power_a
    data.dig('emeters', 0, 'power') ||
      data.dig('meters', 0, 'power') ||
      data.dig('em:0', 'a_act_power') ||
      device_status&.dig('em:0', 'a_act_power')
  end

  def power_b
    data.dig('emeters', 1, 'power') ||
      data.dig('meters', 1, 'power') ||
      data.dig('em:0', 'b_act_power') ||
      device_status&.dig('em:0', 'b_act_power')
  end

  def power_c
    data.dig('emeters', 2, 'power') ||
      data.dig('meters', 2, 'power') ||
      data.dig('em:0', 'c_act_power') ||
      device_status&.dig('em:0', 'c_act_power')
  end

  def device_status
    data.dig('data', 'device_status')
  end
end
