# frozen_string_literal: true

module Plus
  module MetaAdReferralExtensions
    module FacebookMessageParser
      def referral
        @messaging['referral'] || @messaging.dig('postback', 'referral')
      end

      def identifier
        super || referral_event_identifier
      end

      private

      def referral_event_identifier
        return unless referral.present?

        "meta-referral-#{sender_id}-#{recipient_id}-#{time_stamp}"
      end
    end

    module FacebookMessageBuilder
      private

      def message_params
        params = super
        referral = Plus::MetaAdReferralAttributes.from_facebook_response(response)
        params[:content_attributes][:referral] = referral if referral.present? && !@outgoing_echo
        params
      end
    end

    module InstagramBaseMessageBuilder
      private

      def message_params
        params = super
        referral = Plus::MetaAdReferralAttributes.from_instagram_messaging(@messaging)
        params[:content_attributes][:referral] = referral if referral.present? && !@outgoing_echo
        params
      end
    end
  end
end
