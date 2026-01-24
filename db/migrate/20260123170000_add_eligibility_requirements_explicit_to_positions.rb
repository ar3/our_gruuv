class AddEligibilityRequirementsExplicitToPositions < ActiveRecord::Migration[8.0]
  def change
    add_column :positions, :eligibility_requirements_explicit, :jsonb, default: {}, null: false
    add_index :positions, :eligibility_requirements_explicit, using: :gin
  end
end
