class AddOfficialRatingToAssignmentTenures < ActiveRecord::Migration[8.0]
  def change
    add_column :assignment_tenures, :official_rating, :string
  end
end
