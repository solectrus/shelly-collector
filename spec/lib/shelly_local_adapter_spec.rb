require 'shelly_local_adapter'
require 'config'

describe ShellyLocalAdapter do
  subject(:adapter) do
    described_class.new(config:)
  end

  let(:logger) { MemoryLogger.new }

  before do
    config.logger = logger
  end

  context 'with single device' do
    let(:config) { Config.from_env(shelly_host:, shelly_cloud_server: nil, shelly_interval: 5) }

    describe '#solectrus_record' do
      subject(:solectrus_record) { adapter.solectrus_record }

      context 'when Shelly Pro 3EM', vcr: 'shelly-pro-3em' do
        let(:shelly_host) { 'shelly-heatpump.fritz.box' }

        it 'has values' do
          expect(solectrus_record.power).to be_a(Numeric)
          expect(solectrus_record.temp).to be_a(Numeric)
        end

        it 'has phase power' do
          expect(solectrus_record.power_a).to be_a(Numeric)
          expect(solectrus_record.power_b).to be_a(Numeric)
          expect(solectrus_record.power_c).to be_a(Numeric)
        end

        it 'has a valid time' do
          expect(solectrus_record.time).to be > 1_700_000_000
        end

        it 'handles errors' do
          allow(Faraday::Adapter).to receive(:new).and_raise(StandardError)

          expect(solectrus_record).to be_nil
          adapter.log_batch_results(1)
          expect(logger.error_messages).to include(/Error,/)
        end
      end

      context 'when Shelly Plug S (Gen2)', vcr: 'shelly-plug-s-gen2' do
        let(:shelly_host) { 'shelly-fridge.fritz.box' }

        it 'has values' do
          expect(solectrus_record.power).to be_a(Numeric)
          expect(solectrus_record.temp).to be_a(Numeric)
        end

        it 'has a valid time' do
          expect(solectrus_record.time).to be > 1_700_000_000
        end

        it 'handles errors' do
          allow(Faraday::Adapter).to receive(:new).and_raise(StandardError)

          expect(solectrus_record).to be_nil
          adapter.log_batch_results(1)
          expect(logger.error_messages).to include(/Error,/)
        end
      end

      context 'when Shelly Plug S (Gen3)', vcr: 'shelly-plug-s-gen3' do
        let(:shelly_host) { 'shelly-tv.fritz.box' }

        it 'has values' do
          expect(solectrus_record.power).to be >= 0
          expect(solectrus_record.temp).to be >= 0
        end

        it 'has a valid time' do
          expect(solectrus_record.time).to be > 1_700_000_000
        end

        it 'handles errors' do
          allow(Faraday::Adapter).to receive(:new).and_raise(StandardError)

          expect(solectrus_record).to be_nil
          adapter.log_batch_results(1)
          expect(logger.error_messages).to include(/Error,/)
        end
      end

      context 'when Shelly needs authentication', vcr: 'shelly-auth' do
        let(:shelly_host) { 'shelly-tv.fritz.box' }

        it 'has values' do
          expect(solectrus_record.power).to eq(0.0)
          expect(solectrus_record.temp).to be > 0
        end

        it 'has a valid time' do
          expect(solectrus_record.time).to be > 1_700_000_000
        end

        it 'handles errors' do
          allow(Faraday::Adapter).to receive(:new).and_raise(StandardError)

          expect(solectrus_record).to be_nil
          adapter.log_batch_results(1)
          expect(logger.error_messages).to include(/Error,/)
        end
      end

      context 'when Shelly PM Mini (Gen3)', vcr: 'shelly-pm-mini-gen3' do
        let(:shelly_host) { 'shelly-pm-mini-gen3' }

        it 'has values' do
          expect(solectrus_record.power).to be > 0
        end

        it 'has a valid time' do
          expect(solectrus_record.time).to be > 1_700_000_000
        end

        it 'handles errors' do
          allow(Faraday::Adapter).to receive(:new).and_raise(StandardError)

          expect(solectrus_record).to be_nil
          adapter.log_batch_results(1)
          expect(logger.error_messages).to include(/Error,/)
        end
      end

      context 'when Shelly Plug S (Gen1)', vcr: 'shelly-plug-s-gen1' do
        let(:shelly_host) { 'shelly-plug-s-gen1' }

        it 'has values' do
          expect(solectrus_record.power).to be > 0
        end

        it 'has a valid time' do
          expect(solectrus_record.time).to be > 1_700_000_000
        end

        it 'handles errors' do
          allow(Faraday::Adapter).to receive(:new).and_raise(StandardError)

          expect(solectrus_record).to be_nil
          adapter.log_batch_results(1)
          expect(logger.error_messages).to include(/Error,/)
        end
      end

      context 'when Shelly EM', vcr: 'shelly-em' do
        let(:shelly_host) { 'shelly-em' }

        it 'has values' do
          expect(solectrus_record.power).to be > 0
        end

        it 'has a valid time' do
          expect(solectrus_record.time).to be > 1_700_000_000
        end

        it 'handles errors' do
          allow(Faraday::Adapter).to receive(:new).and_raise(StandardError)

          expect(solectrus_record).to be_nil
          adapter.log_batch_results(1)
          expect(logger.error_messages).to include(/Error,/)
        end
      end

      context 'when Shelly 3EM', vcr: 'shelly-3em' do
        let(:shelly_host) { 'shelly-3em' }

        it 'has values' do
          expect(solectrus_record.power).to be > 0
        end

        it 'has a valid time' do
          expect(solectrus_record.time).to be > 1_700_000_000
        end

        it 'handles errors' do
          allow(Faraday::Adapter).to receive(:new).and_raise(StandardError)

          expect(solectrus_record).to be_nil
          adapter.log_batch_results(1)
          expect(logger.error_messages).to include(/Error,/)
        end
      end
    end
  end

  context 'with multiple devices' do
    around do |example|
      VCR.turned_off { example.run }
    end

    let(:config) do
      Config.new(
        shelly_host: '192.168.1.10,192.168.1.20',
        influx_host: 'localhost',
        influx_token: 'my-token',
        influx_org: 'my-org',
        influx_bucket: 'my-bucket',
        influx_measurement: 'meter_a,meter_b',
      )
    end

    let(:gen2_response_a) do
      {
        'sys' => { 'mac' => 'AABBCCDDEEFF', 'unixtime' => 1_770_264_642 },
        'em:0' => { 'a_act_power' => 100.5, 'b_act_power' => 200.3, 'c_act_power' => 150.0, 'total_act_power' => 450.8 },
        'temperature:0' => { 'tC' => 42.5 },
      }.to_json
    end

    let(:gen1_response_b) do
      {
        'mac' => '112233445566',
        'unixtime' => 1_770_264_645,
        'emeters' => [
          { 'power' => 75.2 },
          { 'power' => 30.1 },
        ],
      }.to_json
    end

    describe '#solectrus_records' do
      subject(:records) { adapter.solectrus_records }

      before do
        # Device A: Gen2 (404 for Gen1, success for Gen2)
        stub_request(:get, 'http://192.168.1.10/status').to_return(status: 404)
        stub_request(:get, 'http://192.168.1.10/rpc/Shelly.GetStatus').to_return(
          status: 200, body: gen2_response_a, headers: { 'Content-Type' => 'application/json' },
        )

        # Device B: Gen1 (success for Gen1)
        stub_request(:get, 'http://192.168.1.20/status').to_return(
          status: 200, body: gen1_response_b, headers: { 'Content-Type' => 'application/json' },
        )
      end

      it 'returns an array of SolectrusRecord' do
        expect(records).to all(be_a(SolectrusRecord))
      end

      it 'returns one record per device' do
        expect(records.size).to eq(2)
      end

      it 'assigns correct measurements' do
        expect(records.map(&:measurement)).to contain_exactly('meter_a', 'meter_b')
      end

      it 'parses power values from Gen2 device' do
        meter_a = records.find { |r| r.measurement == 'meter_a' }
        expect(meter_a.power).to eq(450.8)
      end

      it 'parses power values from Gen1 device' do
        meter_b = records.find { |r| r.measurement == 'meter_b' }
        expect(meter_b.power_a).to eq(75.2)
        expect(meter_b.power_b).to eq(30.1)
      end

      it 'has valid times' do
        records.each do |record|
          expect(record.time).to be > 1_700_000_000
        end
      end

      it 'logs batch results' do
        records
        adapter.log_batch_results(1)
        expect(logger.info_messages).to include(/Got 2 records:/)
      end

      it 'annotates skipped records' do
        records
        adapter.log_batch_results(1, skipped_measurements: ['meter_a'])
        expect(logger.info_messages).to include(/\[skipped\]/)
        expect(logger.success_messages.size).to eq(1)
      end
    end

    describe '#solectrus_record' do
      before do
        stub_request(:get, 'http://192.168.1.10/status').to_return(status: 404)
        stub_request(:get, 'http://192.168.1.10/rpc/Shelly.GetStatus').to_return(
          status: 200, body: gen2_response_a, headers: { 'Content-Type' => 'application/json' },
        )
        stub_request(:get, 'http://192.168.1.20/status').to_return(
          status: 200, body: gen1_response_b, headers: { 'Content-Type' => 'application/json' },
        )
      end

      it 'returns the first record' do
        record = adapter.solectrus_record
        expect(record).to be_a(SolectrusRecord)
      end
    end

    describe 'device error handling' do
      before do
        # Device A fails
        stub_request(:get, 'http://192.168.1.10/status').to_return(status: 404)
        stub_request(:get, 'http://192.168.1.10/rpc/Shelly.GetStatus')
          .to_raise(Faraday::ConnectionFailed.new('Connection refused'))

        # Device B works
        stub_request(:get, 'http://192.168.1.20/status').to_return(
          status: 200, body: gen1_response_b, headers: { 'Content-Type' => 'application/json' },
        )
      end

      it 'skips failed devices and returns successful ones' do
        records = adapter.solectrus_records
        expect(records.size).to eq(1)
        expect(records[0].measurement).to eq('meter_b')
      end

      it 'logs error for failed device' do
        adapter.solectrus_records
        adapter.log_batch_results(1)
        output = logger.error_messages.join("\n")
        expect(output).to include('http://192.168.1.10')
        expect(output).to include('Error, ')
      end
    end

    describe 'total failure handling' do
      before do
        stub_request(:get, 'http://192.168.1.10/status').to_raise(StandardError.new('timeout'))
        stub_request(:get, 'http://192.168.1.10/rpc/Shelly.GetStatus').to_raise(StandardError.new('timeout'))
        stub_request(:get, 'http://192.168.1.20/status').to_raise(StandardError.new('timeout'))
        stub_request(:get, 'http://192.168.1.20/rpc/Shelly.GetStatus').to_raise(StandardError.new('timeout'))
      end

      it 'returns empty array when all devices fail' do
        records = adapter.solectrus_records
        expect(records).to eq([])
      end
    end
  end
end
