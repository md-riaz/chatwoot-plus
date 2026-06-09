class Voice::Provider::Custom::SessionService
  pattr_initialize [:call!, :inbox!, :user!]

  def join(call_sid:)
    ensure_conference_sid!
    update_status('in_progress', call_sid)
    {
      status: 'success',
      id: call.conversation.display_id,
      conference_sid: call.conference_sid,
      using_webrtc: true,
      to: contact_phone_number
    }
  end

  def leave(call_sid:)
    update_status('completed', call_sid)
  end

  private

  def ensure_conference_sid!
    return if call.conference_sid.present?

    call.update!(conference_sid: call.default_conference_sid)
  end

  def update_status(status, call_sid)
    raise ArgumentError, 'call_sid required' if call_sid.blank?

    Voice::CallStatus::Manager.new(call: call).process_status_update(status, timestamp: Time.zone.now.to_i)
  end

  def contact_phone_number
    call.contact&.phone_number || call.from_number || call.conversation.contact_inbox&.source_id || last_call_number
  end

  def last_call_number
    message = call.conversation.messages
                           .where(content_type: 'voice_call')
                           .order(created_at: :desc)
                           .first
    data = message&.content_attributes&.dig('data') || {}
    data['to_number'] || data['from_number']
  end
end
