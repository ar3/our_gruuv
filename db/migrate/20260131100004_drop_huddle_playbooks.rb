class DropHuddlePlaybooks < ActiveRecord::Migration[8.0]
  def up
    drop_table :huddle_playbooks
  end

  def down
    create_table :huddle_playbooks do |t|
      t.string :special_session_name
      t.string :slack_channel
      t.timestamps
      t.bigint :company_id, null: false
      t.bigint :team_id

      t.index [:company_id, :team_id, :special_session_name],
              name: 'index_huddle_playbooks_on_company_team_and_session_name',
              unique: true
      t.index [:company_id], name: 'index_huddle_playbooks_on_company_id'
      t.index [:team_id], name: 'index_huddle_playbooks_on_team_id'
    end

    add_foreign_key :huddle_playbooks, :organizations, column: :company_id
    add_foreign_key :huddle_playbooks, :teams
  end
end
