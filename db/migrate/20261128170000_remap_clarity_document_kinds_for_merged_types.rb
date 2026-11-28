# frozen_string_literal: true

class RemapClarityDocumentKindsForMergedTypes < ActiveRecord::Migration[8.0]
  def up
    say_with_time "Merge FAQ/Reference and Policy/Process document kinds" do
      execute <<~SQL.squish
        UPDATE documents SET kind = 'faq_reference' WHERE kind IN ('faq', 'reference');
        UPDATE documents SET kind = 'policy_process' WHERE kind IN ('policy', 'process');
      SQL
    end
  end

  def down
    say_with_time "Split merged document kinds back to prior values" do
      execute <<~SQL.squish
        UPDATE documents SET kind = 'reference' WHERE kind = 'faq_reference';
        UPDATE documents SET kind = 'policy' WHERE kind = 'policy_process';
      SQL
    end
  end
end
