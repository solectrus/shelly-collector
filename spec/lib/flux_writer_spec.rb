require 'flux_writer'
require 'config'

describe FluxWriter do
  let(:config) do
    instance_double(
      Config,
      influx_bucket: 'test_bucket',
      influx_org: 'test_org',
      influx_measurement: 'test_measurement',
      influx_power_data_type: power_data_type,
    )
  end
  let(:power_data_type) { 'Float' }
  let(:flux_writer) { described_class.new(config) }

  describe '#line_protocol' do
    let(:record) do
      SolectrusRecord.new(
        id: 1,
        time: 1_700_000_000,
        payload: {
          power: 42.7,
          power_a: 10.3,
          power_b: 15.8,
          power_c: 20.1,
          temp: 25.5,
          response_duration: 1.23,
        },
      )
    end

    context 'when power data type is Float' do
      let(:power_data_type) { 'Float' }

      it 'includes the correct measurement name and timestamp' do
        result = flux_writer.send(:line_protocol, record)

        expect(result).to start_with('test_measurement ')
        expect(result).to end_with(' 1700000000')
      end

      it 'leaves power fields as floats' do
        result = flux_writer.send(:line_protocol, record)

        expect(result).to include('power=42.7')
        expect(result).to include('power_a=10.3')
        expect(result).to include('power_b=15.8')
        expect(result).to include('power_c=20.1')
      end

      it 'leaves non-power fields as floats' do
        result = flux_writer.send(:line_protocol, record)

        expect(result).to include('temp=25.5')
        expect(result).to include('response_duration=1.23')
      end
    end

    context 'when power data type is Integer' do
      let(:power_data_type) { 'Integer' }

      it 'converts power fields to integers using round' do
        result = flux_writer.send(:line_protocol, record)

        expect(result).to include('power=43i')
        expect(result).to include('power_a=10i')
        expect(result).to include('power_b=16i')
        expect(result).to include('power_c=20i')
      end

      it 'keeps non-power fields as floats' do
        result = flux_writer.send(:line_protocol, record)

        expect(result).to include('temp=25.5')
        expect(result).to include('response_duration=1.23')
      end
    end

    context 'when power field is already an integer' do
      let(:power_data_type) { 'Integer' }
      let(:record) do
        SolectrusRecord.new(
          id: 2,
          time: 1_700_000_000,
          payload: { power: 42, temp: 25.5 },
        )
      end

      it 'preserves the integer value' do
        result = flux_writer.send(:line_protocol, record)

        expect(result).to include('power=42i')
        expect(result).to include('temp=25.5')
      end
    end

    context 'when power field is missing' do
      let(:power_data_type) { 'Integer' }
      let(:record) do
        SolectrusRecord.new(
          id: 3,
          time: 1_700_000_000,
          payload: { temp: 25.5 },
        )
      end

      it 'does not cause errors' do
        result = flux_writer.send(:line_protocol, record)

        expect(result).to include('temp=25.5')
        expect(result).not_to include('power=')
      end
    end
  end
end
