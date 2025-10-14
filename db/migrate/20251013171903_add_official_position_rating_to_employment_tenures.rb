class AddOfficialPositionRatingToEmploymentTenures < ActiveRecord::Migration[8.0]
  def change
    add_column :employment_tenures, :official_position_rating, :integer
    
    add_check_constraint :employment_tenures,
      'official_position_rating IS NULL OR (official_position_rating >= -3 AND official_position_rating <= 3)',
      name: 'valid_position_rating_range'
  end
end
