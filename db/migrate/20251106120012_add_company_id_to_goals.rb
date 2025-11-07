class AddCompanyIdToGoals < ActiveRecord::Migration[8.0]
  def up
    # Add company_id column (nullable initially for data migration)
    add_reference :goals, :company, null: true, foreign_key: { to_table: :organizations }
    add_index :goals, :company_id, if_not_exists: true
    
    # Migrate existing Person owners to Teammate owners
    # For each goal with Person owner, find the first teammate for that person
    Goal.reset_column_information
    Goal.where(owner_type: 'Person').find_each do |goal|
      person = Person.find_by(id: goal.owner_id)
      next unless person
      
      first_teammate = person.teammates.order(:id).first
      if first_teammate
        goal.update_columns(owner_type: 'Teammate', owner_id: first_teammate.id)
      end
    end
    
    # Set company_id for all goals based on creator.organization.root_company
    Goal.where(company_id: nil).find_each do |goal|
      creator = Teammate.find_by(id: goal.creator_id)
      next unless creator
      
      company = creator.organization.root_company || creator.organization
      next unless company&.company?
      
      goal.update_column(:company_id, company.id)
    end
    
    # Make company_id NOT NULL now that all records have values
    change_column_null :goals, :company_id, false
  end
  
  def down
    remove_index :goals, :company_id
    remove_reference :goals, :company, foreign_key: { to_table: :organizations }
    
    # Note: We don't reverse the Person -> Teammate migration
    # as we can't reliably determine which Person a Teammate should map back to
  end
end
