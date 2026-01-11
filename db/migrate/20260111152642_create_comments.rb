class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.references :commentable, polymorphic: true, null: false
      t.references :organization, null: false, foreign_key: true
      t.text :body, null: false
      t.references :creator, null: false, foreign_key: { to_table: :people }
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :comments, [:commentable_type, :commentable_id], if_not_exists: true
    add_index :comments, :organization_id, if_not_exists: true
    add_index :comments, :resolved_at, if_not_exists: true
    add_index :comments, :creator_id, if_not_exists: true
  end
end
