class RenameBorrowingReminderColumnsToSentAt < ActiveRecord::Migration[8.1]
  def change
    rename_column :borrowings, :due_soon_reminder_scheduled_at, :due_soon_reminder_sent_at
    rename_column :borrowings, :due_today_reminder_scheduled_at, :due_today_reminder_sent_at
  end
end
