require 'faraday'
require 'faraday/net_http_persistent'

class FluxWriter
  def initialize(config)
    @config = config
  end

  attr_reader :config

  def ready?
    connection.get('/ping').success?
  rescue Faraday::Error
    false
  end

  def push(record)
    return unless record

    connection.post(write_path) do |req|
      req.headers['Content-Type'] = 'text/plain'
      req.body = line_protocol(record)
    end
  end

  private

  def line_protocol(record)
    fields = build_fields(record)
    measurement = record.measurement || config.influx_measurement
    # record.time is the collection time, stamped when the record was created.
    # This must NOT be replaced by Time.now: records can sit in the queue for a
    # while (InfluxDB outage, retries), and stamping at write time would collapse
    # the whole backlog onto one timestamp. The device timestamp (device_time) is
    # never written either - the Shelly Cloud serves cached status that can be
    # minutes to hours old, which would repeatedly overwrite the same point.
    "#{measurement} #{format_fields(fields)} #{record.time}"
  end

  def build_fields(record)
    fields = record.to_hash

    # Convert power fields to integers if configured (per-device or global)
    if config.device_config_for(record.measurement).influx_power_data_type == 'Integer'
      fields.each do |key, value|
        next unless key.to_s.start_with?('power') && value.is_a?(Numeric)

        fields[key] = value.round
      end
    end

    fields
  end

  def format_fields(fields)
    fields.map { |k, v| "#{k}=#{format_value(v)}" }.join(',')
  end

  def format_value(value)
    value.is_a?(Integer) ? "#{value}i" : value.to_s
  end

  def write_path
    "/api/v2/write?#{URI.encode_www_form(bucket: config.influx_bucket, org: config.influx_org, precision: 's')}"
  end

  def connection
    @connection ||= Faraday.new(url: config.influx_url) do |f|
      f.request :authorization, 'Token', config.influx_token
      f.response :raise_error
      f.adapter :net_http_persistent
    end
  end
end
