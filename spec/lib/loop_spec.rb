require 'loop'
require 'config'
require 'tmpdir'

describe Loop do
  let(:config) do
    Config.from_env(shelly_cloud_server: nil, shelly_host: 'shelly-heatpump.fritz.box')
  end
  let(:logger) { MemoryLogger.new }
  let(:dir) { Dir.mktmpdir }
  let(:buffer_path) { File.join(dir, 'buffer.jsonl') }

  before do
    config.logger = logger
    stub_const('BufferStore::DEFAULT_PATH', buffer_path)
  end

  after { FileUtils.remove_entry(dir) }

  describe '#start' do
    it 'outputs the correct information when started' do
      VCR.use_cassette('shelly-pro-3em') do
        VCR.use_cassette('influx-success') do
          described_class.start(config:, max_count: 2, max_wait: 1)
        end
      end

      expect(logger.success_messages).to include(/Power/)
    end

    it 'starts collecting even if InfluxDB is not ready at startup' do
      allow_any_instance_of(FluxWriter).to receive(:ready?).and_return(false) # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:sleep) # rubocop:disable RSpec/AnyInstance

      VCR.use_cassette('influx-success') do
        VCR.use_cassette('shelly-pro-3em') do
          described_class.start(config:, max_count: 2, max_wait: 2)
        end
      end

      expect(logger.error_messages).to include(/InfluxDB not ready after 10 seconds, records will be buffered/)
      expect(logger.info_messages).to include(/Successfully pushed/)
    end

    it 'handles Interrupt' do
      allow(config.adapter).to receive(:solectrus_records).and_raise(SystemExit)

      VCR.use_cassette('influx-success') do
        VCR.use_cassette('shelly-pro-3em') do
          described_class.start(config:, max_wait: 1)
        end
      end

      expect(logger.error_messages).to include(/Exiting/)
    end

    it 'handles SIGTERM' do
      allow(config.adapter).to receive(:solectrus_records) { send_sigterm }

      VCR.use_cassette('influx-success') do
        VCR.use_cassette('shelly-pro-3em') do
          described_class.start(config:, max_wait: 1)
        end
      end

      expect(logger.error_messages).to include(/Exiting/)
    end

    it 'restores buffered records on start' do
      BufferStore.new(logger:).save([SolectrusRecord.new(id: 42, time: 1_700_000_000, payload: { power: 500 })])

      VCR.use_cassette('influx-success') do
        VCR.use_cassette('shelly-pro-3em') do
          described_class.start(config:, max_count: 1, max_wait: 1)
        end
      end

      expect(logger.info_messages).to include(/Restored 1 buffered records/)
      expect(logger.info_messages).to include(/Successfully pushed (2 records|record #42)/)
      expect(File.exist?(buffer_path)).to be(false)
    end

    it 'saves buffered records on SIGTERM if InfluxDB is not available' do
      allow(FluxWriter).to receive(:new).and_return(UnavailableFluxWriter.new)
      allow_any_instance_of(described_class).to receive(:sleep) # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(InfluxPush).to receive(:sleep) # rubocop:disable RSpec/AnyInstance
      allow(config.adapter).to receive(:solectrus_records) do |id|
        if id <= 2
          [SolectrusRecord.new(id:, time: 1_700_000_000 + id, payload: { power: 500 })]
        elsif id == 3
          send_sigterm
        else
          []
        end
      end

      described_class.start(config:, max_wait: 1)

      restored = BufferStore.new(logger:).load
      expect(restored.map(&:id)).to contain_exactly(1, 2)
      expect(restored.map(&:time)).to contain_exactly(1_700_000_001, 1_700_000_002)
    end

    it 'handles errors' do
      VCR.turned_off do
        stub_request(:get, %r{localhost:8086/ping}).to_return(status: 204)
        stub_request(:get, /shelly-heatpump/).to_raise(StandardError.new('connection failed'))

        described_class.start(config:, max_count: 1, max_wait: 1)
      end

      expect(logger.error_messages).to include(/Error,/)
    end
  end

  # Docker sends SIGTERM to the process, so Ruby raises it in the main thread
  def send_sigterm
    Thread.main.raise(SignalException, 'TERM')
    []
  end
end

class UnavailableFluxWriter
  def ready?
    false
  end

  def push(_records)
    raise Errno::ECONNREFUSED
  end
end
