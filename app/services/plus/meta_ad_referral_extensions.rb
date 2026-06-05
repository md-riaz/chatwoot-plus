# frozen_string_literal: true

module Plus
  module MetaAdReferralExtensions
    module FacebookMessageParser
      def referral
        @messaging['referral']
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
