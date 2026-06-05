<script setup>
import { useI18n } from 'vue-i18n';

import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
</script>

<template>
  <section
    class="flex flex-col items-center justify-center w-full h-full bg-n-surface-1"
  >
    <div
      class="flex flex-col max-w-md px-6 py-6 border shadow bg-n-solid-1 rounded-xl border-n-weak"
    >
      <div class="flex items-center w-full gap-2 mb-4">
        <span
          class="flex items-center justify-center w-6 h-6 rounded-full bg-n-solid-blue"
        >
          <Icon
            class="flex-shrink-0 text-n-brand size-[14px]"
            icon="i-lucide-lock-keyhole"
          />
        </span>
        <span class="text-base font-medium text-n-slate-12">
          {{ t('KANBAN.FEATURE_DISABLED.TITLE') }}
        </span>
      </div>
      <p class="mb-4 text-sm font-normal text-n-slate-11">
        {{ t('KANBAN.FEATURE_DISABLED.DESCRIPTION') }}
      </p>
    </div>
  </section>
</template>
