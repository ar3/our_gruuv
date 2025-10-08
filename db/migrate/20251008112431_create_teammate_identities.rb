class CreateTeammateIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :teammate_identities do |t|
      t.references :teammate, null: false, foreign_key: true, index: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email
      t.string :name
      t.string :profile_image_url
      t.jsonb :raw_data, default: {}

      t.timestamps
      
      # Composite index for efficient lookups
      t.index [:teammate_id, :provider], name: 'index_teammate_identities_on_teammate_and_provider'
      # Unique constraint to prevent duplicate identities
      t.index [:provider, :uid], name: 'index_teammate_identities_on_provider_and_uid', unique: true
    end
  end
end
