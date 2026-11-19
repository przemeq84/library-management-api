class Book < ApplicationRecord
  include Discard::Model

  has_many :borrowings
  has_one :current_borrowing, -> { active }, class_name: "Borrowing"

  validates :title, :author, presence: true
  validates :serial_number, presence: true,
                            format: { with: /\A\d{6}\z/, message: "must be a six-digit number", allow_blank: true },
                            uniqueness: { conditions: -> { kept } }

  before_discard :ensure_not_borrowed

  def borrowed?
    current_borrowing.present?
  end

  def status
    borrowed? ? "borrowed" : "available"
  end

  private

  def ensure_not_borrowed
    return unless borrowings.active.exists?

    errors.add(:base, "Book is currently borrowed")
    throw :abort
  end
end
