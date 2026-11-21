class Borrowing < ApplicationRecord
  DUE_AFTER = 30.days
  # How long before the due date the due-soon reminder is sent
  REMIND_BEFORE = 3.days
  # How far back a missed due-today reminder is still sent, so old overdue loans aren't emailed
  REMINDER_CATCH_UP = 7.days

  belongs_to :book
  belongs_to :reader

  enum :status, active: 0, returned: 1

  validates :borrowed_at, :due_on, presence: true

  scope :chronological, -> { order(borrowed_at: :desc) }
  scope :with_reader_email, -> { joins(:reader).where.not(readers: { email: nil }) }

  # Active borrowings that should get `reminder` (a Borrowing::Reminder) on `today` and haven't yet.
  scope :reminder_pending, lambda { |reminder, today|
    active.with_reader_email.where(reminder.sent_at_column => nil, due_on: reminder.due_on_range(today))
  }

  def self.borrow!(book:, reader:, at: Time.current)
    transaction do
      book = Book.kept.lock.find(book.id)
      reader = Reader.kept.find(reader.id)
      raise Errors::AlreadyBorrowed if book.borrowed?

      # All times in the code should be in the library TZ (as set in config.time_zone)
      # in_time_zone is just to protect against someone passing time in a wrong zone manually
      borrowing = create!(book:, reader:, borrowed_at: at, due_on: at.in_time_zone.to_date + DUE_AFTER)
      book.borrowed!
      borrowing
    end
  rescue ActiveRecord::RecordNotUnique
    raise Errors::AlreadyBorrowed
  end

  def self.return!(book:, at: Time.current)
    transaction do
      book = Book.lock.find(book.id)
      borrowing = book.current_borrowing or raise Errors::NotBorrowed

      borrowing.update!(returned_at: at, status: "returned")
      book.available!
      borrowing
    end
  end

  # A reminder only makes sense while the book is out and the reader can be emailed.
  def remindable?
    active? && reader.email.present?
  end

  def claim_reminder(reminder)
    # Locks the row first: the UPDATE below joins readers, and with a join PostgreSQL
    # re-checks a concurrent claim only against the updated row, not the joined copy,
    # so without the lock both claims could succeed (inconsistent snapshot, see
    # https://www.postgresql.org/docs/current/transaction-iso.html#XACT-READ-COMMITTED).
    self.transaction do
      Borrowing.lock("FOR UPDATE").find_by(id:)
      self.class.active.with_reader_email.where(id:, reminder.sent_at_column => nil)
          .update_all(reminder.sent_at_column => Time.current) == 1
    end
  end

  def release_reminder(reminder)
    self.class.where(id:).update_all(reminder.sent_at_column => nil)
  end
end
