# frozen_string_literal: true

class ConvertGoalOwnerTypeToExplicitTypes < ActiveRecord::Migration[7.2]
  def up
    # Convert owner_type from 'Organization' to explicit types (Company, Department, Team)
    # This is a data migration to support the explicit owner_type refactor
    Goal.where(owner_type: 'Organization').find_each do |goal|
      if goal.owner.present? && goal.owner.respond_to?(:type)
        goal.update_column(:owner_type, goal.owner.type)
      end
    end
  end

  def down
    # Convert back to 'Organization' for Company, Department, Team owners
    Goal.where(owner_type: ['Company', 'Department', 'Team']).update_all(owner_type: 'Organization')
  end
end
