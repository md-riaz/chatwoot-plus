# == Schema Information
#
# Table name: channel_whatsapp
#
#  id                             :bigint           not null, primary key
#  message_templates              :jsonb
#  message_templates_last_updated :datetime
#  phone_number                   :string           not null
#  provider                       :string           default("default")
#  provider_config                :jsonb
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :integer          not null
#
# Indexes
#
#  index_channel_whatsapp_on_phone_number  (phone_number) UNIQUE
#

class Channel::Whatsapp < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_whatsapp'
  EDITABLE_ATTRS = [:phone_number, :provider, { provider_config: {} }].freeze

  # default at the moment is 360dialog lets change later.
  PROVIDERS = %w[default whatsapp_cloud unoapi].freeze
  before_validation :ensure_webhook_verify_token

  validates :provider, inclusion: { in: PROVIDERS }
  validates :phone_number, presence: true, uniqueness: true
  validate :validate_provider_config

  after_create :sync_templates
  before_destroy :teardown_webhooks
  after_commit :setup_webhooks, on: :create, if: :should_auto_setup_webhooks?

  def name
    'Whatsapp'
  end

  # Mirrors Channel::TwilioSms#voice_enabled? so the call subsystem can duck-type across providers.
  # Meta's Calling API is available to any whatsapp_cloud inbox (embedded-signup or manual keys);
  # only 360dialog (default provider) can't reach the call APIs.
  def voice_enabled?
    voice_calling_supported? &&
      provider_config['calling_enabled'].present? &&
      account.feature_enabled?('channel_voice')
  end

  # Mutes only the incoming side of calling; default on, so only an explicit false disables inbound.
  def inbound_calls_enabled?
    provider_config['inbound_calls_enabled'] != false
  end

  # Whether this inbox can do WhatsApp calling at all. Meta's Calling API is
  # reachable by any whatsapp_cloud inbox, so 360dialog inboxes can't be toggled
  # on even though calling_enabled would persist.
  def voice_calling_supported?
    provider == 'whatsapp_cloud'
  end

  def provider_service
    if provider == 'whatsapp_cloud'
      Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: self)
    elsif provider == 'unoapi'
      Whatsapp::Providers::UnoapiService.new(whatsapp_channel: self)
    else
      Whatsapp::Providers::Whatsapp360DialogService.new(whatsapp_channel: self)
    end
  end

  def allow_group_creation?
    provider == 'unoapi'
  end

  def create_group(subject, participants)
    response = provider_service.create_group(subject: subject, participants: participants)
    raise Groups::ProviderUnavailableError, provider_error(response, 'Provider failed to create group') unless response.success?

    (response.parsed_response || {}).deep_symbolize_keys
  end

  def update_group_subject(group_id, subject)
    update_group(group_id: group_id, subject: subject)
  end

  def update_group_description(group_id, description)
    update_group(group_id: group_id, description: description)
  end

  def update_group_picture(group_id, image_base64)
    update_group(group_id: group_id, picture_url: image_base64)
  end

  def group_invite_code(group_id)
    invite_code_from_link(provider_group_invite_link(group_id))
  end

  def revoke_group_invite(group_id)
    invite_code_from_link(provider_reset_group_invite_link(group_id))
  end

  def update_group_participants(group_id, participants, action)
    case action
    when 'add'
      response = provider_service.add_group_participants(group_id: group_id, participants: participants)
    when 'remove'
      response = provider_service.remove_group_participants(group_id: group_id, participants: participants)
    else
      raise Groups::ProviderUnavailableError, 'Group participant role updates are not supported by this provider'
    end
    raise Groups::ProviderUnavailableError, provider_error(response, 'Provider failed to update group participants') unless response.success?

    true
  end

  def group_join_requests(group_id)
    response = provider_service.group_join_requests(group_id)
    raise Groups::ProviderUnavailableError, provider_error(response, 'Provider failed to fetch group join requests') unless response.success?

    response.parsed_response
  end

  def handle_group_join_requests(group_id, participants, action)
    response = if action == 'approve'
                 provider_service.approve_group_join_requests(group_id: group_id, participants: participants)
               else
                 provider_service.reject_group_join_requests(group_id: group_id, participants: participants)
               end
    raise Groups::ProviderUnavailableError, provider_error(response, 'Provider failed to handle group join requests') unless response.success?

    true
  end

  def group_leave(_group_id)
    raise Groups::ProviderUnavailableError, 'Group leave is not supported by this provider'
  end

  def group_setting_update(_group_id, _property, _enabled)
    raise Groups::ProviderUnavailableError, 'Group settings are not supported by this provider'
  end

  def group_join_approval_mode(_group_id, _mode)
    raise Groups::ProviderUnavailableError, 'Group join approval changes are not supported by this provider'
  end

  def group_member_add_mode(_group_id, _mode)
    raise Groups::ProviderUnavailableError, 'Group member add mode changes are not supported by this provider'
  end

  # Enables voice: turns calling on at Meta (idempotent), then re-registers webhooks
  # with the in-memory calling_enabled flag so the `calls` field is subscribed. The
  # flag is persisted only after registration succeeds, so a webhook failure can't
  # leave the inbox reporting voice_enabled? while the WABA isn't subscribed to calls.
  # Saved with validate: false to skip validate_provider_config's remote credential
  # re-check, which could spuriously fail and desync the flag from Meta.
  def enable_voice_calling!
    raise 'WhatsApp calling requires a whatsapp_cloud inbox' unless voice_calling_supported?
    raise 'WhatsApp calling requires the channel_voice feature' unless account.feature_enabled?('channel_voice')

    provider_service.update_calling_status('ENABLED')
    self.provider_config = provider_config.merge('calling_enabled' => true)
    webhook_setup_service.register_callback
    save!(validate: false)
  end

  # Disables voice: unsets calling_enabled (gates the call subsystem) and re-registers
  # webhooks, which drops `calls` from the subscription (best-effort, so a Meta outage
  # can't trap admins). Leaves Meta's WABA calling.status untouched.
  def disable_voice_calling!
    raise 'WhatsApp calling requires a whatsapp_cloud inbox' unless voice_calling_supported?

    self.provider_config = provider_config.merge('calling_enabled' => false)
    save!(validate: false)
    begin
      webhook_setup_service.register_callback
    rescue StandardError => e
      Rails.logger.warn "[WHATSAPP CALL] disable webhook re-subscribe failed: #{e.message}"
    end
  end

  def mark_message_templates_updated
    # rubocop:disable Rails/SkipsModelValidations
    update_column(:message_templates_last_updated, Time.zone.now)
    # rubocop:enable Rails/SkipsModelValidations
  end

  delegate :send_message, to: :provider_service
  delegate :send_template, to: :provider_service

  def send_message_delete(message)
    return false unless provider_service.respond_to?(:send_message_update)

    provider_service.send_message_update(provider_delete_payload(message))
  end

  delegate :sync_templates, to: :provider_service
  delegate :media_url, to: :provider_service
  delegate :api_headers, to: :provider_service

  def setup_webhooks
    perform_webhook_setup
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP] Webhook setup failed: #{e.message}"
    prompt_reauthorization!
  end

  def provider_delete_payload(message)
    {
      status: 'deleted',
      source_id: message.source_id,
      sender: { phone_number: message.sender&.phone_number },
      conversation: {
        group: message.conversation.group?,
        group_source_id: message.conversation.group_source_id,
        contact_inbox: message.conversation.contact_inbox
      }
    }
  end

  private

  def ensure_webhook_verify_token
    provider_config['webhook_verify_token'] ||= SecureRandom.hex(16) if %w[whatsapp_cloud unoapi].include?(provider)
  end

  def validate_provider_config
    errors.add(:provider_config, 'Invalid Credentials') unless provider_service.validate_provider_config?
  end

  def perform_webhook_setup
    webhook_setup_service.perform
  end

  def webhook_setup_service
    Whatsapp::WebhookSetupService.new(self, provider_config['business_account_id'], provider_config['api_key'])
  end

  def teardown_webhooks
    Whatsapp::WebhookTeardownService.new(self).perform
  end

  def update_group(group_id:, subject: nil, description: nil, picture_url: nil)
    response = provider_service.update_group(group_id: group_id, subject: subject, description: description, picture_url: picture_url)
    raise Groups::ProviderUnavailableError, provider_error(response, 'Provider failed to update group') unless response.success?

    true
  end

  def provider_group_invite_link(group_id)
    response = provider_service.group_invite_link(group_id)
    raise Groups::ProviderUnavailableError, provider_error(response, 'Provider failed to fetch invite link') unless response.success?

    parsed_invite_link(response)
  end

  def provider_reset_group_invite_link(group_id)
    response = provider_service.reset_group_invite_link(group_id)
    raise Groups::ProviderUnavailableError, provider_error(response, 'Provider failed to reset invite link') unless response.success?

    parsed_invite_link(response)
  end

  def parsed_invite_link(response)
    payload = (response.parsed_response || {}).with_indifferent_access
    payload[:invite_link] || payload[:inviteLink] || payload[:link] || payload.dig(:group, :invite_link) || payload.dig(:group, :inviteLink)
  end

  def invite_code_from_link(invite_link)
    invite_link.to_s.split('/').last
  end

  def provider_error(response, fallback)
    parsed = response.parsed_response if response.respond_to?(:parsed_response)
    parsed = parsed.with_indifferent_access if parsed.respond_to?(:with_indifferent_access)
    parsed&.dig(:error, :message) || parsed&.dig(:error) || fallback
  end

  def should_auto_setup_webhooks?
    # Only auto-setup webhooks for whatsapp_cloud provider with manual setup
    # Embedded signup calls setup_webhooks explicitly in EmbeddedSignupService
    provider == 'whatsapp_cloud' && provider_config['source'] != 'embedded_signup'
  end
end
