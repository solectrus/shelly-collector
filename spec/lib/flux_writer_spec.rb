require 'flux_writer'

describe FluxWriter do
  let(:config) do
    double(
      'Config',
      influx_bucket: 'test_bucket',
      influx_org: 'test_org',
      influx_measurement: 'test_measurement',
      influx_power_data_type: power_data_type
    )
  end
  let(:power_data_type) { 'Float' }
  let(:flux_writer) { described_class.new(config) }

  describe '#point' do
    let(:record) do
      double(
        'SolectrusRecord',
        time: Time.now.to_i,
        to_hash: {
          power: 42.7,
          power_a: 10.3,
          power_b: 15.8,
          power_c: 20.1,
          temp: 25.5,
          response_duration: 1.23
        }
      )
    end

    context 'when power data type is Float' do
      let(:power_data_type) { 'Float' }

      it 'leaves all fields as their original types' do
        point = flux_writer.send(:point, record)
        
        expect(point.name).to eq('test_measurement')
        expect(point.time).to eq(record.time)
        expect(point.fields[:power]).to eq(42.7)
        expect(point.fields[:power_a]).to eq(10.3)
        expect(point.fields[:power_b]).to eq(15.8)
        expect(point.fields[:power_c]).to eq(20.1)
        expect(point.fields[:temp]).to eq(25.5)
        expect(point.fields[:response_duration]).to eq(1.23)
      end
    end

    context 'when power data type is Integer' do
      let(:power_data_type) { 'Integer' }

      it 'converts power fields to integers using round' do
        point = flux_writer.send(:point, record)
        
        expect(point.fields[:power]).to eq(43)
        expect(point.fields[:power]).to be_a(Integer)
        expect(point.fields[:power_a]).to eq(10)
        expect(point.fields[:power_a]).to be_a(Integer)
        expect(point.fields[:power_b]).to eq(16)
        expect(point.fields[:power_b]).to be_a(Integer)
        expect(point.fields[:power_c]).to eq(20)
        expect(point.fields[:power_c]).to be_a(Integer)
        
        # Non-power fields should remain as floats
        expect(point.fields[:temp]).to eq(25.5)
        expect(point.fields[:temp]).to be_a(Float)
        expect(point.fields[:response_duration]).to eq(1.23)
        expect(point.fields[:response_duration]).to be_a(Float)
      end
    end

    context 'when power field is already an integer' do
      let(:power_data_type) { 'Integer' }
      let(:record) do
        double(
          'SolectrusRecord',
          time: Time.now.to_i,
          to_hash: { power: 42, temp: 25.5 }
        )
      end

      it 'preserves the integer value' do
        point = flux_writer.send(:point, record)
        
        expect(point.fields[:power]).to eq(42)
        expect(point.fields[:power]).to be_a(Integer)
        expect(point.fields[:temp]).to eq(25.5)
        expect(point.fields[:temp]).to be_a(Float)
      end
    end

    context 'when power field is missing' do
      let(:power_data_type) { 'Integer' }
      let(:record) do
        double(
          'SolectrusRecord',
          time: Time.now.to_i,
          to_hash: { temp: 25.5 }
        )
      end

      it 'does not cause errors' do
        point = flux_writer.send(:point, record)
        
        expect(point.fields[:temp]).to eq(25.5)
        expect(point.fields).not_to have_key(:power)
      end
    end
  end
end