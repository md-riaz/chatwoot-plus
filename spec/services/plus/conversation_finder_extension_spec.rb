require 'rails_helper'

RSpec.describe Plus::ConversationFinderExtension do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account) }
  let(:other_agent) { create(:user, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:internal_channel) { Channel::Internal.create!(account: account) }
  let(:internal_inbox) { create(:inbox, account: account, channel: internal_channel) }
  let!(:mine) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let!(:assigned) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }
  let!(:unassigned) { create(:conversation, account: account, inbox: inbox, assignee: nil) }
  let!(:group_conversation) { create(:conversation, account: account, inbox: inbox, group: true) }
  let!(:internal_conversation) { create(:conversation, account: account, inbox: internal_inbox) }

  describe '.filter_by_assignee_type' do
    it 'returns non-group unassigned conversations' do
      result = described_class.filter_by_assignee_type(account.conversations, 'unassigned', agent)

      expect(result).to contain_exactly(unassigned, internal_conversation)
    end

    it 'returns group conversations' do
      result = described_class.filter_by_assignee_type(account.conversations, 'groups', agent)

      expect(result).to contain_exactly(group_conversation)
    end
  end

  describe '.filter_by_conversation_type' do
    it 'returns internal inbox conversations' do
      result = described_class.filter_by_conversation_type(account.conversations, 'internal', account, agent)

      expect(result).to contain_exactly(internal_conversation)
    end
  end

  describe '.counts' do
    it 'counts assigned, non-group unassigned, all, and group conversations' do
      result = described_class.counts(account.conversations, agent)

      expect(result).to eq(
        mine_count: 1,
        assigned_count: 3,
        unassigned_count: 2,
        all_count: 5,
        group_count: 1
      )
    end
  end
end
