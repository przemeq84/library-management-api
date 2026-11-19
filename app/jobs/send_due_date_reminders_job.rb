# Finds borrowings that need a reminder and enqueues one SendReminderJob each.
# Scheduled twice a day in config/recurring.yml, once per reminder kind.
class SendDueDateRemindersJob < ApplicationJob
  RELATIONS = {
    "due_soon" => :due_soon_reminder_pending,
    "due_today" => :due_today_reminder_pending
  }.freeze

  def perform(kind)
    relation = RELATIONS.fetch(kind) { raise ArgumentError, "unknown reminder: #{kind.inspect}" }

    Borrowing.public_send(relation, Time.zone.today).find_in_batches do |borrowings|
      ActiveJob.perform_all_later(borrowings.map { |borrowing| SendReminderJob.new(borrowing, kind) })
    end
  end
end
