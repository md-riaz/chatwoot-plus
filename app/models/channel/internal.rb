# == Schema Information
#
# Table name: channel_internal
#
#  id         :bigint           not null, primary key
#  account_id :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Channel::Internal < ApplicationRecord
  include Channelable

  self.table_name = 'channel_internal'
  EDITABLE_ATTRS = [].freeze

  validates :account_id, presence: true

  def name
    'Internal Chat'
  end

  def medium
    'internal'
  end
end
