require 'shelly_adapter'
require 'config'

describe ShellyAdapter do
  subject(:adapter) do
    described_class.new(config:)
  end

  let(:config) { Config.from_env(shelly_interval: 5) }
  let(:logger) { MemoryLogger.new }

  before do
    config.logger = logger
  end

  describe '#initialize' do
    before { adapter }

    it { expect(logger.info_messages).to include('Pulling from your Shelly at http://192.168.178.83 every 5 seconds') }
  end

  describe '#connection' do
    subject { adapter.connection }

    it { is_expected.to be_a(Faraday::Connection) }
  end

  describe '#solectrus_record', vcr: 'shelly' do
    subject(:solectrus_record) { adapter.solectrus_record }

    it { is_expected.to be_a(SolectrusRecord) }

    it 'has an automatic id' do
      expect(solectrus_record.id).to eq(1)
    end

    it 'has a valid measure_time' do
      expect(solectrus_record.measure_time).to be > 1_700_000_000
    end

    it 'handles errors' do
      allow(Faraday::Adapter).to receive(:new).and_raise(StandardError)

      solectrus_record
      expect(logger.error_messages).to include(/Error getting data from Shelly at/)
    end
  end
end
