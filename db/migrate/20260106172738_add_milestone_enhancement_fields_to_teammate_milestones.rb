class AddMilestoneEnhancementFieldsToTeammateMilestones < ActiveRecord::Migration[8.0]
  def change
    add_column :teammate_milestones, :certification_note, :text
    add_column :teammate_milestones, :published_at, :datetime
    add_column :teammate_milestones, :published_by_teammate_id, :bigint
    add_column :teammate_milestones, :public_profile_published_at, :datetime
    
    add_index :teammate_milestones, :published_at, name: 'index_teammate_milestones_on_published_at'
    add_index :teammate_milestones, :public_profile_published_at, name: 'index_teammate_milestones_on_public_profile_published_at'
    add_index :teammate_milestones, :published_by_teammate_id, name: 'index_teammate_milestones_on_published_by_teammate_id'
    
    add_foreign_key :teammate_milestones, :teammates, column: :published_by_teammate_id
  end
end
