class SolectrusRecord
  # time: when the record was collected (used as InfluxDB point time)
  # device_time: when the device (or cloud cache) last reported (used for staleness detection)
  def initialize(id:, time:, payload:, mac: nil, device_time: nil, response_duration: nil, measurement: nil) # rubocop:disable Metrics/ParameterLists
    @id = id
    @time = time
    @device_time = device_time
    @payload = payload
    @mac = mac
    @response_duration = response_duration
    @measurement = measurement
  end

  attr_reader :id, :time, :device_time, :mac, :measurement

  %i[
    temp
    power
    power_a
    power_b
    power_c
    response_duration
  ].each do |method|
    define_method(method) do
      @payload[method]
    end
  end

  def to_hash
    @payload.merge(
      response_duration:,
    ).compact
  end

  def power?
    !power.round.zero?
  end
end
