class ShellyPull
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
        queue << record
      else
        skipped << record.measurement
      end
      queue << last if should_queue_last_record?(record, last)

      @last_records[key] = record
    end
    skipped
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
