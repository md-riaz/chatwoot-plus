class CreatePlusScheduledMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :plus_scheduled_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false
      t.datetime :send_at, null: false
      t.string :status, null: false, default: 'pending'
      t.jsonb :content_attributes, null: false, default: {}
      t.timestamps
    end

    add_index :plus_scheduled_messages, :send_at, where: "status = 'pending'"
  end
end
