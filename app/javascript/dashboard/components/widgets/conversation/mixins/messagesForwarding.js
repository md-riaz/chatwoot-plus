import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';

export default {
  data() {
    return {
      forwardSelection: {
        isActive: false,
        selectedMessageIds: [],
      },
      showForwardModal: false,
    };
  },
  computed: {
    isForwardSelectionActive() {
      return this.forwardSelection.isActive;
    },
    forwardSelectedMessages() {
      if (!this.forwardSelection.isActive) {
        return [];
      }
      const selectedIds = this.forwardSelection.selectedMessageIds;
      if (!selectedIds.length) {
        return [];
      }
      return this.getMessages.filter(message =>
        selectedIds.includes(message.id)
      );
    },
    forwardSelectionCount() {
      return this.forwardSelection.selectedMessageIds.length;
    },
  },
  methods: {
    registerForwardingBusListener() {
      emitter.on(BUS_EVENTS.FORWARD_MESSAGES, this.onForwardMessagesStart);
    },
    removeForwardingBusListener() {
      emitter.off(BUS_EVENTS.FORWARD_MESSAGES, this.onForwardMessagesStart);
    },
    onForwardMessagesStart({ messageId } = {}) {
      if (!messageId) {
        return;
      }
      this.forwardSelection.isActive = true;
      this.forwardSelection.selectedMessageIds = [messageId];
    },
    toggleForwardSelection(messageId) {
      if (!this.forwardSelection.isActive) {
        return;
      }
      const selectedIds = this.forwardSelection.selectedMessageIds;
      const index = selectedIds.indexOf(messageId);
      if (index === -1) {
        selectedIds.push(messageId);
      } else {
        selectedIds.splice(index, 1);
      }
      if (!selectedIds.length) {
        this.cancelForwardSelection();
      }
    },
    cancelForwardSelection() {
      this.forwardSelection.isActive = false;
      this.forwardSelection.selectedMessageIds = [];
      this.showForwardModal = false;
    },
    openForwardModal() {
      if (!this.forwardSelection.selectedMessageIds.length) {
        return;
      }
      this.showForwardModal = true;
    },
    onForwardCompleted(conversation) {
      this.cancelForwardSelection();
      if (!conversation || !conversation.id) {
        return;
      }
      this.$router.push({
        name: 'inbox_conversation',
        params: {
          accountId: this.currentAccountId,
          conversation_id: conversation.id,
        },
      });
    },
  },
};
