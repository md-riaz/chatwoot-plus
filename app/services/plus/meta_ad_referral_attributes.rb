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
      ads_context = attributes['ads_context_data'] || attributes[:ads_context_data] || {}
      ads_context = ads_context.with_indifferent_access if ads_context.respond_to?(:with_indifferent_access)

      attributes['source_platform'] ||= platform
      attributes['source_type'] ||= 'ad' if attributes['source'].to_s.casecmp('ADS').zero?
      attributes['source_type'] ||= 'link' if attributes['source'].to_s.casecmp('SHORTLINK').zero?
      attributes['source_id'] ||= attributes['ad_id'] || attributes['post_id'] || ads_context[:post_id]
      attributes['source_url'] ||= attributes['referer_uri']
      attributes['headline'] ||= ads_context[:ad_title]
      attributes['image_url'] ||= ads_context[:photo_url]
      attributes['media_url'] ||= ads_context[:video_url]
      attributes['thumbnail_url'] ||= ads_context[:video_url]
      attributes['post_id'] ||= ads_context[:post_id]
      attributes['product_id'] ||= ads_context[:product_id]
      attributes['flow_id'] ||= ads_context[:flow_id]
      attributes
    end
  end
end
