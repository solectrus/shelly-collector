class ShellyPull
  # Maximum number of records to buffer while InfluxDB is not reachable.
  # One record needs about 0.5 KB of memory, so the buffer is limited to about 250 MB.
  # With one device at the minimum interval of 5 seconds this covers about 4 weeks.
  MAX_QUEUE_SIZE = 500_000

  def initialize(config:, queue:)
    @queue = queue
    @config = config
    @count = 0
    @last_records = {}
  end

  attr_reader :config, :queue, :count

  def next
    @count += 1

    records = fetch_records
    skipped = process_records(records)
    log_batch_results(skipped)
    records
  end

  private

  def fetch_records
    config.adapter.solectrus_records(@count)
  end

  def process_records(records)
    skipped = []
    records.each do |record|
      key = record.measurement || :default
      last = @last_records[key]

      if should_queue?(record, last)
        enqueue(record)
      else
        skipped << record.measurement
      end
      enqueue(last) if should_queue_last_record?(record, last)

      @last_records[key] = record
    end
    skipped
  end

  def enqueue(record)
    make_room
    queue << record
  end

  # Drop the oldest record if the buffer is full
  def make_room
    @buffer_full = false if queue.empty?
    return if queue.size < MAX_QUEUE_SIZE

    queue.pop(true)
    return if @buffer_full

    # Log once per outage only
    @buffer_full = true
    config.logger.error "Buffer is full (#{MAX_QUEUE_SIZE} records), dropping oldest records"
  rescue ThreadError
    # Queue has been emptied by the push thread in the meantime
  end

  def log_batch_results(skipped)
    config.adapter.log_batch_results(@count, skipped_measurements: skipped)
  end

  def should_queue?(record, last_record)
    case config.device_config_for(record.measurement).influx_mode
    when :default
      true

    when :essential
      # Only queue this record if the power is non-zero or if it just changed to zero
      record.power? || last_record.nil? || last_record.power?
    end
  end

  def should_queue_last_record?(record, last_record)
    case config.device_config_for(record.measurement).influx_mode
    when :default
      false

    when :essential
      # To ensure that a curve always starts at zero, we queue the last record (if it changes from zero)
      record.power? && last_record && !last_record.power?
    end
  end
end
