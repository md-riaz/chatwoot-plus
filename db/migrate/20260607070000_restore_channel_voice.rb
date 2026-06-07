class RestoreChannelVoice < ActiveRecord::Migration[7.0]
  def up
    return if table_exists?(:channel_voice)

    create_table :channel_voice do |t|
      t.string :phone_number, null: false
      t.string :provider, null: false, default: 'twilio'
      t.jsonb :provider_config, null: false
      t.integer :account_id, null: false
      t.jsonb :additional_attributes, default: {}

      t.timestamps
    end

    add_index :channel_voice, :phone_number, unique: true
    add_index :channel_voice, :account_id
  end

  def down
    drop_table :channel_voice, if_exists: true
  end
end
