require 'influx_push'
require 'shelly_pull'
require 'forwardable'

class Loop
  extend Forwardable
  def_delegators :config, :logger

  def self.start(config:, max_count: nil, &)
    new(config:, max_count:, &).start
  end

  def initialize(config:, max_count:)
    @config = config
    @max_count = max_count
  end

  attr_reader :config, :max_count
  attr_accessor :queue

  def start
    self.queue = Queue.new

    pull_thread = Thread.new { pull_loop }
    push_thread = Thread.new { push_loop }

    # Wait for the pull thread to finish (will happen if max_count is set)
    pull_thread.join

    # Push any remaining records to InfluxDB
    close_queue

    # Wait for the push thread to finish (will happen because queue is closed)
    push_thread.join
  rescue SystemExit, Interrupt
    logger.error 'Exiting...'

    # Stop pulling data from Shelly
    pull_thread.exit

    # Push any remaining records to InfluxDB (can take a while)
    close_queue

    # Stop pushing data to InfluxDB
    push_thread.exit
  end

  private

  def shelly_pull
    @shelly_pull ||= ShellyPull.new(config:, queue:)
  end

  # Pull data from Shelly and add to queue
  def pull_loop
    loop do
      shelly_pull.next

      break if max_count && shelly_pull.count >= max_count

      sleep config.shelly_interval
    end
  end

  # Push data from queue to InfluxDB
  def push_loop
    InfluxPush.new(config:, queue:).run
  end

  def close_queue
    until queue.empty?
      logger.info "Waiting for #{queue.size} records to be pushed to InfluxDB"
      sleep 1
    end

    queue.close
  end
end
