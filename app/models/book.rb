class Book < ApplicationRecord
  include Discard::Model

  has_many :borrowings
  has_many :recent_borrowings_chronological, -> { chronological.limit(3) }, class_name: "Borrowing"
  has_one :current_borrowing, -> { active }, class_name: "Borrowing"

  validates :title, :author, presence: true
  validates :serial_number, presence: true,
                            format: { with: /\A\d{6}\z/, message: "must be a six-digit number", allow_blank: true },
                            uniqueness: true

  before_discard :ensure_not_borrowed

  def to_param
    serial_number
  end

  def borrowed?
    current_borrowing.present?
  end

  def status
    borrowed? ? "borrowed" : "available"
  end

  private

  def ensure_not_borrowed
    raise Borrowing::Errors::BookStillBorrowed if borrowings.active.exists?
  end
end
