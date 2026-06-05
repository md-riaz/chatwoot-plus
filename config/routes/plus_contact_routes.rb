scope module: :contacts do
  resources :group_members, only: [:index, :create, :destroy] do
    patch ':member_id', action: :update, on: :collection
  end
  patch :group_metadata, to: 'group_metadata#update'
  resource :group_invite, only: [:show], controller: :group_invites do
    post :revoke
  end
  resources :group_join_requests, only: [:index], controller: :group_join_requests do
    post :handle, on: :collection
  end
  resource :group_admin, only: [:update], controller: :group_admin do
    post :leave
  end
end
