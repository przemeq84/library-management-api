class MakeUniqueIndexesNonPartial < ActiveRecord::Migration[8.1]
  def change
    add_index :books, :serial_number, unique: true, name: "index_books_on_serial_number_uniq"
    add_index :readers, :card_number, unique: true, name: "index_readers_on_card_number_uniq"

    remove_index :books, :serial_number, unique: true, where: "discarded_at IS NULL", name: "index_books_on_serial_number"
    remove_index :readers, :card_number, unique: true, where: "discarded_at IS NULL", name: "index_readers_on_card_number"
  end
end
