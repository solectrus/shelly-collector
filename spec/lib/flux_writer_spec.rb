require 'flux_writer'

describe FluxWriter do
  let(:config) do
    double(
      'Config',
      influx_bucket: 'test_bucket',
      influx_org: 'test_org',
      influx_measurement: 'test_measurement',
      influx_integer_fields: integer_fields
    )
  end
  let(:integer_fields) { [] }
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
          temp: 25.5
        }
      )
    end

    context 'when no integer fields are specified' do
      let(:integer_fields) { [] }

      it 'leaves all fields as their original types' do
        point = flux_writer.send(:point, record)
        
        expect(point.name).to eq('test_measurement')
        expect(point.time).to eq(record.time)
        expect(point.fields[:power]).to eq(42.7)
        expect(point.fields[:power_a]).to eq(10.3)
        expect(point.fields[:temp]).to eq(25.5)
      end
    end

    context 'when integer fields are specified' do
      let(:integer_fields) { ['power', 'power_a'] }

      it 'converts specified fields to integers' do
        point = flux_writer.send(:point, record)
        
        expect(point.fields[:power]).to eq(42)
        expect(point.fields[:power]).to be_a(Integer)
        expect(point.fields[:power_a]).to eq(10)
        expect(point.fields[:power_a]).to be_a(Integer)
        expect(point.fields[:power_b]).to eq(15.8)
        expect(point.fields[:power_b]).to be_a(Float)
        expect(point.fields[:temp]).to eq(25.5)
        expect(point.fields[:temp]).to be_a(Float)
      end
    end

    context 'when non-existent field names are specified' do
      let(:integer_fields) { ['nonexistent_field'] }

      it 'does not cause errors and preserves original data' do
        point = flux_writer.send(:point, record)
        
        expect(point.fields[:power]).to eq(42.7)
        expect(point.fields[:temp]).to eq(25.5)
      end
    end

    context 'when field is already an integer' do
      let(:integer_fields) { ['power'] }
      let(:record) do
        double(
          'SolectrusRecord',
          time: Time.now.to_i,
          to_hash: { power: 42 }
        )
      end

      it 'preserves the integer value' do
        point = flux_writer.send(:point, record)
        
        expect(point.fields[:power]).to eq(42)
        expect(point.fields[:power]).to be_a(Integer)
      end
    end
  end
end