/* global axios */
import ApiClient from '../../ApiClient';
import ContactsAPI from '../../contacts';
import camelcaseKeys from 'camelcase-keys';

const normalizePhoneKey = value => String(value || '').replace(/[^\d+]/g, '');
class VoiceAPI extends ApiClient {
  constructor() {
    super('voice', { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  initiateCall(contactId, inboxId) {
    return ContactsAPI.initiateCall(contactId, inboxId).then(r => r.data);
  }

  async initiateCallByPhone(phoneNumber, inboxId) {
    const normalizedPhoneNumber = normalizePhoneKey(phoneNumber);
    const {
      data: { payload: contacts = [] },
    } = await ContactsAPI.search(normalizedPhoneNumber, 1, 'name', '', {
      skipMinLength: true,
    });

    const existingContact = contacts.find(contact => {
      return (
        normalizePhoneKey(contact.phone_number) === normalizedPhoneNumber ||
        normalizePhoneKey(contact.phoneNumber) === normalizedPhoneNumber
      );
    });

    const contact = existingContact
      ? camelcaseKeys(existingContact, { deep: true })
      : await ContactsAPI.create({
          name: normalizedPhoneNumber.startsWith('+')
            ? normalizedPhoneNumber.slice(1)
            : normalizedPhoneNumber,
          phone_number: normalizedPhoneNumber,
        }).then(({ data }) =>
          camelcaseKeys(data.payload.contact, { deep: true })
        );

    return this.initiateCall(contact.id, inboxId);
  }

  leaveConference({ inboxId, conversationId, callSid }) {
    return axios
      .delete(`${this.baseUrl()}/inboxes/${inboxId}/conference`, {
        params: { conversation_id: conversationId, call_sid: callSid },
      })
      .then(r => r.data);
  }

  joinConference({ conversationId, inboxId, callSid }) {
    return axios
      .post(`${this.baseUrl()}/inboxes/${inboxId}/conference`, {
        conversation_id: conversationId,
        call_sid: callSid,
      })
      .then(r => r.data);
  }

  getToken(inboxId) {
    if (!inboxId) return Promise.reject(new Error('Inbox ID is required'));
    return axios
      .get(`${this.baseUrl()}/inboxes/${inboxId}/conference/token`)
      .then(r => r.data);
  }

  notifyIncomingCall({ inboxId, callSid, fromNumber }) {
    return axios
      .post(`${this.baseUrl()}/inboxes/${inboxId}/conference`, {
        call_sid: callSid,
        from_number: fromNumber,
      })
      .then(r => r.data);
  }

  updateCallStatus({
    inboxId,
    conversationId,
    callSid,
    callStatus,
    reason,
    timestamp,
  }) {
    return axios
      .patch(`${this.baseUrl()}/inboxes/${inboxId}/conference`, {
        conversation_id: conversationId,
        call_sid: callSid,
        call_status: callStatus,
        reason,
        timestamp,
      })
      .then(r => r.data);
  }

  transferCall({ inboxId, conversationId, targetAgentId, callSid }) {
    return axios
      .post(`${this.baseUrl()}/inboxes/${inboxId}/conference/transfer`, {
        conversation_id: conversationId,
        target_agent_id: targetAgentId,
        call_sid: callSid,
      })
      .then(r => r.data);
  }
}

export default new VoiceAPI();
