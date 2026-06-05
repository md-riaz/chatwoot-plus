import conversationApi from 'dashboard/api/inbox/conversation';

const GROUP_CONTACT_MENTION_REGEX =
  /\[@([^\]]+)\]\(mention:\/\/group[_-]contact\/(\d+)\/([^)]+)\)|mention:\/\/group[_-]contact\/(\d+)\/([^\s)]+)/g;

export default {
  data() {
    return {
      showGroupMentions: false,
      groupMentionContacts: [],
      isLoadingGroupMentionContacts: false,
      groupMentionFetchTimeout: null,
    };
  },
  computed: {
    canUseGroupMentions() {
      return (
        this.currentChat?.group &&
        this.isAUnoapiChannel &&
        !this.isOnPrivateNote
      );
    },
  },
  watch: {
    showGroupMentions(value) {
      if (value) this.fetchGroupMentionContacts(this.groupMentionSearchTerm());
      if (!value) this.groupMentionContacts = [];
    },
    message() {
      if (this.showGroupMentions) this.debouncedFetchGroupMentionContacts();
    },
  },
  unmounted() {
    clearTimeout(this.groupMentionFetchTimeout);
  },
  methods: {
    groupMentionSearchTerm(message = this.message) {
      const match = message.match(/(?:^|\s)@([^\s@]*)$/);
      return match ? match[1] : '';
    },
    debouncedFetchGroupMentionContacts() {
      clearTimeout(this.groupMentionFetchTimeout);
      this.groupMentionFetchTimeout = setTimeout(() => {
        this.fetchGroupMentionContacts(this.groupMentionSearchTerm());
      }, 250);
    },
    async fetchGroupMentionContacts(query = '') {
      const normalizedQuery = query.trim();
      if (normalizedQuery.length < 2) {
        this.groupMentionContacts = [];
        return;
      }

      if (!this.canUseGroupMentions || this.isLoadingGroupMentionContacts) {
        this.groupMentionContacts = [];
        return;
      }

      this.isLoadingGroupMentionContacts = true;
      try {
        const { data } = await conversationApi.fetchGroupContacts(
          this.currentChat.id,
          1,
          normalizedQuery
        );
        this.groupMentionContacts = (data.payload || [])
          .map(member => this.normalizeGroupMentionContact(member))
          .filter(contact => contact.id && contact.bsuid);
      } finally {
        this.isLoadingGroupMentionContacts = false;
      }
    },
    normalizeGroupMentionContact(member = {}) {
      const contact = member.contact || {};
      const metadata = member.metadata || {};
      const phoneNumber =
        contact.phone_number?.replace(/\D/g, '') ||
        metadata.wa_id?.replace(/\D/g, '') ||
        (!member.participant_identifier?.includes('@')
          ? member.participant_identifier?.replace(/\D/g, '')
          : '');
      const bsuid =
        contact.bsuid ||
        metadata.user_id ||
        metadata.lid ||
        (metadata.jid?.endsWith('@lid') ? metadata.jid : '') ||
        phoneNumber;
      const name =
        contact.name ||
        contact.whatsapp_username ||
        metadata.name ||
        member.participant_identifier ||
        bsuid;

      return {
        id: contact.id,
        bsuid,
        name,
        displayName: name,
        whatsapp_username: contact.whatsapp_username,
        phone_number: contact.phone_number,
        thumbnail: contact.thumbnail,
      };
    },
    groupMentionAttributesFor(message = '') {
      if (!this.canUseGroupMentions || !message) return [];

      const mentionsByContactId = new Map(
        this.groupMentionContacts.map(contact => [
          contact.id?.toString(),
          contact,
        ])
      );

      return Array.from(message.matchAll(GROUP_CONTACT_MENTION_REGEX)).flatMap(
        match => {
          const contactId = match[2] || match[4];
          const mentionName = match[3] || match[5] || match[1];
          const contact = mentionsByContactId.get(contactId);
          if (!contact?.bsuid) return [];

          return {
            contact_id: contact.id,
            name: decodeURIComponent(mentionName || ''),
            bsuid: contact.bsuid,
          };
        }
      );
    },
    withGroupMentionsInPayload(payload, message = payload.message) {
      const groupMentions = this.groupMentionAttributesFor(message);
      if (!groupMentions.length) return payload;

      return {
        ...payload,
        contentAttributes: {
          ...(payload.contentAttributes || {}),
          group_mentions: groupMentions,
        },
      };
    },
  },
};
