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
        expect(solectrus_record.power).to be > 0
      end

      it 'has temp' do
        expect(solectrus_record.temp).to be > 0
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

  def read_json(cassette_name)
    cassette_path = VCR.configuration.cassette_library_dir + "/#{cassette_name}.yml"
    yaml_content = YAML.load_file(cassette_path)
    http_interactions = yaml_content['http_interactions']

    http_interactions.last.dig('response', 'body', 'string')
  end
end
