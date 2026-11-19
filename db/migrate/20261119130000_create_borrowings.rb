class CreateBorrowings < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowings do |t|
      t.references :book, null: false, foreign_key: true, index: false
      t.references :reader, null: false, foreign_key: true, index: false
      t.datetime :borrowed_at, null: false
      t.date :due_on, null: false
      t.datetime :returned_at
      t.datetime :due_soon_reminder_scheduled_at
      t.datetime :due_today_reminder_scheduled_at

      t.timestamps
    end

    add_index :borrowings, :book_id, unique: true, where: "returned_at IS NULL", name: "index_borrowings_on_book_id_active"
    add_index :borrowings, [ :book_id, :borrowed_at ]
    add_index :borrowings, [ :reader_id, :returned_at ]
    add_index :borrowings, :due_on
  end
end
