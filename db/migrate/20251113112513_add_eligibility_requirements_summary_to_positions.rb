class AddEligibilityRequirementsSummaryToPositions < ActiveRecord::Migration[8.0]
  def change
    add_column :positions, :eligibility_requirements_summary, :text
  end
end
