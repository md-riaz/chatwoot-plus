module Enterprise::Api::V1::Accounts::InboxesController
  def inbox_attributes
    super + ee_inbox_attributes
  end

  def enable_whatsapp_calling
    return unless ensure_whatsapp_calling_supported

    @inbox.channel.enable_voice_calling!
    head :ok
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def disable_whatsapp_calling
    return unless ensure_whatsapp_calling_supported

    @inbox.channel.disable_voice_calling!
    head :ok
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def ee_inbox_attributes
    [auto_assignment_config: [:max_assignment_limit]]
  end

  private

  def ensure_whatsapp_calling_supported
    channel = @inbox.channel
    return true if channel.is_a?(Channel::Whatsapp) && channel.voice_calling_supported?

    render_could_not_create_error('Inbox does not support WhatsApp calling')
    false
  end

  def allowed_channel_types
    super + ['voice']
  end

  def channel_type_from_params
    return Channel::Voice if permitted_params[:channel][:type] == 'voice'

    super
  end

  def account_channels_method
    return Current.account.voice_channels if permitted_params[:channel][:type] == 'voice'

    super
  end

  def create_channel
    if permitted_params[:channel][:type] == 'voice'
      raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('channel_voice')
    end

    super
  end

  def get_channel_attributes(channel_type)
    attrs = super
    attrs += [:voice_enabled, :api_key_sid, :api_key_secret] if channel_type == 'Channel::TwilioSms' && @inbox&.channel&.medium == 'sms'
    attrs
  end
end
