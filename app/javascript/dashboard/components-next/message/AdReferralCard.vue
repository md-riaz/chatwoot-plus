<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

/**
 * @typedef {Object} ReferralBlock
 * @property {string} [source_platform] - 'facebook' | 'instagram'
 * @property {string} [source_id]       - Meta ad/post id
 * @property {string} [source_type]     - 'ad' | 'post' | 'link'
 * @property {string} [source_url]      - Public URL of the ad/post when supplied
 * @property {string} [referer_uri]     - Messenger referral URL when supplied
 * @property {string} [headline]        - Ad headline
 * @property {string} [ad_title]        - Messenger ads_context_data title
 * @property {string} [body]            - Ad body text
 * @property {string} [ref]             - Messenger referral parameter
 * @property {string} [ad_id]           - Messenger ad id
 * @property {string} [post_id]         - Messenger post id
 * @property {string} [product_id]      - Messenger product id
 * @property {string} [flow_id]         - Messenger welcome flow id
 * @property {string} [media_type]      - 'image' | 'video' | ...
 * @property {string} [media_url]       - Meta CDN URL (often expires)
 * @property {string} [photo_url]       - Messenger ad image URL
 * @property {string} [video_url]       - Messenger ad video thumbnail URL
 * @property {string} [image_url]       - Optional cover image (some payloads)
 * @property {string} [image]           - Legacy alias for image_url
 * @property {string} [thumbnail_url]   - Cached thumbnail when present
 * @property {string} [ctwa_clid]       - Click-to-WhatsApp click id (attribution only)
 */

const props = defineProps({
  referral: {
    type: Object,
    required: true,
    validator: value => value && typeof value === 'object',
  },
});

const { t } = useI18n();

const sourcePlatform = computed(() => {
  const platform = String(props.referral?.source_platform || '').toLowerCase();
  if (['facebook', 'instagram'].includes(platform)) return platform;

  const url = String(
    props.referral?.source_url || props.referral?.referer_uri || ''
  );
  if (/(^|\.)instagram\.com\b/i.test(url)) return 'instagram';
  if (/(^|\.)(facebook\.com|fb\.com|fb\.me)\b/i.test(url)) return 'facebook';
  return 'unknown';
});

const sourceType = computed(() => {
  const type = String(props.referral?.source_type || '').toLowerCase();
  if (['ad', 'post', 'link'].includes(type)) return type;
  if (String(props.referral?.source || '').toUpperCase() === 'SHORTLINK')
    return 'link';
  return 'ad';
});

const sourceLabel = computed(() => {
  const labels = {
    ad: {
      facebook: t('CONVERSATION.WHATSAPP_AD_REFERRAL.FROM_AD_FACEBOOK'),
      instagram: t('CONVERSATION.WHATSAPP_AD_REFERRAL.FROM_AD_INSTAGRAM'),
      unknown: t('CONVERSATION.WHATSAPP_AD_REFERRAL.FROM_AD_UNKNOWN'),
    },
    post: {
      facebook: t('CONVERSATION.WHATSAPP_AD_REFERRAL.FROM_POST_FACEBOOK'),
      instagram: t('CONVERSATION.WHATSAPP_AD_REFERRAL.FROM_POST_INSTAGRAM'),
      unknown: t('CONVERSATION.WHATSAPP_AD_REFERRAL.FROM_POST_UNKNOWN'),
    },
    link: {
      facebook: t('CONVERSATION.WHATSAPP_AD_REFERRAL.FROM_LINK_FACEBOOK'),
      instagram: t('CONVERSATION.WHATSAPP_AD_REFERRAL.FROM_LINK_INSTAGRAM'),
      unknown: t('CONVERSATION.WHATSAPP_AD_REFERRAL.FROM_LINK_UNKNOWN'),
    },
  };

  return labels[sourceType.value][sourcePlatform.value];
});

const sourceIdLabel = computed(() => {
  if (sourceType.value === 'post') {
    return t('CONVERSATION.WHATSAPP_AD_REFERRAL.POST_ID');
  }

  if (sourceType.value === 'link') {
    return t('CONVERSATION.WHATSAPP_AD_REFERRAL.REF');
  }

  return t('CONVERSATION.WHATSAPP_AD_REFERRAL.AD_ID');
});

