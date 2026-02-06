# Creates the rewards catalog for highlights point redemption
class CreateHighlightsRewards < ActiveRecord::Migration[8.0]
  def change
    create_table :highlights_rewards do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.decimal :cost_in_points, precision: 10, scale: 1, null: false
      t.string :reward_type, null: false, default: 'gift_card'
      t.boolean :active, null: false, default: true
      t.string :image_url
      t.jsonb :metadata, default: {}
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :highlights_rewards, [:organization_id, :active]
    add_index :highlights_rewards, :reward_type
    add_index :highlights_rewards, :deleted_at
  end
end
