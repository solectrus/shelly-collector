require 'http_auth'

describe HttpAuth do
  let(:app) { double }
  let(:middleware) { described_class.new(app, username: 'username', password: 'password') }

  describe '#call' do
    let(:url) { instance_double(URI::HTTP, request_uri: '/test') }
    let(:seen_headers) { [] }
    let(:success) { instance_double(Faraday::Response, status: 200) }

    def fresh_env
      Faraday::Env.new.tap do |e|
        e.method = :get
        e.url = url
        e.request_headers = {}
      end
    end

    def challenge(header)
      instance_double(Faraday::Response, status: 401, headers: { 'www-authenticate' => header })
    end

    # Records every Authorization header the app sees and lets the block decide
    # the response based on that header (nil when the request is unauthenticated).
    def stub_app
      allow(app).to receive(:call) do |called_env|
        header = called_env.request_headers['Authorization']
        seen_headers << header
        yield(header)
      end
    end

    it 'returns response without authentication' do
      allow(app).to receive(:call).and_return(success)

      expect(middleware.call(fresh_env)).to eq(success)
    end

    it 'retries with digest auth on 401 (Gen2+)' do
      unauthorized = challenge('Digest realm="test", nonce="123", qop="auth"')
      stub_app { |header| header ? success : unauthorized }

      expect(middleware.call(fresh_env)).to eq(success)
      expect(seen_headers).to match([nil, a_string_starting_with('Digest ')])
    end

    it 'retries with basic auth on 401 (Gen1)' do
      unauthorized = challenge('Basic realm="test"')
      stub_app { |header| header ? success : unauthorized }

      expect(middleware.call(fresh_env)).to eq(success)
      expect(seen_headers).to eq([nil, "Basic #{['username:password'].pack('m0')}"])
    end

    it 'raises error on auth failure (wrong credentials)' do
      unauthorized = challenge('Digest realm="test", nonce="123", qop="auth"')
      allow(app).to receive(:call).and_return(unauthorized)

      expect { middleware.call(fresh_env) }.to raise_error(Faraday::UnauthorizedError)
    end

    it 'sends basic auth preemptively once the scheme is known (Gen1)' do
      unauthorized = challenge('Basic realm="test"')
      stub_app { |header| header ? success : unauthorized }

      middleware.call(fresh_env) # first call discovers Basic via the 401 challenge
      middleware.call(fresh_env)

      basic = "Basic #{['username:password'].pack('m0')}"
      # 1st call: unauthenticated + retry; 2nd call: a single preemptive request
      expect(seen_headers).to eq([nil, basic, basic])
    end

    it 'sends digest preemptively with incrementing nc once the nonce is known (Gen2+)' do
      unauthorized = challenge('Digest realm="test", nonce="123", qop="auth"')
      stub_app { |header| header ? success : unauthorized }

      middleware.call(fresh_env) # discovers the nonce via the 401 challenge
      middleware.call(fresh_env)

      # Only the very first request is unauthenticated; the nonce is then reused
      # with an incrementing nonce count instead of a fresh challenge each time.
      expect(seen_headers).to match(
        [nil, a_string_including('nc=00000001'), a_string_including('nc=00000002')],
      )
    end

    it 'relearns the digest challenge when the cached nonce expires' do
      old = challenge('Digest realm="test", nonce="111", qop="auth"')
      fresh = challenge('Digest realm="test", nonce="222", qop="auth"')
      nonce_111_alive = true
      stub_app do |header|
        if header.nil?
          old
        elsif header.include?('nonce="111"')
          # The nonce works once, then the device expires it
          nonce_111_alive ? (nonce_111_alive = false) || success : fresh
        else
          success
        end
      end

      middleware.call(fresh_env)
      expect(middleware.call(fresh_env)).to eq(success)

      # The expired nonce was replaced and the nonce count restarted at 1
      expect(seen_headers.last).to include('nonce="222"', 'nc=00000001')
    end

    it 'self-heals when the device switches auth scheme (Gen1 to Gen2+)' do
      basic = challenge('Basic realm="test"')
      digest = challenge('Digest realm="test", nonce="123", qop="auth"')
      basic_alive = true
      stub_app do |header|
        if header.nil?
          basic
        elsif header.start_with?('Basic')
          basic_alive ? (basic_alive = false) || success : digest
        else
          success
        end
      end

      middleware.call(fresh_env) # discovers Basic
      expect(middleware.call(fresh_env)).to eq(success)
      expect(seen_headers.last).to start_with('Digest ')
    end

    it 'raises when the cached credentials are later rejected' do
      unauthorized = challenge('Basic realm="test"')
      stub_app { |header| header ? success : unauthorized }

      middleware.call(fresh_env) # discover Basic

      # The device now rejects everything (e.g. the password was changed)
      allow(app).to receive(:call).and_return(unauthorized)
      expect { middleware.call(fresh_env) }.to raise_error(Faraday::UnauthorizedError)
    end
  end

  describe '#parse_www_authenticate' do
    it 'parses header' do
      header = 'Digest realm="test", nonce="abc", qop="auth"'

      result = middleware.send(:parse_www_authenticate, header)
      expect(result).to eq('realm' => 'test', 'nonce' => 'abc', 'qop' => 'auth')
    end
  end
end