const headline = computed(() =>
  String(props.referral?.headline || props.referral?.ad_title || '').trim()
);
const body = computed(() =>
  String(props.referral?.body || props.referral?.ref || '').trim()
);
const sourceId = computed(() =>
  String(
    props.referral?.source_id ||
      props.referral?.ad_id ||
      props.referral?.post_id ||
      props.referral?.ref ||
      ''
  ).trim()
);
const sourceUrl = computed(
  () => props.referral?.source_url || props.referral?.referer_uri || ''
);

const extraDetails = computed(() => {
  const details = [];
  if (props.referral?.post_id && props.referral.post_id !== sourceId.value) {
    details.push({
      label: t('CONVERSATION.WHATSAPP_AD_REFERRAL.POST_ID'),
      value: props.referral.post_id,
    });
  }
  if (props.referral?.product_id) {
    details.push({
      label: t('CONVERSATION.WHATSAPP_AD_REFERRAL.PRODUCT_ID'),
      value: props.referral.product_id,
    });
  }
  if (props.referral?.flow_id) {
    details.push({
      label: t('CONVERSATION.WHATSAPP_AD_REFERRAL.FLOW_ID'),
      value: props.referral.flow_id,
    });
  }
  return details;
});

// Meta referral payloads differ by channel. Keep every display key explicit:
// WhatsApp CTWA uses headline/body/source_url, while Messenger ads use
// ads_context_data-derived ad_title/photo_url/video_url/product_id/flow_id.
const imageUrl = computed(() => {
  const r = props.referral || {};
  if (typeof r.thumbnail_url === 'string' && r.thumbnail_url) {
    return r.thumbnail_url;
  }
  if (typeof r.image_url === 'string' && r.image_url) return r.image_url;
  if (typeof r.photo_url === 'string' && r.photo_url) return r.photo_url;
  if (typeof r.image === 'string' && r.image) return r.image;
  if (r.media_type === 'image' && typeof r.media_url === 'string') {
    return r.media_url;
  }
  if (typeof r.video_url === 'string' && r.video_url) return r.video_url;
  return '';
});

const hasAnyContent = computed(() => {
  return Boolean(
    headline.value ||
      body.value ||
      sourceId.value ||
      sourceUrl.value ||
      imageUrl.value ||
      extraDetails.value.length
  );
});

// Meta's scontent.fbcdn.net image URLs expire after a few hours; failing
// silently is the right UX — the rest of the card is still useful.
const handleImageError = event => {
  if (event?.target) {
    event.target.style.display = 'none';
  }
};
</script>

<template>
  <div
    v-if="hasAnyContent"
    class="flex gap-2 items-start p-2 -mx-1 mb-2 rounded-lg text-start bg-n-alpha-black1"
    data-testid="ad-referral-card"
  >
    <img
      v-if="imageUrl"
      :src="imageUrl"
      :alt="headline || sourceLabel"
      class="object-cover flex-shrink-0 w-12 h-12 rounded-md skip-context-menu"
      loading="lazy"
      decoding="async"
      referrerpolicy="no-referrer"
      @error="handleImageError"
    />
    <div class="flex flex-col flex-1 gap-0.5 min-w-0">
      <span class="text-xs font-medium truncate text-n-slate-11">
        {{ sourceLabel }}
      </span>
      <span
        v-if="sourceId"
        class="text-[11px] font-mono truncate text-n-slate-10"
        :title="sourceId"
      >
        {{
          $t('CONVERSATION.WHATSAPP_AD_REFERRAL.ID_LABEL', {
            label: sourceIdLabel,
            id: sourceId,
          })
        }}
      </span>
      <span
        v-if="headline"
        class="text-sm font-semibold truncate text-n-slate-12"
        :title="headline"
      >
        {{ headline }}
      </span>
      <p
        v-if="body"
        class="text-xs break-words line-clamp-2 text-n-slate-11"
        :title="body"
      >
        {{ body }}
      </p>
      <span
        v-for="detail in extraDetails"
        :key="`${detail.label}-${detail.value}`"
        class="text-[11px] font-mono truncate text-n-slate-10"
        :title="detail.value"
      >
        {{
          $t('CONVERSATION.WHATSAPP_AD_REFERRAL.ID_LABEL', {
            label: detail.label,
            id: detail.value,
          })
        }}
      </span>
      <a
        v-if="sourceUrl"
        :href="sourceUrl"
        target="_blank"
        rel="noreferrer noopener nofollow"
        class="text-xs underline truncate text-n-blue-11 skip-context-menu"
        :title="sourceUrl"
      >
        {{ $t('CONVERSATION.WHATSAPP_AD_REFERRAL.VIEW_AD') }}
      </a>
    </div>
  </div>
</template>
