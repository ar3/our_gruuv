FactoryBot.define do
  factory :observation_trigger do
    trigger_source { 'slack' }
    trigger_type { 'slack_command' }
    trigger_data do
      {
        command: '/og',
        text: 'feedback Great work!',
        user_id: 'U123456',
        channel_id: 'C123456',
        team_id: 'T123456',
        team_domain: 'test-workspace',
        channel_name: 'general',
        user_name: 'testuser',
        response_url: 'https://hooks.slack.com/commands/123/456',
        trigger_id: '123.456.789'
      }
    end
  end
end

