require 'shelly_local_adapter'
require 'config'

describe ShellyLocalAdapter do
  subject(:adapter) do
    described_class.new(config:)
  end

  let(:config) { Config.from_env(shelly_host:, shelly_interval: 5) }
  let(:shelly_host) { '192.168.178.83' }
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

  describe '#solectrus_record' do
    subject(:solectrus_record) { adapter.solectrus_record }

    context 'when Shelly Pro 3EM', vcr: 'shelly-pro-3em' do
      let(:shelly_host) { 'shelly-pro-3em' }

      it 'has values' do
        expect(solectrus_record.power).to be > 0
        expect(solectrus_record.temp).to be > 0
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

    context 'when Shelly Plug S (Gen2)', vcr: 'shelly-plug-s-gen2' do
      subject(:solectrus_record) { adapter.solectrus_record }

      let(:shelly_host) { 'shelly-plug-s' }

      it 'has values' do
        expect(solectrus_record.power).to be > 0
        expect(solectrus_record.temp).to be > 0
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

    context 'when Shelly Plug S (Gen3)', vcr: 'shelly-plug-s-gen3' do
      subject(:solectrus_record) { adapter.solectrus_record }

      let(:shelly_host) { 'shelly-plug-s-gen3' }

      it 'has values' do
        expect(solectrus_record.power).to be > 0
        expect(solectrus_record.temp).to be > 0
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

    context 'when Shelly needs authentication', vcr: 'shelly-auth' do
      subject(:solectrus_record) { adapter.solectrus_record }

      let(:shelly_host) { '192.168.178.108' }

      it 'has values' do
        expect(solectrus_record.power).to eq(0.0)
        expect(solectrus_record.temp).to be > 0
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

    context 'when Shelly PM Mini (Gen3)', vcr: 'shelly-pm-mini-gen3' do
      subject(:solectrus_record) { adapter.solectrus_record }

      let(:shelly_host) { 'shelly-pm-mini-gen3' }

      it 'has values' do
        expect(solectrus_record.power).to be > 0
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

    context 'when Shelly PM Mini (Gen3)', vcr: 'shelly-plug-s-gen1' do
      subject(:solectrus_record) { adapter.solectrus_record }

      let(:shelly_host) { 'shelly-plug-s-gen1' }

      it 'has values' do
        expect(solectrus_record.power).to be > 0
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

    context 'when Shelly EM', vcr: 'shelly-em' do
      subject(:solectrus_record) { adapter.solectrus_record }

      let(:shelly_host) { 'shelly-em' }

      it 'has values' do
        expect(solectrus_record.power).to be > 0
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

    context 'when Shelly 3EM', vcr: 'shelly-3em' do
      subject(:solectrus_record) { adapter.solectrus_record }

      let(:shelly_host) { 'shelly-3em' }

      it 'has values' do
        expect(solectrus_record.power).to be > 0
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
end
