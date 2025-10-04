class CreateAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :addresses do |t|
      t.references :person, null: false, foreign_key: true
      t.string :address_type, null: false, default: 'home'
      t.string :street_address
      t.string :city
      t.string :state_province
      t.string :postal_code
      t.string :country
      t.boolean :is_primary, default: false

      t.timestamps
    end
  end
end
