require 'faraday'
require 'digest'
require 'securerandom'

# Faraday middleware that authenticates against password-protected Shelly devices.
#
# Shelly Gen1 devices (e.g. Shelly 3EM) use HTTP Basic auth, while Gen2+ devices
# use HTTP Digest auth. The scheme is not known up front, so the first request is
# sent unauthenticated and the scheme is taken from the device's WWW-Authenticate
# response header.
#
# That challenge is then cached and the credentials are sent preemptively on every
# subsequent request, sparing the 401 challenge round-trip. Basic credentials are
# constant; Digest reuses the server nonce with an incrementing nonce count (nc),
# which Shelly accepts until the nonce expires. When the device eventually rejects
# the cached challenge with a fresh 401, the new challenge is learned and the
# request retried — so an expired nonce or a changed auth scheme self-heals.
class HttpAuth < Faraday::Middleware
  def initialize(app, username:, password:)
    super(app)
    @username = username
    @password = password
    @challenge = nil
  end

  def call(env)
    response = authorized_request(env)
    return response unless needs_auth?(response)

    # No challenge cached yet, or the cached one was rejected (expired nonce,
    # changed scheme): learn the current challenge and retry once.
    @challenge = parse_challenge(response.headers['www-authenticate'])
    response = authorized_request(env)
    reject_unauthorized!(response)
    response
  end

  private

  # Sends the request, adding an Authorization header built from the cached
  # challenge when one is known. The very first request (and any after the
  # device expired its nonce) goes out unauthenticated and triggers a 401.
  def authorized_request(env)
    return @app.call(env) unless @challenge

    authenticated_env = env.dup
    authenticated_env.request_headers['Authorization'] = authorization(env)
    @app.call(authenticated_env)
  end

  def needs_auth?(response)
    response.status == 401 && response.headers['www-authenticate']
  end

  def reject_unauthorized!(response)
    return unless response.status == 401

    raise Faraday::UnauthorizedError, 'Authentication failed: invalid username or password'
  end

  # Detects the scheme requested by the device (Basic for Gen1, Digest for Gen2+)
  def parse_challenge(header)
    if header.match?(/\ABasic\b/i)
      { scheme: :basic }
    else
      { scheme: :digest, params: parse_www_authenticate(header), nc: 0 }
    end
  end

  def authorization(env)
    case @challenge[:scheme]
    when :basic
      basic_authorization
    else
      digest_authorization(env)
    end
  end

  def basic_authorization
    credentials = ["#{@username}:#{@password}"].pack('m0')
    "Basic #{credentials}"
  end

  def digest_authorization(env)
    params = @challenge[:params]
    nc_hex = format('%08x', @challenge[:nc] += 1)
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
