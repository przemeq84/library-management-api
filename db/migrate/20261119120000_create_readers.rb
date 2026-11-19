class CreateReaders < ActiveRecord::Migration[8.1]
  def change
    create_table :readers do |t|
      t.string :card_number, null: false
      t.string :name, null: false
      t.string :email
      t.datetime :discarded_at

      t.timestamps
    end

    # Uniqueness applies to kept (not soft-deleted) readers only.
    add_index :readers, :card_number, unique: true, where: "discarded_at IS NULL"
    add_index :readers, :email, unique: true, where: "discarded_at IS NULL AND email IS NOT NULL"
  end
end
