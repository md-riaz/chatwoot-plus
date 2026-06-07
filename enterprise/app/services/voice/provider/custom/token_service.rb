class Voice::Provider::Custom::TokenService
  pattr_initialize [:inbox!, :user!, :account!]

  def generate
    {
      provider: 'custom',
      account_id: account.id,
      auth_type: 'password',
      password: resolved_password,
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

  def resolved_password
    inbox_member&.webrtc_password.presence ||
      user_custom_attributes['webrtc_password'].presence ||
      config['password'].presence ||
      config['token'].presence
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
