require 'flux_writer'
require 'forwardable'

class InfluxPush
  extend Forwardable

  def_delegators :config, :logger

  def initialize(config:, queue:)
    @config = config
    @queue = queue
    @flux_writer = FluxWriter.new(config)
    @pushed = []
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
      # Wait for a record to be added to the queue
      record = queue.pop

      # Push (unless queue has been closed)
      push(record) if record
    end
  end

  private

  def push(record)
    flux_writer.push(record)
    @pushed << record
    log_push_summary if queue.empty?
    log_recovery if @failing_since
  rescue StandardError => e
    log_push_summary
    error_handling(record, e)

    # Wait a bit before trying again
    sleep(5)
  end

  def log_push_summary
    return if @pushed.empty?

    if @pushed.size == 1
      logger.info "Successfully pushed record ##{@pushed.first.id}#{measurement_suffix} to InfluxDB"
    else
      logger.info "Successfully pushed #{@pushed.size} points for ##{@pushed.first.id} to InfluxDB"
    end

    @pushed = []
  end

  def measurement_suffix
    return unless config.multi_device?

    " for #{@pushed.first.measurement || config.influx_measurement}"
  end

  def error_handling(record, error)
    # Log the first failure only, so a long outage does not flood the log
    unless @failing_since
      @failing_since = Time.now
      logger.error "Error while pushing record ##{record.id} to InfluxDB: #{error.message}"
      logger.error 'Records will be buffered and pushed when InfluxDB is available again.'
    end

    return if queue.closed?

    # Put the record back into the queue
    queue << record
  end

  def log_recovery
    logger.info "InfluxDB is available again after #{(Time.now - @failing_since).round} seconds, " \
                "#{queue.size} buffered records remaining"
    @failing_since = nil
  end
end
