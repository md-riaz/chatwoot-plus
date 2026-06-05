# frozen_string_literal: true

module Plus
  class MetaAdReferralAttributes
    FACEBOOK_PLATFORM = 'facebook'
    INSTAGRAM_PLATFORM = 'instagram'

    def self.from_facebook_response(response)
      return unless response.respond_to?(:referral)

      build(response.referral, FACEBOOK_PLATFORM)
    end

    def self.from_instagram_messaging(messaging)
      build(messaging[:referral] || messaging['referral'], INSTAGRAM_PLATFORM)
    end

    def self.build(referral, platform)
      return unless referral.is_a?(Hash)

      attributes = referral.deep_dup
      attributes['source_platform'] ||= platform
      attributes['source_type'] ||= 'ad' if attributes['source'].to_s.casecmp('ADS').zero?
      attributes['source_id'] ||= attributes['ad_id'] || attributes['post_id']
      attributes['source_url'] ||= attributes['referer_uri']
      attributes
    end
  end
end
