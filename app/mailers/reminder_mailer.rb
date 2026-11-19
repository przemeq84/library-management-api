class ReminderMailer < ApplicationMailer
  before_action :load_borrowing

  def due_soon
    return unless deliverable?

    mail(to: @reader.email, subject: "Reminder: \"#{@book.title}\" is due on #{l(@borrowing.due_on, format: :long)}")
  end

  # Also sent late (catch-up after a missed run), so it says "was due" once the due date has passed.
  def due_today
    return unless deliverable?

    @overdue = @borrowing.due_on < Time.zone.today
    subject = @overdue ? "was due on #{l(@borrowing.due_on, format: :long)}" : "is due today"
    mail(to: @reader.email, subject: "Reminder: \"#{@book.title}\" #{subject}")
  end

  private

  def load_borrowing
    @borrowing = params.fetch(:borrowing)
    @book = @borrowing.book
    @reader = @borrowing.reader
  end

  # Final guard for any caller: no email once the book is returned or the reader has no address.
  def deliverable?
    @borrowing.remindable?
  end
end
