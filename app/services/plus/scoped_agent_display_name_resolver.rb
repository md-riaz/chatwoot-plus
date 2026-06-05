module Plus
  class ScopedAgentDisplayNameResolver
    FEATURE_KEY = 'scoped_agent_display_name'.freeze

    def self.call(user:, account: nil, inbox: nil)
      new(user: user, account: account, inbox: inbox).call
    end

    def initialize(user:, account: nil, inbox: nil)
      @user = user
      @inbox = inbox
      @account = account || inbox&.account
    end

    def call
      return if user.blank?
      return user.available_name unless user.is_a?(User)
      return user.available_name if account.blank?
      return user.available_name unless account.feature_enabled?(FEATURE_KEY)

      inbox_display_name.presence || account_display_name.presence || user.available_name
    end

    private

    attr_reader :user, :account, :inbox

    def account_display_name
      account_user&.display_name
    end

    def inbox_display_name
      inbox_member&.display_name
    end

    def account_user
      return @account_user if defined?(@account_user)

      @account_user = if user.account_users.loaded?
                        user.account_users.find { |account_user| account_user.account_id == account.id }
                      else
                        AccountUser.find_by(account_id: account.id, user_id: user.id)
                      end
    end

    def inbox_member
      return @inbox_member if defined?(@inbox_member)
      return if inbox.blank?

      @inbox_member = InboxMember.find_by(inbox_id: inbox.id, user_id: user.id)
    end
  end
end
