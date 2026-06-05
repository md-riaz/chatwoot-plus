export default {
  data() {
    return {
      showScheduledMessageModal: false,
      attachedContacts: [],
      showContactAttachmentModal: false,
      showStickerPicker: false,
    };
  },
  methods: {
    openContactAttachmentModal() {
      this.showContactAttachmentModal = true;
    },
    hideContactAttachmentModal() {
      this.showContactAttachmentModal = false;
    },
    setAttachedContacts(contacts) {
      this.attachedContacts = contacts;
      this.hideContactAttachmentModal();
    },
    removeAttachedContact(contactId) {
      this.attachedContacts = this.attachedContacts.filter(
        contact => contact.id !== contactId
      );
    },
    showStickerPickerModal() {
      this.showStickerPicker = true;
    },
    hideStickerPickerModal() {
      this.showStickerPicker = false;
    },
    sendStickerMessage(sticker) {
      this.sendMessage({
        conversationId: this.currentChat.id,
        content_type: 'sticker',
        content_attributes: {
          sticker_id: sticker.id,
          sticker_url: sticker.file_url,
        },
      });
    },
    openScheduleModal() {
      this.showScheduledMessageModal = true;
    },
    onScheduledMessageCreated() {
      this.clearMessage();
      this.showScheduledMessageModal = false;
    },
    serializeAttachedContact(contact) {
      const fullName =
        contact.formattedName ||
        contact.name ||
        [contact.firstName, contact.lastName].filter(Boolean).join(' ') ||
        '';
      const [firstName, ...lastNameParts] = fullName.split(' ').filter(Boolean);

      return {
        id: contact.id,
        formatted_name: fullName,
        first_name: firstName || fullName,
        last_name: lastNameParts.join(' ') || '',
        phone_number: contact.phoneNumber || contact.phone_number || '',
        email: contact.email || '',
      };
    },
  },
};
