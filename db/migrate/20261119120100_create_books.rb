class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :serial_number, null: false
      t.string :title, null: false
      t.string :author, null: false
      t.datetime :discarded_at

      t.timestamps
    end

    # Uniqueness applies to kept (not soft-deleted) books only.
    add_index :books, :serial_number, unique: true, where: "discarded_at IS NULL"
  end
end
