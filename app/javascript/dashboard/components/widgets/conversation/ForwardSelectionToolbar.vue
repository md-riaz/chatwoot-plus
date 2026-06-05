<script>
import ForwardMessagesModal from './ForwardMessagesModal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: { ForwardMessagesModal, NextButton },
  props: {
    active: {
      type: Boolean,
      default: false,
    },
    show: {
      type: Boolean,
      default: false,
    },
    selectedMessages: {
      type: Array,
      default: () => [],
    },
    conversationId: {
      type: Number,
      default: null,
    },
    selectedCount: {
      type: Number,
      default: 0,
    },
  },
  emits: ['update:show', 'forwarded', 'close', 'cancel', 'open'],
};
</script>

<template>
  <ForwardMessagesModal
    v-if="active"
    :show="show"
    :selected-messages="selectedMessages"
    :conversation-id="conversationId"
    @update:show="$emit('update:show', $event)"
    @forwarded="$emit('forwarded', $event)"
    @close="$emit('close')"
  />
  <div
    v-if="active"
    class="flex items-center justify-between mx-2 mt-2 mb-1 rounded-lg bg-n-alpha-2 px-3 py-2"
  >
    <p class="m-0 text-xs font-medium text-n-slate-12">
      {{
        $t('CONVERSATION.FORWARD_MESSAGES.SELECTED_COUNT', {
          count: selectedCount,
        })
      }}
    </p>
    <div class="flex items-center gap-2">
      <NextButton
        variant="ghost"
        color="slate"
        size="xs"
        :label="$t('CONVERSATION.FORWARD_MESSAGES.CANCEL')"
        @click="$emit('cancel')"
      />
      <NextButton
        color="blue"
        size="xs"
        :disabled="selectedCount === 0"
        :label="$t('CONVERSATION.FORWARD_MESSAGES.ACTION_LABEL')"
        @click="$emit('open')"
      />
    </div>
  </div>
</template>
