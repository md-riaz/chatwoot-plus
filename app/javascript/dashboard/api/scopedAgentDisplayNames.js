/* global axios */
import ApiClient from './ApiClient';

class ScopedAgentDisplayNames extends ApiClient {
  constructor() {
    super('plus/scoped_agent_display_names', { accountScoped: true });
  }

  list({ inboxId } = {}) {
    return axios.get(this.url, { params: { inbox_id: inboxId } });
  }

  updateAccount({ userId, displayName, inboxId }) {
    return axios.patch(`${this.url}/account`, {
      user_id: userId,
      display_name: displayName,
      inbox_id: inboxId,
    });
  }

  updateInbox({ inboxId, userId, displayName }) {
    return axios.patch(`${this.url}/inbox`, {
      inbox_id: inboxId,
      user_id: userId,
      display_name: displayName,
    });
  }
}

export default new ScopedAgentDisplayNames();
