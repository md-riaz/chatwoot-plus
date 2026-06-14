module Plus
  module ConversationFinderExtension
    module_function

    def filter_by_assignee_type(conversations, assignee_type, current_user)
      case assignee_type
      when 'me'
        conversations.assigned_to(current_user)
      when 'unassigned'
        conversations.non_group_conversations.unassigned
      when 'groups'
        conversations.group_conversations
      when 'assigned'
        conversations.assigned
      else
        conversations
      end
    end

    def filter_by_conversation_type(conversations, conversation_type, current_account, current_user)
      case conversation_type
      when 'mention'
        conversation_ids = current_account.mentions.where(user: current_user).pluck(:conversation_id)
        conversations.where(id: conversation_ids)
      when 'participating'
        current_user.participating_conversations.where(account_id: current_account.id)
      when 'unattended'
        conversations.unattended
      when 'internal'
        conversations.where(inbox_id: current_account.inboxes.where(channel_type: 'Channel::Internal'))
      else
        conversations
      end
    end

    def counts(conversations, current_user)
      return legacy_counts(conversations, current_user) if conversations.limit_value || conversations.offset_value || conversations.eager_loading?

      conversation_table = Conversation.arel_table
      values = conversations.unscope(:order).pick(
        Arel.sql("COUNT(*) FILTER (WHERE assignee_id = #{current_user.id})"),
        Arel.sql("COUNT(*) FILTER (WHERE assignee_id IS NULL AND #{conversation_table[:group].eq(false).to_sql})"),
        Arel.sql('COUNT(*)'),
        Arel.sql("COUNT(*) FILTER (WHERE #{conversation_table[:group].eq(true).to_sql})")
      )

      build_count_hash(values || [0, 0, 0, 0])
    end

    def legacy_counts(conversations, current_user)
      build_count_hash([
                         conversations.assigned_to(current_user).count,
                         conversations.non_group_conversations.unassigned.count,
                         conversations.count,
                         conversations.group_conversations.count
                       ])
    end

    def build_count_hash(values)
      mine_count, unassigned_count, all_count, group_count = values
      {
        mine_count: mine_count,
        unassigned_count: unassigned_count,
        all_count: all_count,
        group_count: group_count,
        assigned_count: all_count - unassigned_count
      }
    end
  end
end
