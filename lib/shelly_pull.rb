class ShellyPull
  def initialize(config:, queue:)
    @queue = queue
    @config = config
    @count = 0
    @last_record = nil
  end

  attr_reader :config, :queue, :count

  def next
    record = config.adapter.solectrus_record(@count += 1)

    queue << record if should_queue?(record)
    queue << @last_record if should_queue_last_record?(record)

    # Remember the last record for the next iteration
    @last_record = record

    record
  end

  private

  def should_queue?(record)
    case config.influx_mode
    when :default
      # Always queue this record
      true

    when :essential
      # Only queue this record if the power is non-zero or if it just changed to zero
      result = record.power? || @last_record.nil? || @last_record.power?
      config.logger.info "Ignoring record ##{record.id} (zero power)" unless result

      result
    end
  end

  def should_queue_last_record?(record)
    case config.influx_mode
    when :default
      false

    when :essential
      # To ensure that a curve always starts at zero, we queue the last record (if it changes from zero)
      record.power? && @last_record && !@last_record.power?
    end
  end
end
