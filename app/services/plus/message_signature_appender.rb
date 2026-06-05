module Plus
  class MessageSignatureAppender
    def self.call(content:, conversation:, message_type:, private_message:)
      return content unless message_type == 'outgoing'
      return content if private_message
      return content if content.blank?

      signature = conversation.inbox.additional_attributes&.dig('signature') if conversation.inbox.respond_to?(:additional_attributes)
      return content if signature.blank?
      normalized_content = content.to_s.rstrip
      normalized_signature = signature.to_s.rstrip
      already_signed = normalized_content == normalized_signature ||
                       normalized_content.end_with?("\n#{normalized_signature}")
      return content if already_signed

      "#{content}\n\n#{signature}"
    end
  end
end
