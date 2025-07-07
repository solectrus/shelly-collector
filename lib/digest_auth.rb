require 'faraday'
require 'digest'
require 'securerandom'

class DigestAuth < Faraday::Middleware
  def initialize(app, username:, password:)
    super(app)
    @username = username
    @password = password
    @nc = 0
  end

  def call(env)
    response = @app.call(env)
    response = retry_with_auth(response, env) if needs_auth?(response)
    response
  end

  private

  def needs_auth?(response)
    response.status == 401 && response.headers['www-authenticate']
  end

  def retry_with_auth(response, env)
    auth_header = response.headers['www-authenticate']
    params = parse_www_authenticate(auth_header)

    new_env = build_authenticated_env(env, params)
    authenticated_response = @app.call(new_env)

    if authenticated_response.status == 401
      raise Faraday::UnauthorizedError, 'Digest authentication failed: invalid username or password'
    end

    authenticated_response
  end

  def build_authenticated_env(env, params)
    auth_value = build_auth_header(env, params)
    new_env = env.dup
    new_env.request_headers['Authorization'] = "Digest #{auth_value}"
    new_env
  end

  def build_auth_header(env, params)
    @nc += 1
    nc_hex = format('%08x', @nc)
    cnonce = SecureRandom.hex(8)

    ha1 = Digest::SHA256.hexdigest("#{@username}:#{params['realm']}:#{@password}")
    ha2 = Digest::SHA256.hexdigest("#{env.method.to_s.upcase}:#{env.url.request_uri}")
    response_hash = Digest::SHA256.hexdigest("#{ha1}:#{params['nonce']}:#{nc_hex}:#{cnonce}:#{params['qop']}:#{ha2}")

    build_auth_value(env, params, nc_hex, cnonce, response_hash)
  end

  def build_auth_value(env, params, nc_hex, cnonce, response_hash)
    [
      "username=\"#{@username}\"",
      "realm=\"#{params['realm']}\"",
      "nonce=\"#{params['nonce']}\"",
      "uri=\"#{env.url.request_uri}\"",
      "qop=#{params['qop']}",
      "nc=#{nc_hex}",
      "cnonce=\"#{cnonce}\"",
      "response=\"#{response_hash}\"",
      'algorithm=SHA-256',
    ].join(', ')
  end

  def parse_www_authenticate(header)
    header.scan(/(\w+)=["]?([^",]+)["]?/).to_h
  end
end

Faraday::Request.register_middleware digest_auth: -> { DigestAuth }
