class Api::V1::Accounts::Plus::ScopedAgentDisplayNamesController < Api::V1::Accounts::BaseController
  before_action :ensure_feature_enabled

  def index
    authorize Current.account, :show?

    render json: scoped_display_names
  end

  def account
    authorize Current.account, :update?

    account_user.update!(display_name: display_name_param)
    render json: scoped_display_names
  end

  def inbox
    authorize inbox_record, :update?

    inbox_member.update!(display_name: display_name_param)
    render json: scoped_display_names
  end

  private

  def scoped_display_names
    {
      account_display_names: Current.account.account_users.pluck(:user_id, :display_name).to_h,
      inbox_display_names: inbox_display_names
    }
  end

  def inbox_display_names
    return {} if params[:inbox_id].blank?

    inbox_record.inbox_members.pluck(:user_id, :display_name).to_h
  end

  def account_user
    @account_user ||= Current.account.account_users.find_by!(user_id: params[:user_id])
  end

  def inbox_member
    @inbox_member ||= inbox_record.inbox_members.find_by!(user_id: params[:user_id])
  end

  def inbox_record
    @inbox_record ||= Current.account.inboxes.find(params[:inbox_id])
  end

  def display_name_param
    params[:display_name].to_s.strip.presence
  end

  def ensure_feature_enabled
    return if Current.account.feature_enabled?(Plus::ScopedAgentDisplayNameResolver::FEATURE_KEY)

    render json: { error: 'Scoped agent display name is not enabled for this account' }, status: :forbidden
  end
end
