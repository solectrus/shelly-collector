class SolectrusRecord
  def initialize(id:, time:, payload:, mac: nil, response_duration: nil)
    @id = id
    @time = time
    @payload = payload
    @mac = mac
    @response_duration = response_duration
  end

  attr_reader :id, :time, :mac

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
