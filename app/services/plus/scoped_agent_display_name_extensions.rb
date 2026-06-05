module Plus
  module ScopedAgentDisplayNameExtensions
    module EmailBaseBuilder
      private

      def custom_sender_name
        Plus::ScopedAgentDisplayNameResolver.call(user: message&.sender, account: account, inbox: inbox) || super
      end
    end

    module ConversationDrop
      private

      def message_sender_name(sender)
        return super unless sender.is_a?(User)

        Plus::ScopedAgentDisplayNameResolver.call(user: sender, account: @obj.account, inbox: @obj.inbox) || super
      end
    end

    module MessageDrop
      def sender_display_name
        return super unless @obj.sender.is_a?(User)

        Plus::ScopedAgentDisplayNameResolver.call(user: @obj.sender, account: @obj.account, inbox: @obj.inbox) || super
      end
    end
  end
end
