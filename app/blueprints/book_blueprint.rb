class BookBlueprint < Blueprinter::Base
  identifier :serial_number

  fields :title, :author, :status

  field :discarded?, name: :archived

  view :detailed do
    association :recent_borrowings_chronological, name: :recent_borrowings, blueprint: BorrowingBlueprint

    field(:borrowings_count) { |_book, options| options[:borrowings_count] }
  end
end
