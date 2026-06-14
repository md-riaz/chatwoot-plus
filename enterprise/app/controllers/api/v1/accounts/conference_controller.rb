class Api::V1::Accounts::ConferenceController < Api::V1::Accounts::BaseController
  before_action :set_voice_inbox_for_conference
  rescue_from CustomExceptions::CallAlreadyAccepted, with: :render_call_already_accepted

  def token
    render json: token_service.new(
      inbox: @voice_inbox,
      user: Current.user,
      account: Current.account
    ).generate
  end

  def create
    if provider == 'custom' && params[:from_number].present?
      return incoming
    end

    call = resolve_call!

    if call.custom?
      call.update!(accepted_by_agent: current_user) if call.accepted_by_agent_id != current_user.id
      response = Voice::Provider::Custom::SessionService.new(
        call: call,
        inbox: @voice_inbox,
        user: current_user
      ).join(call_sid: call.provider_call_id)

      return render json: response.merge(provider: provider)
    end

    conference_service = Voice::Provider::Twilio::ConferenceService.new(call: call)
    conference_sid = conference_service.ensure_conference_sid
    conference_service.mark_agent_joined(user: current_user)

    render json: {
      status: 'success',
      id: call.conversation.display_id,
      conference_sid: conference_sid,
      using_webrtc: true,
      provider: provider
    }
  end

  def incoming
    return render json: { error: 'Inbound calls supported only for custom voice provider' }, status: :unprocessable_entity unless provider == 'custom'

    call_sid = params.require(:call_sid)
    from_number = params.require(:from_number)

    call = Voice::InboundCallBuilder.perform!(
      inbox: @voice_inbox,
      from_number: from_number,
      call_sid: call_sid,
      provider: :custom
    )

    render json: {
      status: 'success',
      conversation_id: call.conversation.display_id,
      inbox_id: @voice_inbox.id,
      call_sid: call.provider_call_id
    }
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    call = resolve_call!
    status = params[:call_status].to_s.tr('-', '_')
    return render json: { status: 'ignored' } unless Call::STATUSES.include?(status)

    timestamp = params[:timestamp].presence&.to_i
    Voice::CallStatus::Manager.new(call: call).process_status_update(status, timestamp: timestamp)
    Voice::CallMessageBuilder.new(call).update_status!(status: status, agent: call.accepted_by_agent)
    render json: { status: 'success', id: call.conversation.display_id }
  end

  alias status update

  def destroy
    call = resolve_call!
    rejecting = agent_rejecting_before_pickup?(call)

    if call.custom?
      Voice::Provider::Custom::SessionService.new(
        call: call,
        inbox: @voice_inbox,
        user: current_user
      ).leave(call_sid: call.provider_call_id)
    else
      Voice::Provider::Twilio::ConferenceService.new(call: call).end_conference
    end

    finalize_as_agent_reject!(call) if rejecting
    render json: { status: 'success', id: call.conversation.display_id }
  end

  def upload_recording
    unless provider == 'custom'
      return render json: { error: 'Recording supported only for custom voice provider' }, status: :unprocessable_entity
    end

    call = resolve_call!
    return render_could_not_create_error(I18n.t('errors.whatsapp.calls.no_recording')) if params[:recording].blank?
    return render_could_not_create_error(I18n.t('errors.whatsapp.calls.no_message')) if call.message.blank?

    upload_status = call.message.with_lock do
      attach_recording_idempotently(call)
    end

    render json: { status: upload_status, id: call.conversation.display_id }
  end

  def transfer
    return render json: { error: 'Transfer supported only for custom voice provider' }, status: :unprocessable_entity unless provider == 'custom'

    call = resolve_call!
    target_agent = Current.account.users.find(params.require(:target_agent_id))
    response = Voice::Provider::Custom::TransferService.new(
      inbox: @voice_inbox,
      conversation: call.conversation,
      target_agent: target_agent,
      call_sid: call.provider_call_id
    ).perform

    render json: response.merge(status: 'success')
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def resolve_call!
    sid = params[:call_sid].presence
    raise ActionController::ParameterMissing, :call_sid if sid.blank?

    conversation = fetch_conversation_by_display_id
    scope = Call.where(inbox_id: @voice_inbox.id, conversation_id: conversation.id)
    scope = scope.where(provider: provider == 'custom' ? :custom : :twilio)
    scope.find_by!(provider_call_id: sid)
  end

  def set_voice_inbox_for_conference
    @voice_inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @voice_inbox, :show?
  end

  def provider
    @provider ||= @voice_inbox.channel.provider
  end

  def token_service
    case provider
    when 'custom'
      Voice::Provider::Custom::TokenService
    else
      Voice::Provider::Twilio::TokenService
    end
  end

  def fetch_conversation_by_display_id
    cid = params[:conversation_id]
    raise ActiveRecord::RecordNotFound, 'conversation_id required' if cid.blank?

    conversation = Current.account.conversations.find_by!(display_id: cid)
    authorize conversation, :show?
    return conversation if conversation.inbox_id == @voice_inbox.id

    internal_voice_inbox_id = conversation.additional_attributes&.dig('voice_inbox_id')
    raise ActiveRecord::RecordNotFound, 'Conversation not linked to voice inbox' unless internal_voice_inbox_id == @voice_inbox.id

    conversation
  end

  def attach_recording_idempotently(call)
    return 'already_uploaded' if call.message.attachments.exists?(file_type: :audio)

    call.message.attachments.create!(
      account_id: call.account_id,
      file_type: :audio,
      file: params[:recording]
    )
    'uploaded'
  end

  def render_call_already_accepted(error)
    render json: { error: error.message }, status: :conflict
  end

  def agent_rejecting_before_pickup?(call)
    call.ringing? && call.accepted_by_agent_id.nil?
  end

  def finalize_as_agent_reject!(call)
    rejected = call.with_lock do
      next false unless agent_rejecting_before_pickup?(call)

      call.update!(status: 'failed', end_reason: 'agent_rejected', accepted_by_agent_id: Current.user.id)
      true
    end
    Voice::CallMessageBuilder.new(call).update_status!(status: 'failed', agent: Current.user) if rejected
  end
end
