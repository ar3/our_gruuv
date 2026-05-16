class ChangeCompanyLabelPreferencesLabelValueToText < ActiveRecord::Migration[8.0]
  def up
    change_column :company_label_preferences, :label_value, :text
  end

  def down
    change_column :company_label_preferences, :label_value, :string
  end
end
