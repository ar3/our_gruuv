class AddIdentityFieldsToPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :preferred_name, :string
    add_column :people, :gender_identity, :string
    add_column :people, :pronouns, :string
  end
end
