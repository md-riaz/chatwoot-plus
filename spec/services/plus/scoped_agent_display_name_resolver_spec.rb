require 'rails_helper'

RSpec.describe Plus::ScopedAgentDisplayNameResolver do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:user) { create(:user, name: 'John Smith', display_name: 'John') }

  before do
    create(:account_user, account: account, user: user, display_name: account_display_name)
    create(:inbox_member, inbox: inbox, user: user, display_name: inbox_display_name)
    allow(account).to receive(:feature_enabled?).with('scoped_agent_display_name').and_return(feature_enabled)
  end

  let(:account_display_name) { nil }
  let(:inbox_display_name) { nil }
  let(:feature_enabled) { true }

  it 'returns the inbox display name first' do
    account_user = AccountUser.find_by(account: account, user: user)
    account_user.update!(display_name: 'Account John')
    InboxMember.find_by(inbox: inbox, user: user).update!(display_name: 'Inbox John')

    expect(described_class.call(user: user, inbox: inbox)).to eq('Inbox John')
  end

  it 'falls back to the account display name' do
    AccountUser.find_by(account: account, user: user).update!(display_name: 'Account John')

    expect(described_class.call(user: user, inbox: inbox)).to eq('Account John')
  end

  it 'falls back to the global available name' do
    expect(described_class.call(user: user, inbox: inbox)).to eq('John')
  end

  context 'when the feature is disabled' do
    let(:feature_enabled) { false }
    let(:account_display_name) { 'Account John' }
    let(:inbox_display_name) { 'Inbox John' }

    it 'uses the global available name' do
      expect(described_class.call(user: user, inbox: inbox)).to eq('John')
    end
  end
end
