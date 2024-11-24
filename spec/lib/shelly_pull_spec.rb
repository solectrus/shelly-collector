require 'shelly_pull'
require 'config'

describe ShellyPull do
  let(:queue) { Queue.new }
  let(:config) { Config.from_env(shelly_interval: 5) }
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
        shelly_pull.next

        expect(queue.length).to eq(1)
      end
    end

    context 'when it fails' do
      it 'raises an exception and does not increment queue length' do
        allow(queue).to receive(:<<).and_raise(StandardError)

        expect { shelly_pull.next }.to raise_error(StandardError)
        expect(queue.length).to eq(0)
      end
    end

    context 'when essential mode' do
      let(:config) { Config.from_env(influx_mode: :essential) }

      it 'queues record if power is non-zero' do
        expect do
          record1 = SolectrusRecord.new(id: 1, time: 1, payload: { power: 1 })
          allow(config.adapter).to receive(:solectrus_record).and_return(record1)
          shelly_pull.next
        end.to change(queue, :length).by(1) # Because it's non-zero

        expect do
          record2 = SolectrusRecord.new(id: 2, time: 2, payload: { power: 2 })
          allow(config.adapter).to receive(:solectrus_record).and_return(record2)
          shelly_pull.next
        end.to change(queue, :length).by(1) # Because it's non-zero
      end

      it 'queues record if power just changed to zero' do
        expect do
          record1 = SolectrusRecord.new(id: 3, time: 3, payload: { power: 1 })
          allow(config.adapter).to receive(:solectrus_record).and_return(record1)
          shelly_pull.next
        end.to change(queue, :length).by(1) # Because it's non-zero

        expect do
          record2 = SolectrusRecord.new(id: 4, time: 4, payload: { power: 0 })
          allow(config.adapter).to receive(:solectrus_record).and_return(record2)
          shelly_pull.next
        end.to change(queue, :length).by(1) # Because power just changed to zero
      end

      it 'does not queue record if power is zero' do
        expect do
          record1 = SolectrusRecord.new(id: 5, time: 5, payload: { power: 0 })
          allow(config.adapter).to receive(:solectrus_record).and_return(record1)
          shelly_pull.next
        end.to change(queue, :length) # Because it's the first record

        expect do
          record2 = SolectrusRecord.new(id: 6, time: 6, payload: { power: 0 })
          allow(config.adapter).to receive(:solectrus_record).and_return(record2)
          shelly_pull.next
        end.not_to change(queue, :length) # Because power is still zero
      end

      it 'does queue last_record before non-zero' do # rubocop:disable RSpec/MultipleExpectations
        expect do
          record1 = SolectrusRecord.new(id: 7, time: 7, payload: { power: 0 })
          allow(config.adapter).to receive(:solectrus_record).and_return(record1)
          shelly_pull.next
        end.to change(queue, :length).by(1) # Because it's the first record

        expect do
          record2 = SolectrusRecord.new(id: 8, time: 8, payload: { power: 0 })
          allow(config.adapter).to receive(:solectrus_record).and_return(record2)
          shelly_pull.next
        end.not_to change(queue, :length) # Because power is zero

        expect do
          record3 = SolectrusRecord.new(id: 9, time: 9, payload: { power: 0 })
          allow(config.adapter).to receive(:solectrus_record).and_return(record3)
          shelly_pull.next
        end.not_to(change(queue, :length)) # Because power is still zero

        expect do
          record4 = SolectrusRecord.new(id: 10, time: 9, payload: { power: 1 })
          allow(config.adapter).to receive(:solectrus_record).and_return(record4)
          shelly_pull.next
        end.to change(queue, :length).by(2) # Because power is non-zero and last_record power was zero
      end
    end
  end
end
