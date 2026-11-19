class ReaderBlueprint < Blueprinter::Base
  identifier :id

  fields :card_number, :name, :email
end
