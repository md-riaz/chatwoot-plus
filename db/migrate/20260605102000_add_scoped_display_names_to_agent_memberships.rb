class AddScopedDisplayNamesToAgentMemberships < ActiveRecord::Migration[7.0]
  def change
    add_column :account_users, :display_name, :string
    add_column :inbox_members, :display_name, :string
  end
end
