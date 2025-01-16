class SolectrusRecord
  def initialize(id:, time:, payload:, response_duration: nil)
    @id = id
    @time = time
    @payload = payload
    @response_duration = response_duration
  end

  attr_reader :id, :time, :response_duration

  def to_hash
    @payload
  end

  %i[
    temp
    power
    power_a
    power_b
    power_c
  ].each do |method|
    define_method(method) do
      @payload[method]
    end
  end

  def power?
    !power.round.zero?
  end
end
