class Borrowing < ApplicationRecord
  DUE_AFTER = 30.days

  class Error < StandardError; end

  class AlreadyBorrowed < Error
    def initialize(message = "Book is already borrowed")
      super
    end
  end

  class NotBorrowed < Error
    def initialize(message = "Book is not borrowed")
      super
    end
  end

  belongs_to :book
  belongs_to :reader

  validates :borrowed_at, :due_on, presence: true

  scope :active, -> { where(returned_at: nil) }
  scope :chronological, -> { order(borrowed_at: :desc) }

  def self.borrow!(book:, reader:, at: Time.current)
    transaction do
      book = Book.kept.lock.find(book.id)
      reader = Reader.kept.find(reader.id)
      raise AlreadyBorrowed if book.borrowed?

      create!(book:, reader:, borrowed_at: at, due_on: at.in_time_zone.to_date + DUE_AFTER)
    end
  rescue ActiveRecord::RecordNotUnique
    raise AlreadyBorrowed
  end

  def self.return!(book:, reader:, at: Time.current)
    transaction do
      book = Book.lock.find(book.id)
      borrowing = book.current_borrowing or raise NotBorrowed
      raise NotBorrowed, "Book borrowed by another reader" unless borrowing.reader_id == reader.id

      borrowing.update!(returned_at: at)
      borrowing
    end
  end

  def active?
    returned_at.nil?
  end
end
