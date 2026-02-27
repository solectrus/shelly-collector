require 'loop'
require 'config'

describe Loop do
  let(:config) do
    Config.from_env(shelly_cloud_server: nil, shelly_host: 'shelly-heatpump.fritz.box')
  end
  let(:logger) { MemoryLogger.new }

  before { config.logger = logger }

  describe '#start' do
    it 'outputs the correct information when started' do
      VCR.use_cassette('influx-success') do
        VCR.use_cassette('shelly-pro-3em') do
          described_class.start(config:, max_count: 2, max_wait: 1)
        end
      end

      expect(logger.success_messages).to include(/Power/)
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

    it 'handles errors' do
      VCR.turned_off do
        stub_request(:get, %r{localhost:8086/ping}).to_return(status: 204)
        stub_request(:get, /shelly-heatpump/).to_raise(StandardError.new('connection failed'))

        described_class.start(config:, max_count: 1, max_wait: 1)
      end

      expect(logger.error_messages).to include(/Error,/)
    end
  end
end
