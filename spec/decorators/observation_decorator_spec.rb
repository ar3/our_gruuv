require 'rails_helper'

RSpec.describe ObservationDecorator, type: :decorator do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:teammate1) { create(:teammate, organization: company) }
  let(:observation) do
    build(:observation,
          observer: observer,
          company: company,
          story: 'Great work on the project!',
          primary_feeling: 'happy',
          secondary_feeling: 'proud',
          privacy_level: :observed_only)
  end
  let(:decorated_observation) { observation.decorate }

  before do
    observation.observees.build(teammate: teammate1)
    observation.save!
  end

  describe '#permalink_url' do
    it 'returns correct URL' do
      expected_url = Rails.application.routes.url_helpers.kudos_url(date: observation.observed_at.strftime('%Y-%m-%d'), id: observation.id)
      expect(decorated_observation.permalink_url).to eq(expected_url)
    end
  end

  describe '#permalink_path' do
    it 'returns correct path' do
      expected_path = Rails.application.routes.url_helpers.kudos_path(date: observation.observed_at.strftime('%Y-%m-%d'), id: observation.id)
      expect(decorated_observation.permalink_path).to eq(expected_path)
    end
  end

  describe '#visibility_text' do
    it 'returns correct text for each privacy level' do
      observation.privacy_level = 'observer_only'
      expect(decorated_observation.visibility_text).to eq('Private Journal Entry')
      
      observation.privacy_level = 'observed_only'
      expect(decorated_observation.visibility_text).to eq('1-on-1 Feedback')
      
      observation.privacy_level = 'managers_only'
      expect(decorated_observation.visibility_text).to eq('Manager Review')
      
      observation.privacy_level = 'observed_and_managers'
      expect(decorated_observation.visibility_text).to eq('Team Feedback')
      
      observation.privacy_level = 'public_observation'
      expect(decorated_observation.visibility_text).to eq('Public Recognition')
    end
  end

  describe '#visibility_icon' do
    it 'returns correct icon for each privacy level' do
      observation.privacy_level = 'observer_only'
      expect(decorated_observation.visibility_icon).to eq('🔒')
      
      observation.privacy_level = 'observed_only'
      expect(decorated_observation.visibility_icon).to eq('👤')
      
      observation.privacy_level = 'managers_only'
      expect(decorated_observation.visibility_icon).to eq('👔')
      
      observation.privacy_level = 'observed_and_managers'
      expect(decorated_observation.visibility_icon).to eq('👥')
      
      observation.privacy_level = 'public_observation'
      expect(decorated_observation.visibility_icon).to eq('🌍')
    end
  end

  describe '#visibility_text_style' do
    it 'returns correct style for each privacy level' do
      observation.privacy_level = 'observer_only'
      expect(decorated_observation.visibility_text_style).to eq('Journal')
      
      observation.privacy_level = 'observed_only'
      expect(decorated_observation.visibility_text_style).to eq('1-on-1')
      
      observation.privacy_level = 'managers_only'
      expect(decorated_observation.visibility_text_style).to eq('Managers')
      
      observation.privacy_level = 'observed_and_managers'
      expect(decorated_observation.visibility_text_style).to eq('Team')
      
      observation.privacy_level = 'public_observation'
      expect(decorated_observation.visibility_text_style).to eq('Public')
    end
  end

  describe '#feelings_display_html' do
    it 'displays primary feeling only' do
      observation.primary_feeling = 'happy'
      observation.secondary_feeling = nil
      expect(decorated_observation.feelings_display_html).to eq('😀 (Happy)')
    end

    it 'displays both primary and secondary feelings' do
      observation.primary_feeling = 'happy'
      observation.secondary_feeling = 'proud'
      expect(decorated_observation.feelings_display_html).to eq('😀 (Happy) 😎 (Proud)')
    end

    it 'returns empty string when primary feeling is nil' do
      observation.primary_feeling = nil
      expect(decorated_observation.feelings_display_html).to eq('')
    end
  end

  describe '#story_html' do
    it 'converts markdown to HTML' do
      observation.story = '**Bold text** and *italic text*'
      expect(decorated_observation.story_html).to eq('<strong>Bold text</strong> and <em>italic text</em>')
    end

    it 'converts newlines to br tags' do
      observation.story = "Line 1\nLine 2"
      expect(decorated_observation.story_html).to eq('Line 1<br>Line 2')
    end
  end

  describe '#timeframe' do
    it 'returns :this_day for today' do
      observation.observed_at = Time.current
      expect(decorated_observation.timeframe).to eq(:this_day)
    end

    it 'returns :this_week for this week' do
      observation.observed_at = 3.days.ago
      expect(decorated_observation.timeframe).to eq(:this_week)
    end

    it 'returns :past_three_weeks for past three weeks' do
      observation.observed_at = 2.weeks.ago
      expect(decorated_observation.timeframe).to eq(:past_three_weeks)
    end

    it 'returns :past_three_months for past three months' do
      observation.observed_at = 2.months.ago
      expect(decorated_observation.timeframe).to eq(:past_three_months)
    end

    it 'returns :older for older observations' do
      observation.observed_at = 6.months.ago
      expect(decorated_observation.timeframe).to eq(:older)
    end
  end

  describe '#channel_posts_summary' do
    it 'returns empty string when no channel posts' do
      expect(decorated_observation.channel_posts_summary).to eq('')
    end

    it 'returns correct summary for single channel post' do
      # Create a successful channel notification
      observation.notifications.create!(
        notification_type: 'observation_channel',
        status: 'sent_successfully',
        message_id: '1234567890.123456',
        rich_message: 'Test message',
        fallback_text: 'Test message',
        metadata: { channel: 'C123456' }
      )
      
      expect(decorated_observation.channel_posts_summary).to eq('Posted to 1 channel')
    end
  end

  describe '#status_markup' do
    it 'includes privacy level and posting status' do
      expect(decorated_observation.status_markup).to include('👤')
      expect(decorated_observation.status_markup).to include('1-on-1')
      expect(decorated_observation.status_markup).to include('📝 Draft')
    end
  end
end
