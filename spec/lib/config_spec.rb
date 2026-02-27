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
      expect { described_class.new }.to raise_error(Exception)
    end

    it 'raises an error for invalid INFLUX_SCHEMA' do
      expect do
        described_class.new(**valid_options, influx_schema: 'foo')
      end.to raise_error(Exception, /URL is invalid/)
    end

    it 'raises an error for missing INFLUX_HOST' do
      expect do
        described_class.new(**valid_options, influx_host: nil)
      end.to raise_error(Exception, /INFLUX_HOST is missing/)
    end

    it 'raises an error for missing INFLUX_ORG' do
      expect do
        described_class.new(**valid_options, influx_org: nil)
      end.to raise_error(Exception, /INFLUX_ORG is missing/)
    end

    it 'raises an error for missing INFLUX_BUCKET' do
      expect do
        described_class.new(**valid_options, influx_bucket: nil)
      end.to raise_error(Exception, /INFLUX_BUCKET is missing/)
    end

    it 'raises an error for missing INFLUX_TOKEN' do
      expect do
        described_class.new(**valid_options, influx_token: nil)
      end.to raise_error(Exception, /INFLUX_TOKEN is missing/)
    end

    it 'raises an error for invalid INFLUX_MODE' do
      expect do
        described_class.new(**valid_options, influx_mode: 'foo')
      end.to raise_error(Exception, /MODE is invalid/)
    end

    it 'initializes with valid options' do
      expect { described_class.new(**valid_options) }.not_to raise_error
    end

    it 'limits shelly_interval' do
      config = described_class.new(**valid_options, shelly_interval: 1)

      expect(config.shelly_interval).to eq(2)
    end
  end

  describe 'influx methods' do
    subject(:config) { described_class.new(**valid_options) }

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

  describe '#device_configs' do
    context 'with single cloud device' do
      subject(:config) do
        described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'abc123',
        )
      end

      it 'returns array with one DeviceConfig' do
        expect(config.device_configs.size).to eq(1)
        expect(config.device_configs.first.device_id).to eq('abc123')
      end

      it 'uses influx_measurement as measurement' do
        expect(config.device_configs.first.measurement).to eq('Consumer')
      end

      it 'defaults invert_power to false' do
        expect(config.device_configs.first.invert_power).to be(false)
      end
    end

    context 'with single local device' do
      subject(:config) { described_class.new(**valid_options) }

      it 'returns array with one DeviceConfig' do
        expect(config.device_configs.size).to eq(1)
        expect(config.device_configs.first.host).to eq('1.2.3.4')
      end

      it 'uses influx_measurement as measurement' do
        expect(config.device_configs.first.measurement).to eq('Consumer')
      end
    end

    context 'with multiple devices' do
      subject(:config) { described_class.new(**multi_options) }

      let(:multi_options) do
        valid_influx_options.merge(
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2,dev3',
          influx_measurement: 'meter1,meter2,meter3',
        )
      end

      it 'returns array with three DeviceConfigs' do
        expect(config.device_configs.size).to eq(3)
      end

      it 'parses device IDs correctly' do
        expect(config.device_configs.map(&:device_id)).to eq(%w[dev1 dev2 dev3])
      end

      it 'parses measurements correctly' do
        expect(config.device_configs.map(&:measurement)).to eq(%w[meter1 meter2 meter3])
      end

      it 'defaults all invert_power to false' do
        expect(config.device_configs.map(&:invert_power)).to eq([false, false, false])
      end
    end

    context 'with per-device influx_mode' do
      it 'defaults all to :default when not set' do
        config = described_class.new(
          **valid_influx_options.except(:influx_mode),
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2',
          influx_measurement: 'meter1,meter2',
        )

        expect(config.device_configs.map(&:influx_mode)).to eq(%i[default default])
      end

      it 'parses single value for all devices' do
        config = described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2',
          influx_measurement: 'meter1,meter2',
          influx_mode: :essential,
        )

        expect(config.device_configs.map(&:influx_mode)).to eq(%i[essential essential])
      end

      it 'parses comma-separated values' do
        config = described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2,dev3',
          influx_measurement: 'meter1,meter2,meter3',
          influx_mode: 'essential,default,essential',
        )

        expect(config.device_configs.map(&:influx_mode)).to eq(%i[essential default essential])
      end
    end

    context 'with per-device influx_power_data_type' do
      it 'defaults all to Float' do
        config = described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2',
          influx_measurement: 'meter1,meter2',
        )

        expect(config.device_configs.map(&:influx_power_data_type)).to eq(%w[Float Float])
      end

      it 'parses single value for all devices' do
        config = described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2',
          influx_measurement: 'meter1,meter2',
          influx_power_data_type: 'Integer',
        )

        expect(config.device_configs.map(&:influx_power_data_type)).to eq(%w[Integer Integer])
      end

      it 'parses comma-separated values' do
        config = described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2,dev3',
          influx_measurement: 'meter1,meter2,meter3',
          influx_power_data_type: 'Float,Integer,Float',
        )

        expect(config.device_configs.map(&:influx_power_data_type)).to eq(%w[Float Integer Float])
      end
    end

    context 'with invert_power' do
      it 'parses single true value for all devices' do
        config = described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2',
          influx_measurement: 'meter1,meter2',
          shelly_invert_power: 'true',
        )

        expect(config.device_configs.map(&:invert_power)).to eq([true, true])
      end

      it 'parses comma-separated values' do
        config = described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2,dev3',
          influx_measurement: 'meter1,meter2,meter3',
          shelly_invert_power: 'false,true,false',
        )

        expect(config.device_configs.map(&:invert_power)).to eq([false, true, false])
      end
    end

    context 'with multiple local devices' do
      subject(:config) do
        described_class.new(
          **valid_influx_options,
          shelly_host: '192.168.1.10,192.168.1.20,192.168.1.30',
          shelly_password: 'pass1,,pass3',
          influx_measurement: 'meter1,meter2,meter3',
        )
      end

      it 'returns array with three DeviceConfigs' do
        expect(config.device_configs.size).to eq(3)
      end

      it 'parses hosts correctly' do
        expect(config.device_configs.map(&:host)).to eq(%w[192.168.1.10 192.168.1.20 192.168.1.30])
      end

      it 'parses passwords correctly' do
        expect(config.device_configs.map(&:password)).to eq(['pass1', nil, 'pass3'])
      end

      it 'sets device_id to nil for all' do
        expect(config.device_configs.map(&:device_id)).to eq([nil, nil, nil])
      end

      it 'parses measurements correctly' do
        expect(config.device_configs.map(&:measurement)).to eq(%w[meter1 meter2 meter3])
      end
    end

    context 'with single local device and password' do
      subject(:config) do
        described_class.new(
          **valid_influx_options,
          shelly_host: '192.168.1.10',
          shelly_password: 'secret',
        )
      end

      it 'returns array with one DeviceConfig' do
        expect(config.device_configs.size).to eq(1)
      end

      it 'sets host correctly' do
        expect(config.device_configs.first.host).to eq('192.168.1.10')
      end

      it 'sets password correctly' do
        expect(config.device_configs.first.password).to eq('secret')
      end
    end
  end

  describe '#multi_device?' do
    it 'returns false for single device' do
      config = described_class.new(**valid_options, shelly_device_id: 'abc123')
      expect(config.multi_device?).to be(false)
    end

    it 'returns true for multiple cloud devices' do
      config = described_class.new(
        **valid_influx_options,
        shelly_cloud_server: 'https://shelly.cloud',
        shelly_auth_key: 'key',
        shelly_device_id: 'dev1,dev2',
        influx_measurement: 'meter1,meter2',
      )
      expect(config.multi_device?).to be(true)
    end

    it 'returns true for multiple local devices' do
      config = described_class.new(
        **valid_influx_options,
        shelly_host: '192.168.1.10,192.168.1.20',
        influx_measurement: 'meter1,meter2',
      )
      expect(config.multi_device?).to be(true)
    end
  end

  describe 'multi-device validation' do
    it 'raises error when device count does not match measurement count' do
      expect do
        described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2,dev3',
          influx_measurement: 'meter1,meter2',
        )
      end.to raise_error(Exception, /SHELLY_DEVICE_ID count .* must match INFLUX_MEASUREMENT count/)
    end

    it 'raises error when both SHELLY_HOST and SHELLY_CLOUD_SERVER are set (multi-device)' do
      expect do
        described_class.new(
          **valid_influx_options,
          shelly_host: '1.2.3.4',
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2',
          influx_measurement: 'meter1,meter2',
        )
      end.to raise_error(Exception, /Cannot use both SHELLY_HOST and SHELLY_CLOUD_SERVER/)
    end

    it 'raises error when both SHELLY_HOST and SHELLY_CLOUD_SERVER are set (single-device)' do
      expect do
        described_class.new(
          **valid_influx_options,
          shelly_host: '1.2.3.4',
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1',
        )
      end.to raise_error(Exception, /Cannot use both SHELLY_HOST and SHELLY_CLOUD_SERVER/)
    end

    it 'raises error when invert_power count does not match' do
      expect do
        described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2,dev3',
          influx_measurement: 'meter1,meter2,meter3',
          shelly_invert_power: 'true,false',
        )
      end.to raise_error(Exception, /SHELLY_INVERT_POWER count .* must match/)
    end

    it 'raises error when influx_mode count does not match' do
      expect do
        described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2,dev3',
          influx_measurement: 'meter1,meter2,meter3',
          influx_mode: 'essential,default',
        )
      end.to raise_error(Exception, /INFLUX_MODE count .* must match/)
    end

    it 'raises error when influx_power_data_type count does not match' do
      expect do
        described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2,dev3',
          influx_measurement: 'meter1,meter2,meter3',
          influx_power_data_type: 'Float,Integer',
        )
      end.to raise_error(Exception, /INFLUX_POWER_DATA_TYPE count .* must match/)
    end

    it 'accepts single invert_power value for multiple devices' do
      expect do
        described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2',
          influx_measurement: 'meter1,meter2',
          shelly_invert_power: 'true',
        )
      end.not_to raise_error
    end

    it 'allows multi-device with SHELLY_HOST only' do
      expect do
        described_class.new(
          **valid_influx_options,
          shelly_host: '192.168.1.10,192.168.1.20',
          influx_measurement: 'meter1,meter2',
        )
      end.not_to raise_error
    end

    it 'raises error when local host count does not match measurement count' do
      expect do
        described_class.new(
          **valid_influx_options,
          shelly_host: '192.168.1.10,192.168.1.20,192.168.1.30',
          influx_measurement: 'meter1,meter2',
        )
      end.to raise_error(Exception, /SHELLY_HOST count .* must match INFLUX_MEASUREMENT count/)
    end

    it 'raises error when password count does not match host count' do
      expect do
        described_class.new(
          **valid_influx_options,
          shelly_host: '192.168.1.10,192.168.1.20,192.168.1.30',
          shelly_password: 'p1,p2',
          influx_measurement: 'meter1,meter2,meter3',
        )
      end.to raise_error(Exception, /SHELLY_PASSWORD count .* must match SHELLY_HOST count/)
    end

    it 'accepts single password for multiple local devices' do
      expect do
        described_class.new(
          **valid_influx_options,
          shelly_host: '192.168.1.10,192.168.1.20',
          shelly_password: 'secret',
          influx_measurement: 'meter1,meter2',
        )
      end.not_to raise_error
    end
  end

  describe '#device_config_for' do
    subject(:config) do
      described_class.new(
        **valid_influx_options,
        shelly_cloud_server: 'https://shelly.cloud',
        shelly_auth_key: 'key',
        shelly_device_id: 'dev1,dev2',
        influx_measurement: 'meter1,meter2',
        influx_mode: 'essential,default',
        influx_power_data_type: 'Float,Integer',
      )
    end

    it 'finds device config by measurement' do
      dc = config.device_config_for('meter2')
      expect(dc.device_id).to eq('dev2')
      expect(dc.influx_mode).to eq(:default)
      expect(dc.influx_power_data_type).to eq('Integer')
    end

    it 'falls back to first device config for unknown measurement' do
      dc = config.device_config_for('unknown')
      expect(dc.device_id).to eq('dev1')
    end

    it 'falls back to first device config for nil measurement' do
      dc = config.device_config_for(nil)
      expect(dc.device_id).to eq('dev1')
    end
  end

  describe '#log_config' do
    let(:logger) { MemoryLogger.new }

    context 'with single local device' do
      it 'logs Device (singular) with local mode' do
        config = described_class.new(**valid_options)
        config.logger = logger
        config.log_config

        output = logger.info_messages.join("\n")
        expect(output).to include('InfluxDB at http://influx.example.com:8086, bucket Consumer')
        expect(output).to include('Device (local, every 5s):')
        expect(output).to include('http://1.2.3.4 => Consumer')
      end
    end

    context 'with multiple local devices' do
      let(:output) do
        config = described_class.new(
          **valid_influx_options,
          shelly_host: '192.168.1.10,192.168.1.20',
          influx_measurement: 'meter1,meter2',
        )
        config.logger = logger
        config.log_config
        logger.info_messages.join("\n")
      end

      it 'logs Devices header' do
        expect(output).to include('Devices (local, every 5s):')
      end

      it 'logs all device URLs and measurements' do
        expect(output).to include('http://192.168.1.10')
          .and include('=> meter1')
          .and include('http://192.168.1.20')
          .and include('=> meter2')
      end
    end

    context 'with cloud devices' do
      it 'logs cloud mode with server URL' do
        config = described_class.new(
          **valid_influx_options,
          shelly_cloud_server: 'https://shelly-eu1.shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2',
          influx_measurement: 'meter1,meter2',
        )
        config.logger = logger
        config.log_config

        output = logger.info_messages.join("\n")
        expect(output).to include('Devices (cloud via https://shelly-eu1.shelly.cloud, every 5s):')
        expect(output).to include('dev1')
        expect(output).to include('=> meter1')
      end
    end

    context 'with device flags' do
      it 'shows inverted and auth flags' do
        config = described_class.new(
          **valid_influx_options,
          shelly_host: '192.168.1.10,192.168.1.20',
          shelly_password: 'secret,',
          shelly_invert_power: 'true,false',
          influx_measurement: 'meter1,meter2',
          influx_mode: 'essential,default',
          influx_power_data_type: 'Integer,Float',
        )
        config.logger = logger
        config.log_config

        output = logger.info_messages.join("\n")
        expect(output).to include('=> meter1 (inverted, auth, essential, Integer)')
        expect(output).to include('=> meter2 (no auth)')
      end
    end
  end

  describe 'influx_power_data_type validation' do
    it 'accepts Float as data type' do
      config = described_class.new(**valid_options, influx_power_data_type: 'Float')

      expect(config.influx_power_data_type).to eq('Float')
    end

    it 'accepts Integer as data type' do
      config = described_class.new(**valid_options, influx_power_data_type: 'Integer')

      expect(config.influx_power_data_type).to eq('Integer')
    end

    it 'raises error for invalid data type' do
      expect do
        described_class.new(**valid_options, influx_power_data_type: 'Invalid')
      end.to raise_error(Exception, /INFLUX_POWER_DATA_TYPE is invalid/)
    end
  end
end
