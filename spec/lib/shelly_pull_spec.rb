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
      it 'raises Shelly::Error and does not increment queue length' do
        allow(queue).to receive(:<<).and_raise(StandardError)

        expect { shelly_pull.next }.to raise_error(StandardError)
        expect(queue.length).to eq(0)
      end
    end
  end
end
