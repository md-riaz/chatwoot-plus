namespace :plus do
  get :scoped_agent_display_names, to: 'scoped_agent_display_names#index'
  resource :scoped_agent_display_names, only: [], controller: 'scoped_agent_display_names' do
    patch :account
    patch :inbox
  end
end
