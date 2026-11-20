class SendDueDateRemindersJob < ApplicationJob
  def perform(reminder_name)
    reminder = Borrowing::Reminder.fetch(reminder_name)

    Borrowing.reminder_pending(reminder, Time.zone.today).find_in_batches do |borrowings|
      ActiveJob.perform_all_later(borrowings.map { |borrowing| SendReminderJob.new(borrowing, reminder.name) })
    end
  end
end
