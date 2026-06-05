<script>
import { useAlert } from 'dashboard/composables';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TextArea from 'next/textarea/TextArea.vue';

export default {
  components: {
    SettingsToggleSection,
    NextButton,
    TextArea,
  },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      signature: '',
      isUpdatingSignature: false,
    };
  },
  watch: {
    inbox: {
      handler() {
        this.setDefaults();
      },
      immediate: true,
    },
  },
  methods: {
    setDefaults() {
      this.signature = this.inbox.additional_attributes?.signature || '';
    },
    async updateSignature() {
      this.isUpdatingSignature = true;
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            additional_attributes: {
              ...this.inbox.additional_attributes,
              signature: this.signature,
            },
          },
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      } finally {
        this.isUpdatingSignature = false;
      }
    },
  },
};
</script>

<template>
  <div class="mt-6 border-t border-n-slate-3 pt-6">
    <SettingsToggleSection
      :header="$t('INBOX_MGMT.SETTINGS_POPUP.SIGNATURE.TITLE')"
      :description="$t('INBOX_MGMT.SETTINGS_POPUP.SIGNATURE.DESCRIPTION')"
      hide-toggle
    >
      <template #editor>
        <TextArea
          v-model="signature"
          :placeholder="$t('INBOX_MGMT.SETTINGS_POPUP.SIGNATURE.PLACEHOLDER')"
          auto-height
          resize
          class="w-full [&>div]:!bg-transparent [&>div]:!border-none [&>div]:!border-0 [&>div]:px-0 [&>div]:pb-0 [&>div]:pt-0"
        />
        <div class="mt-3 flex justify-end">
          <NextButton
            :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
            :is-loading="isUpdatingSignature"
            @click="updateSignature"
          />
        </div>
      </template>
    </SettingsToggleSection>
  </div>
</template>
