class CreatePeople < ActiveRecord::Migration[8.0]
  def change
    create_table :people do |t|
      t.string :first_name
      t.string :middle_name
      t.string :last_name
      t.string :suffix
      t.string :unique_textable_phone_number

      t.timestamps
    end
    add_index :people, :unique_textable_phone_number, unique: true
  end
end
