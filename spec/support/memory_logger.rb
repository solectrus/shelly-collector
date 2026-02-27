class MemoryLogger
  def initialize
    @info_messages = []
    @success_messages = []
    @warn_messages = []
    @error_messages = []
  end

  attr_reader :info_messages, :success_messages, :warn_messages, :error_messages

  def info(message, **)
    @info_messages << message
  end

  def success(message)
    @success_messages << message
  end

  def warn(message)
    @warn_messages << message
  end

  def error(message)
    @error_messages << message
  end
end
