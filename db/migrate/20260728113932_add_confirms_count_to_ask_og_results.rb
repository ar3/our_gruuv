# frozen_string_literal: true

class AddConfirmsCountToAskOgResults < ActiveRecord::Migration[8.0]
  def change
    add_column :ask_og_results, :confirms_count, :integer, null: false, default: 0
  end
end
