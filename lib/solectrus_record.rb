class SolectrusRecord
  def initialize(id, payload)
    @id = id
    @payload = payload
  end

  attr_reader :id

  def to_hash
    @payload
  end

  %i[
    measure_time
    temp
    power
    response_duration
  ].each do |method|
    define_method(method) do
      @payload[method]
    end
  end
end
