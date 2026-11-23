class AddStatusToBooksAndBorrowings < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :status, :integer, null: false, default: 0
    add_column :borrowings, :status, :integer, null: false, default: 0
  end
end
