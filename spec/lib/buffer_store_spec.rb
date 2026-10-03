require 'buffer_store'
require 'tmpdir'

describe BufferStore do
  subject(:store) { described_class.new(logger:, path:) }

  let(:logger) { MemoryLogger.new }
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'data', 'buffer.jsonl') }

  let(:records) do
    [1, 2].map do |id|
      SolectrusRecord.new(
        id:,
        time: 1_700_000_000 + id,
        payload: { power: 42.0, power_a: 10, temp: 25.5, response_duration: 12 },
        measurement: "meter#{id}",
        device_time: 1_700_000_000,
      )
    end
  end

  after { FileUtils.remove_entry(dir) }

  describe '#save and #load' do
    it 'restores the records with the same values and types' do
      store.save(records)
      restored = store.load

      attributes = ->(record) { [record.id, record.time, record.measurement, record.to_hash] }
      expect(restored.map(&attributes)).to eq(records.map(&attributes))
      expect([restored.first.power, restored.first.power_a]).to match([kind_of(Float), kind_of(Integer)])
    end

    it 'deletes the file after loading' do
      store.save(records)
      store.load

      expect(File.exist?(path)).to be(false)
    end

    it 'logs the number of records' do
      store.save(records)
      store.load

      expect(logger.info_messages).to include(/Saved 2 buffered records/, /Restored 2 buffered records/)
    end
  end

  describe '#save' do
    it 'does not create a file without records' do
      store.save([])

      expect(File.exist?(path)).to be(false)
    end

    it 'logs an error if the file cannot be written' do
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.chmod(0o500, File.dirname(path))

      store.save(records)

      expect(logger.error_messages).to include(/Could not save 2 buffered records/)
    ensure
      FileUtils.chmod(0o700, File.dirname(path))
    end
  end

  describe '#load' do
    it 'returns nothing if there is no file' do
      expect(store.load).to eq([])
    end

    it 'skips invalid lines' do
      store.save(records)
      File.write(path, "invalid\n{\"id\":3}\n", mode: 'a')

      expect(store.load.size).to eq(2)
      expect(logger.error_messages.grep(/Skipping invalid buffered record/).size).to eq(2)
    end
  end
end
