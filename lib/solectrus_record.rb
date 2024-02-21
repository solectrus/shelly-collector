class SolectrusRecord
  def initialize(id, measure_time, payload)
    @id = id
    @measure_time = measure_time
    @payload = payload
  end

  attr_reader :id, :measure_time

  def to_hash
    @payload
  end

  %i[
    temp
    power
    response_duration
  ].each do |method|
    define_method(method) do
      @payload[method]
    end
  end
end
