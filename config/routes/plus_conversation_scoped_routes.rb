resources :scheduled_messages, only: [:index, :create, :update, :destroy]
resources :recurring_scheduled_messages, only: [:index, :create, :update, :destroy]
resources :group_contacts, only: [:index, :create] do
  delete :destroy, on: :collection
end
resource :group, only: [:show, :update], controller: :group do
  post :sync
  resource :invite_link, only: [:show], controller: :group_invite_link do
    post :reset
  end
  resources :join_requests, only: [:index, :create], controller: :group_join_requests do
    delete :destroy, on: :collection
  end
end
