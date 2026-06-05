module Plus
  class ScheduledMessage < ApplicationRecord
    self.table_name = 'plus_scheduled_messages'

    belongs_to :account
    belongs_to :conversation
    belongs_to :user

    STATUSES = %w[pending sent failed].freeze

    validates :content, presence: true
    validates :send_at, presence: true
    validates :status, inclusion: { in: STATUSES }

    scope :pending, -> { where(status: 'pending') }
    scope :due, -> { pending.where('send_at <= ?', Time.current) }
  end
end
