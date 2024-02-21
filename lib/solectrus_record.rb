class SolectrusRecord
  def initialize(id:, time:, payload:)
    @id = id
    @time = time
    @payload = payload
  end

  attr_reader :id, :time

  def to_hash
    @payload
  end

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
end
