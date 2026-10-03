require 'influx_push'
require 'shelly_pull'
require 'config'

describe InfluxPush do
  let(:config) { Config.from_env(shelly_cloud_server: nil) }
  let(:queue) { Queue.new }
  let!(:shelly_pull) do
    ShellyPull.new(config:, queue:)
  end
  let(:logger) { MemoryLogger.new }

  before do
    config.logger = logger
  end

  describe '#run', vcr: 'shelly-pro-3em' do
    context 'with a single record' do
      before { fill_queue }

      it 'successfully pushes a record to InfluxDB' do
        assert_success('record #1') do
          run_influx_push
        end
      end
    end

    context 'with multiple records' do
      before { fill_queue(3) }

      it 'successfully pushes multiple records to InfluxDB in one batch' do
        assert_success('3 records') do
          run_influx_push
        end
      end
    end

    context 'with more records than the batch size' do
      before do
        stub_const('InfluxPush::BATCH_SIZE', 2)
        fill_queue(3)
      end

      it 'successfully pushes records in multiple batches' do
        assert_success('2 records', 'record #3') do
          run_influx_push
        end
      end
    end

    context 'with multiple devices' do
      let(:config) do
        Config.new(
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2',
          influx_host: 'localhost',
          influx_token: 'token',
          influx_org: 'org',
          influx_bucket: 'bucket',
          influx_measurement: 'meter1,meter2',
        )
      end

      before { allow(FluxWriter).to receive(:new).and_return(instance_double(FluxWriter, push: nil)) }

      it 'pushes the records of one poll as points for this poll' do
        %w[meter1 meter2].each do |measurement|
          queue << SolectrusRecord.new(id: 1, time: 1, payload: { power: 100 }, measurement:)
        end

        assert_success('2 points for #1') do
          run_influx_push
        end
      end

      it 'names the measurement of a single record' do
        queue << SolectrusRecord.new(id: 1, time: 1, payload: { power: 100 }, measurement: 'meter2')

        assert_success('record #1 for meter2') do
          run_influx_push
        end
      end
    end

    context 'when failure' do
      before do
        fill_queue

        allow(FluxWriter).to receive(:new).and_return(FailingFluxWriter.new)
      end

      it 'handles failure during record push' do
        assert_failure(1) do
          run_influx_push
        end
      end
    end

    context 'when InfluxDB rejects a record' do
      before do
        fill_queue(3)

        allow(FluxWriter).to receive(:new).and_return(RejectingFluxWriter.new(rejected_id: 2))
      end

      it 'drops the rejected record and pushes the others' do
        assert_success('record #1', 'record #3') do
          run_influx_push
        end

        expect(logger.error_messages).to include(/InfluxDB rejected record #2, dropping it/)
        expect(logger.info_messages).not_to include(/Successfully pushed record #2/)
      end
    end

    context 'when InfluxDB recovers' do
      before do
        fill_queue(2)

        allow(FluxWriter).to receive(:new).and_return(RecoveringFluxWriter.new)
      end

      it 'pushes buffered records and logs the failure only once' do
        pusher = described_class.new(config:, queue:)
        allow(pusher).to receive(:sleep)

        run_until_pushed(pusher)

        expect(logger.info_messages).to include('Successfully pushed 2 records to InfluxDB')
        expect(logger.error_messages.grep(/Error while pushing/).size).to eq(1)
        expect(logger.info_messages).to include(/InfluxDB is available again/)
      end

      it 'does not log the failure if InfluxDB is already known to be unavailable' do
        pusher = described_class.new(config:, queue:)
        allow(pusher).to receive(:sleep)
        pusher.mark_unavailable

        run_until_pushed(pusher)

        expect(logger.error_messages).to be_empty
        expect(logger.info_messages).to include(/InfluxDB is available again/)
      end
    end
  end

  # Helper methods

  def fill_queue(num_records = 1)
    num_records.times { shelly_pull.next }

    expect(queue.length).to eq(num_records)
  end

  def run_influx_push
    thread = Thread.new do
      VCR.use_cassette('influx-success') do
        pusher = described_class.new(config:, queue:)
        pusher.run
      end
    end

    Timeout.timeout(1) { loop until queue.empty? }
    queue.close
    thread.join
  end

  def run_until_pushed(pusher)
    thread = Thread.new { pusher.run }
    Timeout.timeout(1) { sleep 0.01 until logger.info_messages.grep(/InfluxDB is available again/).any? }
    queue.close
    thread.join
  end

  def assert_success(*descriptions)
    yield

    descriptions.each do |description|
      expect(logger.info_messages).to include "Successfully pushed #{description} to InfluxDB"
    end

    expect(queue.length).to eq(0)
  end

  def assert_failure(num_records, &)
    expect(&).to raise_error(Timeout::Error)
    expect(logger.error_messages).to include(/Error while pushing record #1 to InfluxDB/)
    expect(queue.length).to eq(num_records)
  end
end

class FailingFluxWriter
  def push(_records)
    raise Faraday::ServerError, 'Internal Server Error'
  end
end

class RecoveringFluxWriter
  def initialize
    @failures = 2
  end

  def push(_records)
    return if (@failures -= 1).negative?

    raise Faraday::ServerError, 'Internal Server Error'
  end
end

class RejectingFluxWriter
  def initialize(rejected_id:)
    @rejected_id = rejected_id
  end

  def push(records)
    return if records.none? { |record| record.id == @rejected_id }

    raise Faraday::UnprocessableContentError, 'field type conflict'
  end
end
