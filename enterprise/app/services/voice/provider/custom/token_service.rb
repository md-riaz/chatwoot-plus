class Voice::Provider::Custom::TokenService
  pattr_initialize [:inbox!, :user!, :account!]

  def generate
    if auth_type == 'password'
      return {
        provider: 'custom',
        account_id: account.id,
        auth_type: 'password',
        password: resolved_password,
        webrtc: webrtc_config,
        transfer: transfer_config
      }.compact
    end

    {
      provider: 'custom',
      account_id: account.id,
      auth_type: 'jwt',
      token: resolved_token,
      webrtc: webrtc_config,
      transfer: transfer_config
    }.compact
  end

  private

  def webrtc_config
    {
      ws_url: config['webrtc_ws_url'],
      sip_domain: config['sip_domain'],
      sip_outbound_proxy: config['sip_outbound_proxy'],
      sip_transport: config['sip_transport'] || 'wss',
      username: resolved_username,
      display_name: user.display_name.presence || user.name,
      ice_servers: ice_servers_config
    }.compact
  end

  def transfer_config
    {
      mode: config['transfer_mode'] || 'sip_refer'
    }
  end

  def resolved_token
    member_token = inbox_member&.webrtc_jwt
    return member_token if member_token.present?
    return user_custom_attributes['webrtc_jwt'] if user_custom_attributes['webrtc_jwt'].present?
    return config['token'] if config['token'].present?
    return nil if config['jwt_secret'].blank?

    JWT.encode(token_payload, config['jwt_secret'], 'HS256')
  end
  def resolved_password
    inbox_member&.webrtc_password.presence ||
      user_custom_attributes['webrtc_password'].presence ||
      config['password'].presence ||
      config['token'].presence
  end

  def auth_type
    config['auth_type'].presence || 'jwt'
  end

  def token_payload
    payload = {
      sub: user.id.to_s,
      email: user.email,
      account_id: account.id,
      name: user.name
    }
    ttl = config['jwt_ttl'].to_i
    payload[:exp] = Time.zone.now.to_i + ttl if ttl.positive?
    payload[:iss] = config['jwt_issuer'] if config['jwt_issuer'].present?
    payload[:aud] = config['jwt_audience'] if config['jwt_audience'].present?
    payload
  end
  def resolved_username
    inbox_member&.webrtc_username.presence ||
      user_custom_attributes['webrtc_username'].presence ||
      user.email
  end

  def ice_servers_config
    servers = []

    stun_urls = Array.wrap(config['stun_servers']).map(&:presence).compact
    servers.concat(stun_urls.map { |url| { urls: url } })

    Array.wrap(config['turn_servers']).each do |entry|
      next if entry.blank?

      turn = entry.with_indifferent_access
      url = turn[:urls] || turn[:url]
      next if url.blank?

      server = { urls: url }
      server[:username] = turn[:username] if turn[:username].present?
      server[:credential] = turn[:credential] if turn[:credential].present?
      servers << server
    end

    servers
  end

  def user_custom_attributes
    user.custom_attributes || {}
  end

  def inbox_member
    @inbox_member ||= inbox.inbox_members.find_by(user_id: user.id)
  end

  def config
    @config ||= inbox.channel.provider_config_hash.with_indifferent_access
  end
end
