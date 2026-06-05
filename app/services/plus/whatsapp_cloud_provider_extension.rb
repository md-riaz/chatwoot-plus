# frozen_string_literal: true

module Plus::WhatsappCloudProviderExtension
  GROUP_CONTACT_MENTION_PATTERN = %r{\[@([^\]]+)\]\(mention://group[_-]contact/(\d+)/[^)]+\)|mention://group[_-]contact/(\d+)/([^\s)]+)}

  def send_message(phone_number, message)
    @message = message

    if message.content_type == 'sticker'
      send_sticker_message(phone_number, message)
    elsif contact_message?(message)
      send_contacts_message(phone_number, message)
    elsif message.attachments.present?
      send_attachments(phone_number, message)
    elsif message.content_type == 'input_select'
      send_interactive_text_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  def send_template(phone_number, template_info, message)
    template_body = template_body_parameters(template_info)

    request_body = {
      messaging_product: 'whatsapp',
      recipient_type: recipient_type_for(message),
      to: phone_number,
      type: 'template',
      template: template_body
    }

    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: request_body.to_json
    )

    process_response(response, message)
  end

  def send_reaction(phone_number, message_id, emoji)
    response = HTTParty.post(
      messages_path,
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        to: phone_number,
        type: 'reaction',
        reaction: {
          message_id: message_id,
          emoji: emoji
        }
      }.to_json
    )

    response.success? && response.parsed_response['error'].blank?
  end

  def send_message_update(message)
    payload = message_update_payload(message)
    return false if payload[:message_id].blank? || payload[:recipient_id].blank?

    response = HTTParty.public_send(
      message_update_http_method,
      message_path(message),
      headers: api_headers,
      body: payload.to_json
    )

    response.success? && response.parsed_response['error'].blank?
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] message update failed: #{e.class}: #{e.message}")
    false
  end

  def message_update_payload(message)
    payload = {
      messaging_product: 'whatsapp',
      status: message[:status],
      message_id: message[:source_id],
      recipient_id: message_update_recipient_id(message),
      recipient_type: 'individual'
    }
    if message[:conversation][:group] && message[:conversation][:group_source_id].present?
      return payload.merge(
        recipient_id: message[:conversation][:group_source_id],
        recipient_type: 'group'
      )
    end
    payload
  end

  def message_update_http_method
    :post
  end

  def message_path(_message)
    messages_path
  end

  private

  def message_update_recipient_id(message)
    (message[:sender] || {})[:phone_number].presence ||
      contact_inbox_source_id(message[:conversation]&.[](:contact_inbox))
  end

  def contact_inbox_source_id(contact_inbox)
    return if contact_inbox.blank?
    return contact_inbox[:source_id] if contact_inbox.respond_to?(:[]) && contact_inbox[:source_id].present?
    return contact_inbox['source_id'] if contact_inbox.respond_to?(:[]) && contact_inbox['source_id'].present?
    return contact_inbox.source_id if contact_inbox.respond_to?(:source_id)
  end

  def recipient_type_for(message)
    message.conversation.group? ? 'group' : 'individual'
  end

  def api_base_path
    whatsapp_channel.provider_config['url'] || ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
  end

  def phone_id_path(version = 'v13.0')
    "#{api_base_path}/#{version}/#{whatsapp_channel.provider_config['phone_number_id']}"
  end

  def messages_path
    "#{phone_id_path}/messages"
  end

  def send_attachments(phone_number, message)
    attachments = message.attachments
    last_message_id = nil

    attachments.each_with_index do |attachment, index|
      include_caption = index.zero?
      last_message_id = send_attachment_message(
        phone_number,
        message,
        attachment,
        include_caption: include_caption
      )
    end

    last_message_id
  end

  def send_text_message(phone_number, message)
    mention_ids = whatsapp_mention_ids(message)
    request_body = {
      messaging_product: 'whatsapp',
      recipient_type: recipient_type_for(message),
      context: whatsapp_reply_context(message),
      to: phone_number,
      text: { body: format_content(message) },
      type: 'text'
    }
    request_body[:mentions] = mention_ids if mention_ids.present?

    response = HTTParty.post(
      messages_path,
      headers: api_headers,
      body: request_body.to_json
    )

    process_response(response, message)
  end

  def format_content(message)
    normalized_content = whatsapp_outgoing_content(message)&.rstrip
    return normalized_content unless should_prefix_sender_name?(message)

    scoped_sender_name = Plus::ScopedAgentDisplayNameResolver.call(user: message.sender, account: message.account, inbox: message.inbox)
    scoped_sender_name.present? ? "*#{scoped_sender_name}*: #{normalized_content}" : normalized_content
  end

  def whatsapp_outgoing_content(message)
    return message.outgoing_content unless message.conversation.group? && whatsapp_group_mentions(message).present?

    content = replace_group_mentions(message.content.to_s, message)
    Messages::MarkdownRendererService.new(
      content,
      message.conversation.inbox.channel_type,
      whatsapp_channel
    ).render
  end

  def should_prefix_sender_name?(message)
    return true if message.conversation.group?

    feature = whatsapp_channel.inbox.account.feature_enabled?('send_agent_name_in_whatsapp_message')
    config = whatsapp_channel.provider_config['send_agent_name']
    feature || config
  end

  def send_attachment_message(phone_number, message, attachment = nil, include_caption: true)
    attachment ||= message.attachments.first
    type = %w[image audio video].include?(attachment.file_type) ? attachment.file_type : 'document'
    type_content = {
      'link': attachment.download_url
    }
    type_content['caption'] = whatsapp_outgoing_content(message) unless %w[audio sticker].include?(type) || !include_caption
    mention_ids = whatsapp_mention_ids(message)
    type_content['mentions'] = mention_ids if mention_ids.present?
    type_content['filename'] = attachment.file.filename if type == 'document'
    request_body = {
      messaging_product: 'whatsapp',
      recipient_type: recipient_type_for(message),
      context: whatsapp_reply_context(message),
      to: phone_number,
      type: type,
      type.to_s => type_content
    }
    request_body[:mentions] = mention_ids if mention_ids.present?

    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: request_body.to_json
    )

    process_response(response, message)
  end

  def send_sticker_message(phone_number, message)
    sticker_url = message.content_attributes&.[]('sticker_url')
    if sticker_url.blank?
      Rails.logger.warn("[WHATSAPP] Sticker url missing message_id=#{message.id}")
      return
    end

    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        recipient_type: recipient_type_for(message),
        context: whatsapp_reply_context(message),
        to: phone_number,
        type: 'sticker',
        sticker: {
          link: sticker_url
        }
      }.to_json
    )

    process_response(response, message)
  end

  def send_contacts_message(phone_number, message)
    contacts_payload = whatsapp_contacts_payload(message)
    request_body = {
      messaging_product: 'whatsapp',
      recipient_type: recipient_type_for(message),
      context: whatsapp_reply_context(message),
      to: phone_number,
      type: 'contacts',
      contacts: contacts_payload
    }

    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: request_body.to_json
    )

    process_response(response, message)
  end

  def whatsapp_reply_context(message)
    reply_to = message.content_attributes[:in_reply_to_external_id]
    if reply_to.blank?
      in_reply_to_id = message.content_attributes[:in_reply_to]
      reply_to = message.conversation.messages.find_by(id: in_reply_to_id)&.source_id if in_reply_to_id.present?
    end
    return nil if reply_to.blank?

    {
      message_id: reply_to
    }
  end

  def replace_group_mentions(content, message)
    mentions_by_contact_id = whatsapp_group_mentions(message).index_by { |mention| mention[:mention_id].to_s }

    content.gsub(GROUP_CONTACT_MENTION_PATTERN) do
      contact_id = Regexp.last_match(2) || Regexp.last_match(3)
      mention = mentions_by_contact_id[contact_id]
      display_identifier = mention&.dig(:bsuid).to_s.delete_prefix('@').delete_suffix('@lid')

      display_identifier.present? ? "@#{display_identifier}" : Regexp.last_match(0)
    end
  end

  def whatsapp_mention_ids(message)
    whatsapp_group_mentions(message).filter_map { |mention| mention[:bsuid].presence }
  end

  def whatsapp_group_mentions(message)
    return [] unless message.conversation.group?
    return [] unless whatsapp_channel.provider == 'unoapi'

    mentions = group_mentions_from_content_attributes(message) + group_mentions_from_content(message)
    mentions.uniq { |mention| [mention[:mention_id].to_s, mention[:bsuid].to_s] }
  end

  def group_mentions_from_content_attributes(message)
    mentions = message.content_attributes&.[]('group_mentions') || []
    mentions.filter_map do |mention|
      mention = mention.with_indifferent_access
      bsuid = mention[:bsuid].to_s.delete_prefix('@').presence || mention[:phone_number].to_s.gsub(/\D/, '').presence
      contact_id = mention[:contact_id].presence
      next if bsuid.blank? || contact_id.blank?

      { mention_id: contact_id, contact_id: contact_id, bsuid: bsuid }
    end
  end

  def group_mentions_from_content(message)
    message.content.to_s.scan(GROUP_CONTACT_MENTION_PATTERN).filter_map do |match|
      mention_id = (match[1] || match[2]).presence
      next if mention_id.blank?

      group_mention_from_id(message, mention_id)
    end
  end

  def group_mention_from_id(message, mention_id)
    group_contact = message.conversation.group_contacts.includes(:contact).find_by(contact_id: mention_id) ||
                    message.conversation.group_contacts.includes(:contact).find_by(id: mention_id)
    contact = group_contact&.contact || Contact.find_by(id: mention_id, account_id: message.account_id)
    bsuid = group_mention_identifier(contact, group_contact)
    return if contact.blank? || bsuid.blank?

    { mention_id: mention_id, contact_id: contact.id, bsuid: bsuid }
  end

  def group_mention_identifier(contact, group_contact)
    metadata = group_contact&.metadata || {}
    contact&.bsuid.presence ||
      metadata['user_id'].presence ||
      metadata['lid'].presence ||
      (metadata['jid'].to_s.end_with?('@lid') ? metadata['jid'] : nil) ||
      contact&.phone_number.to_s.gsub(/\D/, '').presence ||
      metadata['wa_id'].to_s.gsub(/\D/, '').presence
  end

  def contact_message?(message)
    message.attachments.any?(&:contact?)
  end

  def whatsapp_contacts_payload(message)
    message.attachments.select(&:contact?).map do |attachment|
      meta = attachment.meta&.with_indifferent_access || {}
      formatted_name = meta[:formatted_name].presence ||
                       [meta[:first_name], meta[:last_name]].compact.join(' ').presence ||
                       attachment.fallback_title
      wa_id = attachment.fallback_title.to_s.gsub(/\D/, '').presence

      payload = {
        name: {
          formatted_name: formatted_name,
          first_name: meta[:first_name].presence || formatted_name,
          last_name: meta[:last_name].presence
        }.compact
      }

      if attachment.fallback_title.present?
        phone_payload = {
          phone: attachment.fallback_title,
          type: 'CELL'
        }
        phone_payload[:wa_id] = wa_id if wa_id.present?
        payload[:phones] = [phone_payload]
      end

      if meta[:email].present?
        payload[:emails] = [{
          email: meta[:email],
          type: 'WORK'
        }]
      end

      payload
    end
  end

  def send_interactive_text_message(phone_number, message)
    payload = create_payload_based_on_items(message)

    response = HTTParty.post(
      "#{phone_id_path}/messages",
      headers: api_headers,
      body: {
        messaging_product: 'whatsapp',
        recipient_type: recipient_type_for(message),
        to: phone_number,
        interactive: payload,
        type: 'interactive'
      }.to_json
    )

    process_response(response, message)
  end
end
