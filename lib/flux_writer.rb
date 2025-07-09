class FluxWriter
  def initialize(config)
    @config = config
  end

  attr_reader :config

  def ready?
    influx_client.ping.status == 'ok'
  end

  def push(record)
    return unless record

    write_api.write(
      data: point(record),
      bucket: config.influx_bucket,
      org: config.influx_org,
    )
  end

  private

  def point(record)
    fields = record.to_hash

    # Convert power fields to integers if configured
    if config.influx_power_data_type == 'Integer'
      fields.each do |key, value|
        next unless key.to_s.start_with?('power') && value.is_a?(Numeric)

        fields[key] = value.round
      end
    end

    InfluxDB2::Point.new(
      name: influx_measurement,
      time: record.time,
      fields: fields,
      # TODO: Add tags, so just ONE Measurement would be enough
      # tags: { mac: record.mac }.compact,
    )
  end

  def influx_measurement
    config.influx_measurement
  end

  def influx_client
    @influx_client ||=
      InfluxDB2::Client.new(
        config.influx_url,
        config.influx_token,
        use_ssl: config.influx_schema == :https,
        precision: InfluxDB2::WritePrecision::SECOND,
      )
  end

  def write_api
    @write_api ||= influx_client.create_write_api
  end
end
