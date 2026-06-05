scope module: :omni_ai do
  get  'omni_ai/comments_page/stats',                    to: 'comments_proxy#stats'
  get  'omni_ai/comments_page/by-post',                  to: 'comments_proxy#by_post'
  get  'omni_ai/comments_page/post/:post_id',            to: 'comments_proxy#post_comments'
  get  'omni_ai/comments_page/post-info/:post_id',       to: 'comments_proxy#post_info'
  get  'omni_ai/comments_page/commenter/:commenter_id',  to: 'comments_proxy#commenter_history'
  put  'omni_ai/comments_page/:id/reply',                to: 'comments_proxy#reply'
  post 'omni_ai/comments_page/:comment_id/dm',           to: 'comments_proxy#send_dm'
  get  'omni_ai/comments_page',                          to: 'comments_proxy#index'
end
