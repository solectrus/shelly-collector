require 'loop'
require 'config'

describe Loop do
  let(:config) do
    Config.from_env(shelly_cloud_server: nil, shelly_host: 'shelly-heatpump.home.arpa')
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

      expect(logger.info_messages).to include(/Got record #1/)
    end

    it 'handles Interrupt' do
      allow(config.adapter).to receive(:raw_response).and_raise(SystemExit)

      VCR.use_cassette('influx-success') do
        VCR.use_cassette('shelly-pro-3em') do
          described_class.start(config:, max_wait: 1)
        end
      end

      expect(logger.error_messages).to include(/Exiting/)
    end

    it 'handles errors' do
      allow(config.adapter).to receive(:raw_response).and_raise(StandardError)

      VCR.use_cassette('influx-success') do
        described_class.start(config:, max_count: 1, max_wait: 1)
      end

      expect(logger.error_messages).to include(/Error getting data/)
    end
  end
end
