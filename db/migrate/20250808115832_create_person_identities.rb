class CreatePersonIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :person_identities do |t|
      t.references :person, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email, null: false

      t.timestamps
    end
    
    # Add indexes for efficient lookups
    add_index :person_identities, [:provider, :uid], unique: true
    add_index :person_identities, :email
    add_index :person_identities, [:person_id, :provider]
  end
end
