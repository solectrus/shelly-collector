require 'solectrus_record'

class ShellyResponseParser
  def initialize(json, invert_power: false)
    @data = JSON.parse(json)
    @invert_power = invert_power
  end
  attr_reader :data, :invert_power

  def solectrus_record(id: 1, response_duration: nil, measurement: nil)
    SolectrusRecord.new(
      id:,
      mac:,
      time: Time.now.to_i,
      device_time:,
      payload: record_hash.merge(response_duration:),
      measurement:,
    )
  end

  private

  def record_hash
    {
      temp:,
      power:,
      power_a:,
      power_b:,
      power_c:,
      power_d:,
    }.compact
  end

  def mac
    data.dig('sys', 'mac') ||
      data['mac'] ||
      device_status&.dig('mac') ||
      device_status&.dig('sys', 'mac')
  end

  # When the device (or cloud cache) last reported. Only used for staleness
  # detection - the record's point time is the collection time. May be nil
  # when the response carries no usable timestamp. Gen1 devices without NTP
  # sync report unixtime 0 - treat that as missing, not as 1970.
  def device_time
    [
      cloud_timestamp,
      data['unixtime'],
      data.dig('sys', 'unixtime'),
      device_status&.dig('sys', 'unixtime'),
    ].compact.map(&:to_i).find(&:positive?)
  end

  # The cloud-side status timestamp (`ts`) reflects when the device last
  # reported to the cloud. It is fresher than the device's `sys.unixtime`,
  # which lives in a separate sub-object and only refreshes on a full status
  # update - on partial updates it can lag many minutes behind. Prefer `ts`
  # so V1 (device_status.ts) and V2 (root ts) use the same, freshest source.
  def cloud_timestamp
    data['ts'] || device_status&.[]('ts')
  end

  def temp
    (
      data.dig('temperature:0', 'tC') ||
      data.dig('switch:0', 'temperature', 'tC') ||
      device_status&.dig('temperature:0', 'tC') ||
      device_status&.dig('switch:0', 'temperature', 'tC')
    )&.to_f
  end

  def raw_power_value
    data['total_power'] ||
      data.dig('pm1:0', 'apower') ||
      data.dig('em:0', 'total_act_power') ||
      device_status&.dig('em:0', 'total_act_power') ||
      phases_total
  end

  def power
    raw = raw_power_value&.to_f
    raw && invert_power ? -raw : raw
  end

  def phases_total
    power_a.to_f + power_b.to_f + power_c.to_f + power_d.to_f
  end

  def power_a # rubocop:disable Metrics/CyclomaticComplexity,Metrics/AbcSize,Metrics/PerceivedComplexity
    (
      data.dig('emeters', 0, 'power') ||
      data.dig('meters', 0, 'power') ||
      data.dig('em:0', 'a_act_power') ||
      data.dig('em1:0', 'act_power') ||
      data.dig('switch:0', 'apower') ||
      device_status&.dig('meters', 0, 'power') ||
      device_status&.dig('em:0', 'a_act_power') ||
      device_status&.dig('em1:0', 'act_power') ||
      device_status&.dig('switch:0', 'apower')
    )&.to_f
  end

  def power_b # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/AbcSize
    (
      data.dig('emeters', 1, 'power') ||
      data.dig('meters', 1, 'power') ||
      data.dig('em:0', 'b_act_power') ||
      data.dig('em1:1', 'act_power') ||
      data.dig('switch:1', 'apower') ||
      device_status&.dig('meters', 1, 'power') ||
      device_status&.dig('em:0', 'b_act_power') ||
      device_status&.dig('em1:1', 'act_power') ||
      device_status&.dig('switch:1', 'apower')
    )&.to_f
  end

  def power_c # rubocop:disable Metrics/CyclomaticComplexity,Metrics/AbcSize,Metrics/PerceivedComplexity
    (
      data.dig('emeters', 2, 'power') ||
      data.dig('meters', 2, 'power') ||
      data.dig('em:0', 'c_act_power') ||
      data.dig('switch:2', 'apower') ||
      device_status&.dig('meters', 2, 'power') ||
      device_status&.dig('em:0', 'c_act_power') ||
      device_status&.dig('switch:2', 'apower')
    )&.to_f
  end

  def power_d
    (
      data.dig('switch:3', 'apower') ||
      device_status&.dig('switch:3', 'apower')
    )&.to_f
  end

  def device_status
    data.dig('data', 'device_status')
  end
end
