# Preview at http://localhost:3000/rails/mailers/reminder_mailer (development only).
# Built from unsaved records, so it works on an empty database.
class ReminderMailerPreview < ActionMailer::Preview
  def due_soon
    ReminderMailer.with(borrowing: borrowing(due_on: Date.current + Borrowing::REMIND_BEFORE)).due_soon
  end

  def due_today
    ReminderMailer.with(borrowing: borrowing(due_on: Date.current)).due_today
  end

  # A due-today reminder caught up after a missed run.
  def due_today_overdue
    ReminderMailer.with(borrowing: borrowing(due_on: Date.current - 2)).due_today
  end

  private

  def borrowing(due_on:)
    Borrowing.new(
      book: Book.new(serial_number: "000042", title: "Pride and Prejudice", author: "Jane Austen"),
      reader: Reader.new(card_number: "000123", name: "Lara Croft", email: "lara@example.com"),
      borrowed_at: (due_on - Borrowing::DUE_AFTER).in_time_zone,
      due_on:
    )
  end
end
