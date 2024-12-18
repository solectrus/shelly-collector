require 'solectrus_record'

describe SolectrusRecord do
  subject(:record) { described_class.new(id: 1, time: Time.now, payload:) }

  let(:payload) do
    {
      temp: 25.5,
      power: 0.0,
      power_a: 10.2,
      power_b: 20.5,
      power_c: 30.3,
      response_duration: 20.5,
    }
  end

  describe '#initialize' do
    it 'assigns id and time' do
      expect(record.id).to eq(1)
      expect(record.time).to be_a(Time)
    end
  end

  describe '#to_hash' do
    it 'returns the payload hash' do
      expect(record.to_hash).to eq(payload)
    end
  end

  describe '#power?' do
    context 'when power is zero' do
      it 'returns false' do
        expect(record.power?).to be(false)
      end
    end

    context 'when power is non-zero' do
      let(:payload) { super().merge(power: 42) }

      it 'returns true' do
        expect(record.power?).to be(true)
      end
    end
  end

  %i[temp power power_a power_b power_c response_duration].each do |method|
    describe "##{method}" do
      it "returns the value of #{method} from the payload" do
        expect(record.send(method)).to eq(payload[method])
      end
    end
  end
end
