namespace :plus do
  resource :scoped_agent_display_names, only: [:index], controller: 'scoped_agent_display_names' do
    patch :account
    patch :inbox
  end
end
