class BookBlueprint < Blueprinter::Base
  identifier :id

  fields :serial_number, :title, :author, :status

  association :current_borrowing, blueprint: BorrowingBlueprint

  view :detailed do
    association :borrowings, blueprint: BorrowingBlueprint do |book, _options|
      book.borrowings.sort_by(&:borrowed_at).reverse
    end
  end
end
