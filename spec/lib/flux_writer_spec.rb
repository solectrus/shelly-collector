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

  describe '#point' do
    let(:record) do
      SolectrusRecord.new(
        id: 1,
        time: Time.now.to_i,
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
        point = flux_writer.send(:point, record)
        line_protocol = point.to_line_protocol

        expect(line_protocol).to include('test_measurement')
        expect(line_protocol).to include(record.time.to_s)
      end

      it 'leaves power fields as floats' do
        point = flux_writer.send(:point, record)
        line_protocol = point.to_line_protocol

        expect(line_protocol).to include('power=42.7')
        expect(line_protocol).to include('power_a=10.3')
        expect(line_protocol).to include('power_b=15.8')
        expect(line_protocol).to include('power_c=20.1')
      end

      it 'leaves non-power fields as floats' do
        point = flux_writer.send(:point, record)
        line_protocol = point.to_line_protocol

        expect(line_protocol).to include('temp=25.5')
        expect(line_protocol).to include('response_duration=1.23')
      end
    end

    context 'when power data type is Integer' do
      let(:power_data_type) { 'Integer' }

      it 'converts power fields to integers using round' do
        point = flux_writer.send(:point, record)
        line_protocol = point.to_line_protocol

        # Power fields should be converted to integers (note the 'i' suffix in line protocol)
        expect(line_protocol).to include('power=43i') # 42.7 rounded to 43
        expect(line_protocol).to include('power_a=10i') # 10.3 rounded to 10
        expect(line_protocol).to include('power_b=16i') # 15.8 rounded to 16
        expect(line_protocol).to include('power_c=20i') # 20.1 rounded to 20
      end

      it 'keeps non-power fields as floats' do
        point = flux_writer.send(:point, record)
        line_protocol = point.to_line_protocol

        # Non-power fields should remain as floats (no 'i' suffix)
        expect(line_protocol).to include('temp=25.5')
        expect(line_protocol).to include('response_duration=1.23')
      end
    end

    context 'when power field is already an integer' do
      let(:power_data_type) { 'Integer' }
      let(:record) do
        SolectrusRecord.new(
          id: 2,
          time: Time.now.to_i,
          payload: { power: 42, temp: 25.5 },
        )
      end

      it 'preserves the integer value' do
        point = flux_writer.send(:point, record)
        line_protocol = point.to_line_protocol

        expect(line_protocol).to include('power=42i')
        expect(line_protocol).to include('temp=25.5')
      end
    end

    context 'when power field is missing' do
      let(:power_data_type) { 'Integer' }
      let(:record) do
        SolectrusRecord.new(
          id: 3,
          time: Time.now.to_i,
          payload: { temp: 25.5 },
        )
      end

      it 'does not cause errors' do
        point = flux_writer.send(:point, record)
        line_protocol = point.to_line_protocol

        expect(line_protocol).to include('temp=25.5')
        expect(line_protocol).not_to include('power=')
      end
    end
  end
end
