require 'shelly_cloud_adapter'
require 'config'

describe ShellyCloudAdapter do
  subject(:adapter) do
    described_class.new(config:)
  end

  let(:logger) { MemoryLogger.new }

  before do
    config.logger = logger
  end

  context 'with single device (V1 API)' do
    let(:config) { Config.from_env(shelly_host: nil) }

    describe '#connection' do
      subject { adapter.connection }

      it { is_expected.to be_a(Faraday::Connection) }
    end

    describe '#solectrus_record', vcr: 'shelly-cloud' do
      subject(:solectrus_record) { adapter.solectrus_record }

      # Cassette reports ts: 1780895614.63 - pretend "now" is right after it,
      # so the freshness guard treats the recorded data as current.
      before { allow(Time).to receive(:now).and_return(Time.at(1_780_895_620)) }

      it { is_expected.to be_a(SolectrusRecord) }

      it 'has an automatic id' do
        expect(solectrus_record.id).to eq(1)
      end

      it 'has values' do
        expect(solectrus_record.power).to be_a(Numeric)
        expect(solectrus_record.temp).to be_a(Numeric)
      end

      it 'has phase power' do
        expect(solectrus_record.power_a).to be_a(Numeric)
        expect(solectrus_record.power_b).to be_a(Numeric)
        expect(solectrus_record.power_c).to be_a(Numeric)
      end

      it 'prefers cloud timestamp (ts) over device sys.unixtime' do
        # V1 cassette has ts: 1780895614.63 and sys.unixtime: 1780894706
        expect(solectrus_record.device_time).to eq(1_780_895_614)
      end

      it 'handles errors' do
        allow(Faraday::Adapter).to receive(:new).and_raise(StandardError)

        solectrus_record
        expect(logger.error_messages).to include(/Error getting data from Shelly Cloud/)
      end
    end

    describe 'offline device handling' do
      around do |example|
        VCR.turned_off { example.run }
      end

      let(:config) do
        Config.new(
          shelly_cloud_server: 'https://shelly-42-eu.shelly.cloud',
          shelly_auth_key: 'abcsecret',
          shelly_device_id: '1234567890',
          influx_host: 'localhost',
          influx_token: 'my-token',
          influx_org: 'my-org',
          influx_bucket: 'my-bucket',
          influx_measurement: 'meter_a',
        )
      end

      before do
        stub_request(:get, 'https://shelly-42-eu.shelly.cloud/device/status')
          .with(query: { 'id' => '1234567890', 'auth_key' => 'abcsecret' })
          .to_return(
            status: 200,
            body: { isok: true, data: { online: false, device_status: {} } }.to_json,
            headers: { 'Content-Type' => 'application/json' },
          )
      end

      it 'skips the offline device' do
        records = adapter.solectrus_records
        expect(records).to be_empty
        expect(logger.warn_messages).to include(/1234567890 is offline/)
      end
    end
  end

  context 'with multiple devices (V2 API)' do
    around do |example|
      VCR.turned_off { example.run }
    end

    # Mock status carries unixtime: 1_770_264_642 - pretend "now" is right after
    # it, so the freshness guard treats the mocked data as current.
    before { allow(Time).to receive(:now).and_return(Time.at(1_770_264_650)) }

    let(:config) do
      Config.new(
        shelly_cloud_server: 'https://shelly-42-eu.shelly.cloud',
        shelly_auth_key: 'abcsecret',
        shelly_device_id: 'device_aaa,device_bbb',
        influx_host: 'localhost',
        influx_token: 'my-token',
        influx_org: 'my-org',
        influx_bucket: 'my-bucket',
        influx_measurement: 'meter_a,meter_b',
      )
    end

    let(:batch_response) do
      [
        {
          'id' => 'device_aaa',
          'type' => 'SPEM-003CEBEU',
          'gen' => 'G2',
          'online' => 1,
          'status' => {
            'sys' => { 'mac' => 'AABBCCDDEEFF', 'unixtime' => 1_770_264_642 },
            'em:0' => { 'a_act_power' => 100.5, 'b_act_power' => 200.3, 'c_act_power' => 150.0, 'total_act_power' => 450.8 },
            'temperature:0' => { 'id' => 0, 'tC' => 42.5, 'tF' => 108.5 },
          },
        },
        {
          'id' => 'device_bbb',
          'type' => 'SHPLG-S',
          'gen' => 'G1',
          'online' => 1,
          'status' => {
            'sys' => { 'mac' => '112233445566', 'unixtime' => 1_770_264_642 },
            'switch:0' => { 'apower' => 75.2, 'temperature' => { 'tC' => 35.1 } },
          },
        },
      ]
    end

    describe '#solectrus_records' do
      subject(:records) { adapter.solectrus_records }

      before do
        stub_request(:post, 'https://shelly-42-eu.shelly.cloud/v2/devices/api/get?auth_key=abcsecret')
          .to_return(status: 200, body: batch_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns an array of SolectrusRecord' do
        expect(records).to all(be_a(SolectrusRecord))
      end

      it 'returns one record per device' do
        expect(records.size).to eq(2)
      end

      it 'assigns correct measurements' do
        expect(records.map(&:measurement)).to eq(%w[meter_a meter_b])
      end

      it 'parses power values from first device' do
        expect(records[0].power).to eq(450.8)
        expect(records[0].power_a).to eq(100.5)
        expect(records[0].power_b).to eq(200.3)
        expect(records[0].power_c).to eq(150.0)
      end

      it 'parses power values from second device' do
        expect(records[1].power_a).to eq(75.2)
      end

      it 'parses temperature' do
        expect(records[0].temp).to eq(42.5)
        expect(records[1].temp).to eq(35.1)
      end

      it 'uses sys.unixtime as device_time' do
        records.each do |record|
          expect(record.device_time).to eq(1_770_264_642)
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
        stub_request(:post, 'https://shelly-42-eu.shelly.cloud/v2/devices/api/get?auth_key=abcsecret')
          .to_return(status: 200, body: batch_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the first record' do
        record = adapter.solectrus_record
        expect(record).to be_a(SolectrusRecord)
        expect(record.measurement).to eq('meter_a')
      end
    end

    describe 'offline device handling' do
      before do
        offline_response = batch_response.map(&:dup)
        offline_response[0] = offline_response[0].merge('online' => 0)

        stub_request(:post, 'https://shelly-42-eu.shelly.cloud/v2/devices/api/get?auth_key=abcsecret')
          .to_return(status: 200, body: offline_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'skips offline devices' do
        records = adapter.solectrus_records
        expect(records.size).to eq(1)
        expect(records[0].measurement).to eq('meter_b')
        expect(logger.warn_messages).to include(/device_aaa is offline/)
      end
    end

    describe 'stale device handling' do
      before do
        stub_request(:post, 'https://shelly-42-eu.shelly.cloud/v2/devices/api/get?auth_key=abcsecret')
          .to_return(status: 200, body: batch_response.to_json, headers: { 'Content-Type' => 'application/json' })

        # Move "now" far past the cached status (1_770_264_642) so it is stale.
        allow(Time).to receive(:now).and_return(Time.at(1_770_264_642 + 3600))
      end

      it 'skips online devices whose cached data is too old' do
        records = adapter.solectrus_records
        expect(records).to be_empty
        expect(logger.warn_messages).to include(/data is stale/)
      end
    end

    describe 'error handling' do
      it 'returns empty array on error' do
        stub_request(:post, 'https://shelly-42-eu.shelly.cloud/v2/devices/api/get?auth_key=abcsecret')
          .to_raise(StandardError.new('connection failed'))

        records = adapter.solectrus_records
        expect(records).to eq([])
        expect(logger.error_messages).to include(/Error getting data from Shelly Cloud/)
      end
    end
  end
end
