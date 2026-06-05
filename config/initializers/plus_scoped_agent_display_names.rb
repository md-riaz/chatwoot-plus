require Rails.root.join('app/services/plus/scoped_agent_display_name_resolver')
require Rails.root.join('app/services/plus/scoped_agent_display_name_extensions')

Rails.application.config.to_prepare do
  Email::BaseBuilder.prepend(Plus::ScopedAgentDisplayNameExtensions::EmailBaseBuilder)
  ConversationDrop.prepend(Plus::ScopedAgentDisplayNameExtensions::ConversationDrop)
  MessageDrop.prepend(Plus::ScopedAgentDisplayNameExtensions::MessageDrop)
end
