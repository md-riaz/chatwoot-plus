import * as Sentry from '@sentry/vue';
import ConversationApi from 'dashboard/api/inbox/conversation';
import types from '../../../mutation-types';

const attachmentActions = {
  fetchAllAttachments: async ({ commit }, conversationId) => {
    let attachments = [];
    let meta = null;

    try {
      const { data } = await ConversationApi.getAllAttachments(
        conversationId,
        1
      );
      attachments = data.payload || [];
      if (data.meta) {
        meta = {
          page: 1,
          totalCount: data.meta?.total_count ?? attachments.length,
          pageSize: attachments.length,
        };
      }
    } catch (error) {
      Sentry.setContext('Conversation', {
        id: conversationId,
      });
      Sentry.captureException(error);
    } finally {
      commit(types.SET_ALL_ATTACHMENTS, {
        id: conversationId,
        data: attachments,
      });
      if (meta) {
        commit(types.SET_ATTACHMENTS_META, {
          id: conversationId,
          data: meta,
        });
      }
    }
  },

  loadMoreAttachments: async ({ state, commit }, conversationId) => {
    const existingAttachments = state.attachments[conversationId] || [];
    const meta = state.attachmentsMeta[conversationId] || {};
    const nextPage = (meta.page || 1) + 1;

    if (meta.totalCount && existingAttachments.length >= meta.totalCount) {
      return 0;
    }

    try {
      const { data } = await ConversationApi.getAllAttachments(
        conversationId,
        nextPage
      );
      const batch = data.payload || [];
      const combined = [
        ...existingAttachments,
        ...batch.filter(
          item =>
            !existingAttachments.some(
              existing => existing.id === item.id && existing.id !== undefined
            )
        ),
      ];

      commit(types.SET_ALL_ATTACHMENTS, {
        id: conversationId,
        data: combined,
      });
      commit(types.SET_ATTACHMENTS_META, {
        id: conversationId,
        data: {
          totalCount:
            data.meta?.total_count ?? meta.totalCount ?? combined.length,
          page: nextPage,
          pageSize: batch.length,
        },
      });

      return batch.length;
    } catch (error) {
      Sentry.setContext('Conversation', {
        id: conversationId,
      });
      Sentry.captureException(error);
      throw error;
    }
  },

  deleteConversationAttachments: async (
    { commit },
    { conversationId, attachmentIds = [], deleteAll = false }
  ) => {
    const payload = deleteAll
      ? { delete_all: true }
      : { attachment_ids: attachmentIds };

    try {
      const { data } = await ConversationApi.deleteAttachments(
        conversationId,
        payload
      );

      if (deleteAll) {
        commit(types.CLEAR_CONVERSATION_ATTACHMENTS, { id: conversationId });
      } else {
        commit(types.DELETE_CONVERSATION_ATTACHMENTS_BY_ID, {
          id: conversationId,
          attachmentIds,
          removedCount: data.count,
        });
      }

      return data;
    } catch (error) {
      Sentry.setContext('Conversation', {
        id: conversationId,
      });
      Sentry.captureException(error);
      throw error;
    }
  },
};

export default attachmentActions;
