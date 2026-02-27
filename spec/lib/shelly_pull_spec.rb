require 'shelly_pull'
require 'config'

describe ShellyPull do
  let(:queue) { Queue.new }
  let(:config) { Config.from_env(shelly_cloud_server: nil, shelly_interval: 5) }
  let(:shelly_pull) do
    described_class.new(config:, queue:)
  end

  let(:logger) { MemoryLogger.new }

  before do
    config.logger = logger
  end

  describe '#next' do
    context 'when successful' do
      it 'increments the queue length' do
        record = SolectrusRecord.new(id: 1, time: 1, payload: { power: 1 })
        allow(config.adapter).to receive(:solectrus_records).and_return([record])

        shelly_pull.next

        expect(queue.length).to eq(1)
      end
    end

    context 'when adapter returns empty array' do
      it 'does not increment queue length' do
        allow(config.adapter).to receive(:solectrus_records).and_return([])

        shelly_pull.next

        expect(queue.length).to eq(0)
      end
    end

    context 'when queue raises an error' do
      it 'raises an exception and does not increment queue length' do
        record = SolectrusRecord.new(id: 1, time: 1, payload: { power: 1 })
        allow(config.adapter).to receive(:solectrus_records).and_return([record])
        allow(queue).to receive(:<<).and_raise(StandardError)

        expect { shelly_pull.next }.to raise_error(StandardError)
        expect(queue.length).to eq(0)
      end
    end

    context 'when essential mode' do
      let(:config) { Config.from_env(shelly_cloud_server: nil, influx_mode: :essential) }

      it 'queues record if power is non-zero' do
        expect do
          record1 = SolectrusRecord.new(id: 1, time: 1, payload: { power: 1 })
          allow(config.adapter).to receive(:solectrus_records).and_return([record1])
          shelly_pull.next
        end.to change(queue, :length).by(1) # Because it's non-zero

        expect do
          record2 = SolectrusRecord.new(id: 2, time: 2, payload: { power: 2 })
          allow(config.adapter).to receive(:solectrus_records).and_return([record2])
          shelly_pull.next
        end.to change(queue, :length).by(1) # Because it's non-zero
      end

      it 'queues record if power just changed to zero' do
        expect do
          record1 = SolectrusRecord.new(id: 3, time: 3, payload: { power: 1 })
          allow(config.adapter).to receive(:solectrus_records).and_return([record1])
          shelly_pull.next
        end.to change(queue, :length).by(1) # Because it's non-zero

        expect do
          record2 = SolectrusRecord.new(id: 4, time: 4, payload: { power: 0 })
          allow(config.adapter).to receive(:solectrus_records).and_return([record2])
          shelly_pull.next
        end.to change(queue, :length).by(1) # Because power just changed to zero
      end

      it 'does not queue record if power is zero' do
        expect do
          record1 = SolectrusRecord.new(id: 5, time: 5, payload: { power: 0 })
          allow(config.adapter).to receive(:solectrus_records).and_return([record1])
          shelly_pull.next
        end.to change(queue, :length) # Because it's the first record

        expect do
          record2 = SolectrusRecord.new(id: 6, time: 6, payload: { power: 0 })
          allow(config.adapter).to receive(:solectrus_records).and_return([record2])
          shelly_pull.next
        end.not_to change(queue, :length) # Because power is still zero
      end

      it 'does queue last_record before non-zero' do
        expect do
          record1 = SolectrusRecord.new(id: 7, time: 7, payload: { power: 0 })
          allow(config.adapter).to receive(:solectrus_records).and_return([record1])
          shelly_pull.next
        end.to change(queue, :length).by(1) # Because it's the first record

        expect do
          record2 = SolectrusRecord.new(id: 8, time: 8, payload: { power: 0 })
          allow(config.adapter).to receive(:solectrus_records).and_return([record2])
          shelly_pull.next
        end.not_to change(queue, :length) # Because power is zero

        expect do
          record3 = SolectrusRecord.new(id: 9, time: 9, payload: { power: 0 })
          allow(config.adapter).to receive(:solectrus_records).and_return([record3])
          shelly_pull.next
        end.not_to(change(queue, :length)) # Because power is still zero

        expect do
          record4 = SolectrusRecord.new(id: 10, time: 9, payload: { power: 1 })
          allow(config.adapter).to receive(:solectrus_records).and_return([record4])
          shelly_pull.next
        end.to change(queue, :length).by(2) # Because power is non-zero and last_record power was zero
      end
    end

    context 'when multi-device' do
      let(:config) do
        Config.new(
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2',
          influx_host: 'localhost',
          influx_token: 'token',
          influx_org: 'org',
          influx_bucket: 'bucket',
          influx_measurement: 'meter1,meter2',
        )
      end

      it 'queues all records from batch' do
        records = [
          SolectrusRecord.new(id: 1, time: 1, payload: { power: 100 }, measurement: 'meter1'),
          SolectrusRecord.new(id: 1, time: 1, payload: { power: 200 }, measurement: 'meter2'),
        ]
        allow(config.adapter).to receive(:solectrus_records).and_return(records)

        shelly_pull.next

        expect(queue.length).to eq(2)
      end

      it 'handles empty batch response' do
        allow(config.adapter).to receive(:solectrus_records).and_return([])

        shelly_pull.next

        expect(queue.length).to eq(0)
      end
    end

    context 'when multi-device essential mode' do
      let(:config) do
        Config.new(
          shelly_cloud_server: 'https://shelly.cloud',
          shelly_auth_key: 'key',
          shelly_device_id: 'dev1,dev2',
          influx_host: 'localhost',
          influx_token: 'token',
          influx_org: 'org',
          influx_bucket: 'bucket',
          influx_measurement: 'meter1,meter2',
          influx_mode: :essential,
        )
      end

      it 'queues records when devices have power' do
        records = [
          SolectrusRecord.new(id: 1, time: 1, payload: { power: 100 }, measurement: 'meter1'),
          SolectrusRecord.new(id: 1, time: 1, payload: { power: 200 }, measurement: 'meter2'),
        ]
        allow(config.adapter).to receive(:solectrus_records).and_return(records)
        shelly_pull.next
        expect(queue.length).to eq(2)
      end

      it 'queues zero transition for one device while other stays active' do
        records1 = [
          SolectrusRecord.new(id: 1, time: 1, payload: { power: 100 }, measurement: 'meter1'),
          SolectrusRecord.new(id: 1, time: 1, payload: { power: 200 }, measurement: 'meter2'),
        ]
        allow(config.adapter).to receive(:solectrus_records).and_return(records1)
        shelly_pull.next

        records2 = [
          SolectrusRecord.new(id: 2, time: 2, payload: { power: 0 }, measurement: 'meter1'),
          SolectrusRecord.new(id: 2, time: 2, payload: { power: 150 }, measurement: 'meter2'),
        ]
        allow(config.adapter).to receive(:solectrus_records).and_return(records2)
        shelly_pull.next
        expect(queue.length).to eq(4) # +1 for meter1 (zero transition), +1 for meter2
      end

      it 'skips consecutive zero records per device independently' do
        records1 = [
          SolectrusRecord.new(id: 1, time: 1, payload: { power: 100 }, measurement: 'meter1'),
          SolectrusRecord.new(id: 1, time: 1, payload: { power: 200 }, measurement: 'meter2'),
        ]
        allow(config.adapter).to receive(:solectrus_records).and_return(records1)
        shelly_pull.next

        records2 = [
          SolectrusRecord.new(id: 2, time: 2, payload: { power: 0 }, measurement: 'meter1'),
          SolectrusRecord.new(id: 2, time: 2, payload: { power: 0 }, measurement: 'meter2'),
        ]
        allow(config.adapter).to receive(:solectrus_records).and_return(records2)
        shelly_pull.next

        records3 = [
          SolectrusRecord.new(id: 3, time: 3, payload: { power: 0 }, measurement: 'meter1'),
          SolectrusRecord.new(id: 3, time: 3, payload: { power: 0 }, measurement: 'meter2'),
        ]
        allow(config.adapter).to receive(:solectrus_records).and_return(records3)
        shelly_pull.next
        expect(queue.length).to eq(4) # Only zero transitions queued, consecutive zeros skipped
      end
    end
  end
end
