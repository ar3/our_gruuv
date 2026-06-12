class BackfillGsdDigestEnabledFromDigestSlack < ActiveRecord::Migration[8.0]
  # The GSD digest used to send to anyone with the Slack medium on; it now has its own
  # opt-in toggle. Turn it on for everyone who effectively had it on before this change.
  def up
    execute <<~SQL.squish
      UPDATE user_preferences
      SET preferences = preferences || '{"gsd_digest_enabled": "on"}'::jsonb
      WHERE preferences->>'digest_slack' IN ('on', 'daily', 'weekly')
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE user_preferences
      SET preferences = preferences - 'gsd_digest_enabled'
    SQL
  end
end
