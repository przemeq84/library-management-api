class Reader < ApplicationRecord
  include Discard::Model

  has_many :borrowings

  normalizes :email, with: ->(email) { email.strip.downcase.presence }

  validates :name, presence: true
  validates :card_number, presence: true,
                          format: { with: /\A\d{6}\z/, message: "must be a six-digit number", allow_blank: true },
                          uniqueness: { conditions: -> { kept } }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { conditions: -> { kept } },
                    allow_nil: true

  before_discard :ensure_no_active_borrowings

  private

  def ensure_no_active_borrowings
    return unless borrowings.active.exists?

    errors.add(:base, "Reader has borrowed books that are not returned")
    throw :abort
  end
end
