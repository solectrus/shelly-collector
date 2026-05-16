require 'http_auth'

describe HttpAuth do
  let(:app) { double }
  let(:middleware) { described_class.new(app, username: 'username', password: 'password') }

  describe '#call' do
    let(:url) { instance_double(URI::HTTP, request_uri: '/test') }
    let(:env) do
      Faraday::Env.new.tap do |e|
        e.method = :get
        e.url = url
        e.request_headers = {}
      end
    end

    it 'returns response without authentication' do
      response = instance_double(Faraday::Response, status: 200)
      allow(app).to receive(:call).and_return(response)

      expect(middleware.call(env)).to eq(response)
    end

    it 'retries with digest auth on 401 (Gen2+)' do
      auth_header = 'Digest realm="test", nonce="123", qop="auth"'
      unauthorized = instance_double(Faraday::Response, status: 401, headers: { 'www-authenticate' => auth_header })
      success = instance_double(Faraday::Response, status: 200)
      retry_env = nil
      allow(app).to receive(:call) do |called_env|
        retry_env = called_env
        called_env.request_headers['Authorization'] ? success : unauthorized
      end

      expect(middleware.call(env)).to eq(success)
      expect(retry_env.request_headers['Authorization']).to start_with('Digest ')
    end

    it 'retries with basic auth on 401 (Gen1)' do
      auth_header = 'Basic realm="test"'
      unauthorized = instance_double(Faraday::Response, status: 401, headers: { 'www-authenticate' => auth_header })
      success = instance_double(Faraday::Response, status: 200)
      retry_env = nil
      allow(app).to receive(:call) do |called_env|
        retry_env = called_env
        called_env.request_headers['Authorization'] ? success : unauthorized
      end

      expect(middleware.call(env)).to eq(success)
      expect(retry_env.request_headers['Authorization'])
        .to eq("Basic #{['username:password'].pack('m0')}")
    end

    it 'raises error on auth failure' do
      auth_header = 'Digest realm="test", nonce="123", qop="auth"'
      unauthorized = instance_double(Faraday::Response, status: 401, headers: { 'www-authenticate' => auth_header })
      allow(app).to receive(:call).and_return(unauthorized, unauthorized)

      expect { middleware.call(env) }.to raise_error(Faraday::UnauthorizedError)
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
