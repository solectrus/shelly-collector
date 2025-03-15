require 'solectrus_record'

class ShellyResponseParser
  def initialize(json)
    @data = JSON.parse(json)
  end
  attr_reader :data

  def solectrus_record(id: 1, response_duration: nil)
    SolectrusRecord.new(id:, mac:, time:, payload: record_hash.merge(response_duration:))
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

  def mac
    data.dig('sys', 'mac') ||
      data['mac'] ||
      device_status&.dig('mac') ||
      device_status&.dig('sys', 'mac')
  end

  def time
    data['unixtime'] ||
      data.dig('sys', 'unixtime') ||
      device_status['ts'] ||
      Time.now.to_i
  end

  def temp
    (
      data.dig('temperature:0', 'tC') ||
      data.dig('switch:0', 'temperature', 'tC') ||
      device_status&.dig('temperature:0', 'tC') ||
      device_status&.dig('switch:0', 'temperature', 'tC')
    )&.to_f
  end

  def power # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    (
      data['total_power'] ||
      data.dig('pm1:0', 'apower') ||
      data.dig('em:0', 'total_act_power') ||
      data.dig('switch:0', 'apower') ||
      device_status&.dig('em:0', 'total_act_power') ||
      device_status&.dig('switch:0', 'apower') ||
      phases_total
    )&.to_f
  end

  def phases_total
    power_a.to_f + power_b.to_f + power_c.to_f
  end

  def power_a # rubocop:disable Metrics/CyclomaticComplexity
    (
      data.dig('emeters', 0, 'power') ||
      data.dig('meters', 0, 'power') ||
      data.dig('em:0', 'a_act_power') ||
      device_status&.dig('meters', 0, 'power') ||
      device_status&.dig('em:0', 'a_act_power')
    )&.to_f
  end

  def power_b # rubocop:disable Metrics/CyclomaticComplexity
    (
      data.dig('emeters', 1, 'power') ||
      data.dig('meters', 1, 'power') ||
      data.dig('em:0', 'b_act_power') ||
      device_status&.dig('meters', 1, 'power') ||
      device_status&.dig('em:0', 'b_act_power')
    )&.to_f
  end

  def power_c # rubocop:disable Metrics/CyclomaticComplexity
    (
      data.dig('emeters', 2, 'power') ||
      data.dig('meters', 2, 'power') ||
      data.dig('em:0', 'c_act_power') ||
      device_status&.dig('meters', 2, 'power') ||
      device_status&.dig('em:0', 'c_act_power')
    )&.to_f
  end

  def device_status
    data.dig('data', 'device_status')
  end
end
