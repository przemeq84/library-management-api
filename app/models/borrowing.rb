class Borrowing < ApplicationRecord
  DUE_AFTER = 30.days
  REMIND_BEFORE = 3.days
  # How far back a missed due-today reminder is still sent, so old overdue loans aren't emailed.
  REMINDER_CATCH_UP = 7.days

  belongs_to :book
  belongs_to :reader

  validates :borrowed_at, :due_on, presence: true

  scope :active, -> { where(returned_at: nil) }
  scope :chronological, -> { order(borrowed_at: :desc) }
  scope :with_reader_email, -> { joins(:reader).where.not(readers: { email: nil }) }

  # Active borrowings due within REMIND_BEFORE (but not today) whose reminder wasn't sent yet.
  # Using a window rather than an exact day lets a missed run catch up the next day.
  scope :due_soon_reminder_pending, lambda { |today|
    active.with_reader_email.where(due_soon_reminder_sent_at: nil, due_on: (today + 1)..(today + REMIND_BEFORE))
  }

  # Active borrowings due today, or overdue by up to REMINDER_CATCH_UP, whose due-today reminder wasn't sent yet.
  scope :due_today_reminder_pending, lambda { |today|
    active.with_reader_email.where(due_today_reminder_sent_at: nil, due_on: (today - REMINDER_CATCH_UP)..today)
  }

  def self.borrow!(book:, reader:, at: Time.current)
    transaction do
      book = Book.kept.lock.find(book.id)
      reader = Reader.kept.find(reader.id)
      raise Errors::AlreadyBorrowed if book.borrowed?

      create!(book:, reader:, borrowed_at: at, due_on: at.in_time_zone.to_date + DUE_AFTER)
    end
  rescue ActiveRecord::RecordNotUnique
    raise Errors::AlreadyBorrowed
  end

  def self.return!(book:, reader:, at: Time.current)
    transaction do
      book = Book.lock.find(book.id)
      borrowing = book.current_borrowing or raise Errors::NotBorrowed
      raise Errors::NotBorrowed, "Book borrowed by another reader" unless borrowing.reader_id == reader.id

      borrowing.update!(returned_at: at)
      borrowing
    end
  end

  def active?
    returned_at.nil?
  end

  # A reminder only makes sense while the book is out and the reader can be emailed.
  def remindable?
    active? && reader.email.present?
  end
end
