class Reader < ApplicationRecord
  include Discard::Model

  has_many :borrowings

  normalizes :email, with: ->(email) { email.strip.downcase.presence }

  validates :name, presence: true
  validates :card_number, presence: true,
                          format: { with: /\A\d{6}\z/, message: "must be a six-digit number", allow_blank: true },
                          uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { conditions: -> { kept } },
                    allow_nil: true

  before_discard :ensure_no_active_borrowings

  def to_param
    card_number
  end

  private

  def ensure_no_active_borrowings
    raise Borrowing::Errors::ReaderHasActiveBorrowings if borrowings.active.exists?
  end
end
