class AddCompanyAndTeamToHuddlePlaybooks < ActiveRecord::Migration[8.0]
  def change
    add_reference :huddle_playbooks, :company, null: true, foreign_key: { to_table: :organizations }
    add_reference :huddle_playbooks, :team, null: true, foreign_key: true
  end
end
