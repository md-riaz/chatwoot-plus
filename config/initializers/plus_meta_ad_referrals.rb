# frozen_string_literal: true

Rails.application.config.to_prepare do
  Integrations::Facebook::MessageParser.prepend(Plus::MetaAdReferralExtensions::FacebookMessageParser)
  Messages::Facebook::MessageBuilder.prepend(Plus::MetaAdReferralExtensions::FacebookMessageBuilder)
  Messages::Instagram::BaseMessageBuilder.prepend(Plus::MetaAdReferralExtensions::InstagramBaseMessageBuilder)
end
