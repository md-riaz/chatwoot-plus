module Plus
  class ScheduledMessageRunnerJob < ApplicationJob
    queue_as :scheduled_jobs

    def perform
      Plus::ScheduledMessage.due.find_each do |scheduled_message|
        send_scheduled_message(scheduled_message)
      end
    end

    private

    def send_scheduled_message(scheduled_message)
      message = Messages::MessageBuilder.new(
        scheduled_message.user,
        scheduled_message.conversation,
        message_params(scheduled_message)
      ).perform

      scheduled_message.update!(status: message.persisted? ? 'sent' : 'failed')
    rescue StandardError => e
      Rails.logger.error("[Plus::ScheduledMessageRunnerJob] failed scheduled_message_id=#{scheduled_message.id}: #{e.class}: #{e.message}")
      scheduled_message.update!(status: 'failed')
    end

    def message_params(scheduled_message)
      {
        content: scheduled_message.content,
        message_type: :outgoing,
        private: false,
        content_attributes: scheduled_message.content_attributes || {}
      }
    end
  end
end
