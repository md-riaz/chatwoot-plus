class Voice::Provider::Custom::TransferService
  pattr_initialize [:inbox!, :conversation!, :target_agent!, :call_sid]

  def perform
    case transfer_mode
    when 'sip_refer'
      { mode: transfer_mode, refer_to: refer_target }
    when 'ari'
      { mode: transfer_mode, status: 'requested', response: request_transfer }
    else
      raise ArgumentError, "Unsupported transfer mode: #{transfer_mode}"
    end
  end

  private

  def request_transfer
    response = HTTParty.post(
      config['transfer_api_url'],
      headers: transfer_headers,
      body: transfer_payload.to_json,
      timeout: 5
    )

    {
      code: response.code,
      body: response.body
    }
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, HTTParty::Error => e
    Rails.logger.error("Custom voice transfer failed: #{e.class}: #{e.message}")
    {
      code: 500,
      body: { error: 'Failed to contact transfer API' }.to_json
    }
  end

  def transfer_headers
    headers = { 'Content-Type' => 'application/json' }
    token = config['transfer_api_token']
    headers['Authorization'] = "Bearer #{token}" if token.present?
    headers
  end

  def transfer_payload
    {
      conversation_id: conversation.display_id,
      call_sid: call_sid,
      target_agent: {
        id: target_agent.id,
        name: target_agent.name,
        email: target_agent.email
      }
    }
  end

  def refer_target
    username = target_inbox_member&.webrtc_username.presence ||
      target_agent.custom_attributes&.dig('webrtc_username').presence
    return "sip:#{username}@#{config['sip_domain']}" if username.present?

    email = target_agent.email.to_s
    return email if email.start_with?('sip:')
    return "sip:#{email.split('@').first}@#{config['sip_domain']}" if email.include?('@')

    raise ArgumentError, 'Target agent does not have a SIP username'
  end

  def transfer_mode
    config['transfer_mode'] || 'sip_refer'
  end

  def config
    @config ||= inbox.channel.provider_config_hash.with_indifferent_access
  end

  def target_inbox_member
    @target_inbox_member ||= inbox.inbox_members.find_by(user_id: target_agent.id)
  end
end
