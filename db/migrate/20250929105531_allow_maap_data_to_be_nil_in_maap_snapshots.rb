class AllowMaapDataToBeNilInMaapSnapshots < ActiveRecord::Migration[8.0]
  def change
    change_column_null :maap_snapshots, :maap_data, true
  end
end
