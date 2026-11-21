class BorrowingBlueprint < Blueprinter::Base
  identifier :id

  fields :status, :borrowed_at, :due_on, :returned_at

  association :reader, blueprint: ReaderBlueprint
end
