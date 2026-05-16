require 'faraday'
require 'digest'
require 'securerandom'

# Faraday middleware that authenticates against password-protected Shelly devices.
#
# Shelly Gen1 devices (e.g. Shelly 3EM) use HTTP Basic auth, while Gen2+ devices
# use HTTP Digest auth. The scheme is not known up front, so the first request is
# sent unauthenticated and the scheme is taken from the device's WWW-Authenticate
# response header.
class HttpAuth < Faraday::Middleware
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

    new_env = build_authenticated_env(env, auth_header)
    authenticated_response = @app.call(new_env)

    if authenticated_response.status == 401
      raise Faraday::UnauthorizedError, 'Authentication failed: invalid username or password'
    end

    authenticated_response
  end

  def build_authenticated_env(env, auth_header)
    new_env = env.dup
    new_env.request_headers['Authorization'] = authorization(env, auth_header)
    new_env
  end

  # Picks the auth scheme requested by the device (Basic for Gen1, Digest for Gen2+)
  def authorization(env, auth_header)
    if auth_header.match?(/\ABasic\b/i)
      basic_authorization
    else
      digest_authorization(env, parse_www_authenticate(auth_header))
    end
  end

  def basic_authorization
    credentials = ["#{@username}:#{@password}"].pack('m0')
    "Basic #{credentials}"
  end

  def digest_authorization(env, params)
    @nc += 1
    nc_hex = format('%08x', @nc)
    cnonce = SecureRandom.hex(8)

    ha1 = Digest::SHA256.hexdigest("#{@username}:#{params['realm']}:#{@password}")
    ha2 = Digest::SHA256.hexdigest("#{env.method.to_s.upcase}:#{env.url.request_uri}")
    response_hash = Digest::SHA256.hexdigest("#{ha1}:#{params['nonce']}:#{nc_hex}:#{cnonce}:#{params['qop']}:#{ha2}")

    "Digest #{digest_value(env, params, nc_hex, cnonce, response_hash)}"
  end

  def digest_value(env, params, nc_hex, cnonce, response_hash)
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
    header.scan(/(\w+)="?([^",]+)"?/).to_h
  end
end

Faraday::Request.register_middleware http_auth: -> { HttpAuth }
