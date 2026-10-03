require 'flux_writer'
require 'forwardable'

class InfluxPush
  extend Forwardable

  # Maximum number of records to push in one request
  BATCH_SIZE = 1000

  # Errors (HTTP 400 and 422) for data that InfluxDB will never accept (e.g. field type conflict).
  # Retrying such records would block all other records.
  REJECTED_ERRORS = [Faraday::BadRequestError, Faraday::UnprocessableContentError].freeze

  def_delegators :config, :logger

  def initialize(config:, queue:)
    @config = config
    @queue = queue
    @flux_writer = FluxWriter.new(config)
  end

  attr_reader :config, :queue, :flux_writer

  def ready?
    flux_writer.ready?
  end

  # Avoid logging the first failed push if InfluxDB is already known to be unavailable
  def mark_unavailable
    @failing_since = Time.now
  end

  def run
    until queue.closed?
      records = next_batch

      # Push (unless queue has been closed)
      push(records) if records.any?
    end
  end

  private

  def next_batch
    # Wait for a record to be added to the queue (nil if the queue has been closed)
    record = queue.pop
    return [] unless record

    # Add more records if available (e.g. other devices or buffered during an outage)
    records = [record]
    while records.size < BATCH_SIZE && (record = queue.pop(timeout: 0))
      records << record
    end
    records
  end

  def push(records)
    flux_writer.push(records)
    logger.info "Successfully pushed #{description(records)} to InfluxDB"
    log_recovery if @failing_since
  rescue *REJECTED_ERRORS => e
    drop_rejected(records, e)
  rescue StandardError => e
    retry_later(records, e)
  end

  # Push the records one by one to drop the rejected ones only
  def drop_rejected(records, error)
    if records.one?
      logger.error "InfluxDB rejected #{description(records)}, dropping it: #{error.message}"
    else
      records.each { |record| push([record]) }
    end
  end

  def retry_later(records, error)
    # Log the first failure only, so a long outage does not flood the log
    unless @failing_since
      @failing_since = Time.now
      logger.error "Error while pushing #{description(records)} to InfluxDB: #{error.message}"
      logger.error 'Records will be buffered and pushed when InfluxDB is available again.'
    end

    return if queue.closed?

    # Put the records back into the queue
    records.each { |record| queue << record }

    # Wait a bit before trying again
    sleep(5)
  end

  def description(records)
    first = records.first

    if records.one?
      "record ##{first.id}#{measurement_suffix(first)}"
    elsif records.all? { |record| record.id == first.id }
      "#{records.size} points for ##{first.id}"
    else
      "#{records.size} records"
    end
  end

  def measurement_suffix(record)
    return unless config.multi_device?

    " for #{record.measurement || config.influx_measurement}"
  end

  def log_recovery
    logger.info "InfluxDB is available again after #{(Time.now - @failing_since).round} seconds, " \
                "#{queue.size} buffered records remaining"
    @failing_since = nil
  end
end
