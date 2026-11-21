class ReaderBlueprint < Blueprinter::Base
  identifier :card_number

  fields :name, :email

  field :discarded?, name: :archived
end
