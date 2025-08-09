class AddAdditionalFieldsToPersonIdentities < ActiveRecord::Migration[8.0]
  def change
    add_column :person_identities, :name, :string
    add_column :person_identities, :profile_image_url, :string
    add_column :person_identities, :raw_data, :jsonb
  end
end
