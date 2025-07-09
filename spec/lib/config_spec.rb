require 'config'

describe Config do
  let(:valid_influx_options) do
    {
      influx_host: 'influx.example.com',
      influx_token: 'this.is.just.an.example',
      influx_org: 'solectrus',
      influx_bucket: 'Consumer',
      influx_mode: :essential,
    }
  end

  let(:valid_options) do
    valid_influx_options.merge(
      shelly_host: '1.2.3.4',
    )
  end

  describe '#initialize' do
    it 'raises an error for empty options' do
      expect { described_class.new({}) }.to raise_error(Exception)
    end

    it 'raises an error for invalid INFLUX_SCHEMA' do
      expect do
        described_class.new(valid_options.merge(influx_schema: 'foo'))
      end.to raise_error(Exception, /URL is invalid/)
    end

    it 'raises an error for missing INFLUX_HOST' do
      expect do
        described_class.new(valid_options.merge(influx_host: nil))
      end.to raise_error(Exception, /INFLUX_HOST is missing/)
    end

    it 'raises an error for missing INFLUX_ORG' do
      expect do
        described_class.new(valid_options.merge(influx_org: nil))
      end.to raise_error(Exception, /INFLUX_ORG is missing/)
    end

    it 'raises an error for missing INFLUX_BUCKET' do
      expect do
        described_class.new(valid_options.merge(influx_bucket: nil))
      end.to raise_error(Exception, /INFLUX_BUCKET is missing/)
    end

    it 'raises an error for missing INFLUX_TOKEN' do
      expect do
        described_class.new(valid_options.merge(influx_token: nil))
      end.to raise_error(Exception, /INFLUX_TOKEN is missing/)
    end

    it 'raises an error for invalid INFLUX_MODE' do
      expect do
        described_class.new(valid_options.merge(influx_mode: 'foo'))
      end.to raise_error(Exception, /MODE is invalid/)
    end

    it 'initializes with valid options' do
      expect { described_class.new(valid_options) }.not_to raise_error
    end

    it 'limits shelly_interval' do
      config = described_class.new(valid_options.merge(shelly_interval: 1))

      expect(config.shelly_interval).to eq(2)
    end
  end

  describe 'influx methods' do
    subject(:config) { described_class.new(valid_options) }

    it 'returns correct influx_host' do
      expect(config.influx_host).to eq('influx.example.com')
    end

    it 'returns correct influx_schema' do
      expect(config.influx_schema).to eq(:http)
    end

    it 'returns default influx_port' do
      expect(config.influx_port).to eq(8086)
    end

    it 'returns correct influx_token' do
      expect(config.influx_token).to eq('this.is.just.an.example')
    end

    it 'returns correct influx_org' do
      expect(config.influx_org).to eq('solectrus')
    end

    it 'returns correct influx_bucket' do
      expect(config.influx_bucket).to eq('Consumer')
    end

    it 'returns correct influx_measurement' do
      expect(config.influx_measurement).to eq('Consumer')
    end

    it 'returns correct influx_mode' do
      expect(config.influx_mode).to eq(:essential)
    end

    it 'returns default Float for influx_power_data_type' do
      expect(config.influx_power_data_type).to eq('Float')
    end
  end

  describe 'influx_power_data_type validation' do
    it 'accepts Float as data type' do
      config = described_class.new(valid_options.merge(influx_power_data_type: 'Float'))

      expect(config.influx_power_data_type).to eq('Float')
    end

    it 'accepts Integer as data type' do
      config = described_class.new(valid_options.merge(influx_power_data_type: 'Integer'))

      expect(config.influx_power_data_type).to eq('Integer')
    end

    it 'raises error for invalid data type' do
      expect do
        described_class.new(valid_options.merge(influx_power_data_type: 'Invalid'))
      end.to raise_error(Exception, /INFLUX_POWER_DATA_TYPE is invalid/)
    end
  end
end
