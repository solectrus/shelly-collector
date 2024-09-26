require 'shelly_gen1_adapter'
require 'config'

describe ShellyGen1Adapter do
  subject(:adapter) do
    described_class.new(config:)
  end

  let(:config) { Config.from_env(shelly_host:, shelly_gen: 1, shelly_interval: 5) }
  let(:shelly_host) { 'shelly-3em' }
  let(:logger) { MemoryLogger.new }

  before do
    config.logger = logger
  end

  describe '#initialize' do
    before { adapter }

    it { expect(logger.info_messages).to include('Pulling from your Shelly (Gen1) at http://shelly-3em/status every 5 seconds') }
  end

  describe '#connection' do
    subject { adapter.connection }

    it { is_expected.to be_a(Faraday::Connection) }
  end

  describe '#solectrus_record', vcr: 'shelly-3em' do # Manually created cassette!
    subject(:solectrus_record) { adapter.solectrus_record }

    let(:shelly_host) { 'shelly-3em' }

    it { is_expected.to be_a(SolectrusRecord) }

    it 'has an automatic id' do
      expect(solectrus_record.id).to eq(1)
    end

    it 'has total power' do
      expect(solectrus_record.power).to be > 0
    end

    it 'has phase power' do
      expect(solectrus_record.power_a).to be >= 0
      expect(solectrus_record.power_b).to be >= 0
      expect(solectrus_record.power_c).to be >= 0
    end

    it 'has a valid time' do
      expect(solectrus_record.time).to be > 1_700_000_000
    end

    it 'handles errors' do
      allow(Faraday::Adapter).to receive(:new).and_raise(StandardError)

      solectrus_record
      expect(logger.error_messages).to include(/Error getting data from Shelly at/)
    end
  end
end
