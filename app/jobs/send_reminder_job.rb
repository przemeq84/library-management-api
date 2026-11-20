class SendReminderJob < ApplicationJob
  class DeliveryFailed < StandardError; end

  retry_on DeliveryFailed, wait: :polynomially_longer, attempts: 5

  def perform(borrowing, reminder_name)
    reminder = Borrowing::Reminder.fetch(reminder_name)
    return unless borrowing.claim_reminder(reminder)

    begin
      ReminderMailer.with(borrowing:).public_send(reminder.mailer_action).deliver_now
    rescue StandardError => error
      borrowing.release_reminder(reminder)
      raise DeliveryFailed, error.message
    end
  end
end
