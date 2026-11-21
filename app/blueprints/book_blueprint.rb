class BookBlueprint < Blueprinter::Base
  identifier :serial_number

  fields :title, :author, :status

  association :current_borrowing, blueprint: BorrowingBlueprint

  view :detailed do
    association :borrowings_chronological, name: :borrowings, blueprint: BorrowingBlueprint
  end
end
