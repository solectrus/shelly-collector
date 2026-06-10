require 'shelly_response_parser'

describe ShellyResponseParser do
  subject(:parser) { described_class.new(json) }

  describe '#solectrus_record' do
    subject(:solectrus_record) { parser.solectrus_record }

    context 'when Shelly Plug S (Gen1)' do
      let(:json) { read_json('shelly-plug-s-gen1') }

      it { is_expected.to be_a(SolectrusRecord) }

      it 'has an automatic id' do
        expect(solectrus_record.id).to eq(1)
      end

      it 'has power' do
        expect(solectrus_record.power).to be > 0
      end

      it 'has a valid time' do
        expect(solectrus_record.time).to be > 1_700_000_000
      end
    end

    context 'when Shelly Plug S (Gen2)' do
      let(:json) { read_json('shelly-plug-s-gen2') }

      it { is_expected.to be_a(SolectrusRecord) }

      it 'has an automatic id' do
        expect(solectrus_record.id).to eq(1)
      end

      it 'has power' do
        expect(solectrus_record.power).to be_a(Numeric)
      end

      it 'has temp' do
        expect(solectrus_record.temp).to be_a(Numeric)
      end

      it 'has a valid time' do
        expect(solectrus_record.time).to be > 1_700_000_000
      end
    end

    context 'when Shelly Plug S (Gen3)' do
      let(:json) { read_json('shelly-plug-s-gen3') }

      it { is_expected.to be_a(SolectrusRecord) }

      it 'has an automatic id' do
        expect(solectrus_record.id).to eq(1)
      end

      it 'has power' do
        expect(solectrus_record.power).to be >= 0
      end

      it 'has temp' do
        expect(solectrus_record.temp).to be > 0
      end

      it 'has a valid time' do
        expect(solectrus_record.time).to be > 1_700_000_000
      end
    end

    context 'when Shelly Plug 2' do
      let(:json) { read_json('shelly-plug-2') }

      it { is_expected.to be_a(SolectrusRecord) }

      it 'has an automatic id' do
        expect(solectrus_record.id).to eq(1)
      end

      it 'has power' do
        expect(solectrus_record.power).to be > 0
      end

      it 'has a valid time' do
        expect(solectrus_record.time).to be > 1_700_000_000
      end
    end

    context 'when Shelly Pro EM' do
      let(:json) { read_json('shelly-em') }

      it { is_expected.to be_a(SolectrusRecord) }

      it 'has an automatic id' do
        expect(solectrus_record.id).to eq(1)
      end

      it 'has power' do
        expect(solectrus_record.power).to be > 0
      end

      it 'has a valid time' do
        expect(solectrus_record.time).to be > 1_700_000_000
      end
    end

    context 'when Shelly Pro 3EM (Gen2)' do
      let(:json) { read_json('shelly-pro-3em') }

      it { is_expected.to be_a(SolectrusRecord) }

      it 'has an automatic id' do
        expect(solectrus_record.id).to eq(1)
      end

      it 'has power' do
        expect(solectrus_record.power).to be > 0
      end

      it 'has temp' do
        expect(solectrus_record.temp).to be > 0
      end

      it 'has a valid time' do
        expect(solectrus_record.time).to be > 1_700_000_000
      end
    end

    context 'when Shelly PM Mini (Gen3)' do
      let(:json) { read_json('shelly-pm-mini-gen3') }

      it { is_expected.to be_a(SolectrusRecord) }

      it 'has an automatic id' do
        expect(solectrus_record.id).to eq(1)
      end

      it 'has power' do
        expect(solectrus_record.power).to be > 0
      end

      it 'has a valid time' do
        expect(solectrus_record.time).to be > 1_700_000_000
      end
    end

    context 'when Shelly 3EM' do
      let(:json) { read_json('shelly-3em') }

      it { is_expected.to be_a(SolectrusRecord) }

      it 'has an automatic id' do
        expect(solectrus_record.id).to eq(1)
      end

      it 'has power' do
        expect(solectrus_record.power).to be > 0
      end

      it 'has a valid time' do
        expect(solectrus_record.time).to be > 1_700_000_000
      end
    end

    context 'when Cloud' do
      let(:json) { read_json('shelly-cloud') }

      it { is_expected.to be_a(SolectrusRecord) }

      it 'has an automatic id' do
        expect(solectrus_record.id).to eq(1)
      end

      it 'has power' do
        expect(solectrus_record.power).to be > 0
      end

      it 'has temp' do
        expect(solectrus_record.temp).to be > 0
      end

      it 'has a valid time' do
        expect(solectrus_record.time).to be > 1_700_000_000
      end
    end
  end

  describe 'device_time source' do
    subject(:solectrus_record) { parser.solectrus_record }

    context 'when a V2 status carries both ts and a lagging sys.unixtime' do
      let(:json) do
        {
          'ts' => 1_780_895_614,
          'sys' => { 'unixtime' => 1_780_894_706 },
          'switch:0' => { 'apower' => 10.0 },
        }.to_json
      end

      it 'prefers the fresher cloud ts over sys.unixtime' do
        expect(solectrus_record.device_time).to eq(1_780_895_614)
      end
    end

    context 'when only sys.unixtime is present' do
      let(:json) do
        { 'sys' => { 'unixtime' => 1_780_894_706 }, 'switch:0' => { 'apower' => 10.0 } }.to_json
      end

      it 'falls back to sys.unixtime' do
        expect(solectrus_record.device_time).to eq(1_780_894_706)
      end
    end

    context 'when no timestamp is present' do
      let(:json) do
        { 'switch:0' => { 'apower' => 10.0 } }.to_json
      end

      it 'has no device_time' do
        expect(solectrus_record.device_time).to be_nil
      end
    end

    context 'when a Gen1 device without NTP sync reports unixtime 0' do
      let(:json) do
        { 'unixtime' => 0, 'meters' => [{ 'power' => 10.0 }] }.to_json
      end

      it 'treats unixtime 0 as missing' do
        expect(solectrus_record.device_time).to be_nil
      end
    end
  end

  describe 'power inversion' do
    let(:json) { read_json('shelly-plug-s-gen1') }

    context 'when invert_power is false' do
      subject(:parser) { described_class.new(json, invert_power: false) }

      it 'returns positive power value' do
        expect(parser.solectrus_record.power).to be > 0
      end
    end

    context 'when invert_power is true' do
      subject(:parser) { described_class.new(json, invert_power: true) }

      it 'returns negative power value' do
        original_power = described_class.new(json, invert_power: false).solectrus_record.power
        inverted_power = parser.solectrus_record.power

        expect(inverted_power).to eq(-original_power)
        expect(inverted_power).to be < 0
      end
    end
  end

  def read_json(cassette_name)
    cassette_path = VCR.configuration.cassette_library_dir + "/#{cassette_name}.yml"
    yaml_content = YAML.load_file(cassette_path)
    http_interactions = yaml_content['http_interactions']

    http_interactions.last.dig('response', 'body', 'string')
  end
end
