class CreateTeamMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :team_members do |t|
      t.references :team, null: false, foreign_key: true
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.bigint :migrate_from_teammate_id

      t.timestamps
    end

    add_index :team_members, [:team_id, :company_teammate_id], unique: true
    add_index :team_members, :migrate_from_teammate_id, unique: true
  end
end
