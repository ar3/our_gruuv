require 'rails_helper'

RSpec.describe Huddles::StatsService, type: :service do
  let(:company) { create(:organization, :company, name: 'Test Company') }
  let(:team) { create(:organization, :team, name: 'Test Team', parent: company) }
  let(:playbook) { create(:huddle_playbook, organization: team) }
  let(:service) { described_class.new(company) }

  describe 'initialization' do
    it 'can be instantiated without syntax errors' do
      expect { described_class.new(company) }.not_to raise_error
    end

    it 'sets the organization and date range' do
      expect(service.instance_variable_get(:@organization)).to eq(company)
      expect(service.instance_variable_get(:@date_range)).to be_present
    end

    it 'defaults to 6 weeks when no date range provided' do
      service = described_class.new(company)
      date_range = service.instance_variable_get(:@date_range)
      expect(date_range.begin).to be_within(1.day).of(6.weeks.ago.to_date)
      expect(date_range.end).to eq(Date.current)
    end

    it 'accepts custom date range' do
      custom_range = 2.weeks.ago..1.week.ago
      service = described_class.new(company, custom_range)
      expect(service.instance_variable_get(:@date_range)).to eq(custom_range)
    end
  end

  describe '#huddles_in_range' do
    let!(:huddle1) { create(:huddle, huddle_playbook: playbook, started_at: 1.day.ago) }
    let!(:huddle2) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: team), started_at: 2.days.ago) }
    let!(:old_huddle) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: team), started_at: 7.weeks.ago) }

    it 'returns huddles within the date range' do
      result = service.huddles_in_range
      expect(result).to include(huddle1, huddle2)
      expect(result).not_to include(old_huddle)
    end

    it 'includes necessary associations' do
      result = service.huddles_in_range
      expect(result.first.association(:huddle_playbook).loaded?).to be true
      expect(result.first.huddle_playbook.association(:organization).loaded?).to be true
    end

    it 'orders by started_at desc' do
      result = service.huddles_in_range
      expect(result.first).to eq(huddle1)
      expect(result.second).to eq(huddle2)
    end

    it 'memoizes the result' do
      expect(service.huddles_in_range.object_id).to eq(service.huddles_in_range.object_id)
    end
  end

  describe '#calculate_feedback_stats' do
    let!(:huddle) { create(:huddle, huddle_playbook: playbook, started_at: 1.day.ago) }
    let!(:person1) { create(:person) }
    let!(:person2) { create(:person) }
    let!(:teammate1) { create(:teammate, person: person1, organization: company) }
    let!(:teammate2) { create(:teammate, person: person2, organization: company) }
    let!(:feedback1) { create(:huddle_feedback, huddle: huddle, teammate: teammate1, created_at: 1.day.ago) }
    let!(:feedback2) { create(:huddle_feedback, huddle: huddle, teammate: teammate2, created_at: 1.day.ago) }

    it 'returns correct feedback count' do
      stats = service.calculate_feedback_stats
      expect(stats[:feedback_count]).to eq(2)
    end

    it 'returns correct unique participant count' do
      stats = service.calculate_feedback_stats
      expect(stats[:unique_participants]).to eq(2)
    end

    it 'includes date range in stats' do
      stats = service.calculate_feedback_stats
      expect(stats[:start_date]).to be_present
      expect(stats[:end_date]).to be_present
    end

    it 'memoizes the result' do
      expect(service.feedback_stats.object_id).to eq(service.feedback_stats.object_id)
    end
  end

  describe '#calculate_participation_stats' do
    let!(:huddle) { create(:huddle, huddle_playbook: playbook, started_at: 1.day.ago) }
    let!(:person1) { create(:person) }
    let!(:person2) { create(:person) }
    let!(:teammate1) { create(:teammate, person: person1, organization: company) }
    let!(:teammate2) { create(:teammate, person: person2, organization: company) }
    let!(:participant1) { create(:huddle_participant, huddle: huddle, teammate: teammate1) }
    let!(:participant2) { create(:huddle_participant, huddle: huddle, teammate: teammate2) }
    let!(:feedback1) { create(:huddle_feedback, huddle: huddle, teammate: teammate1) }

    it 'calculates total participants correctly' do
      stats = service.calculate_participation_stats
      expect(stats[:total_participants]).to eq(2)
    end

    it 'calculates total feedbacks correctly' do
      stats = service.calculate_participation_stats
      expect(stats[:total_feedbacks]).to eq(1)
    end

    it 'calculates participation rate correctly' do
      stats = service.calculate_participation_stats
      expect(stats[:participation_rate]).to eq(50.0)
    end

    it 'includes distinct participant information' do
      stats = service.calculate_participation_stats
      expect(stats[:distinct_participant_count]).to eq(2)
      expect(stats[:distinct_participant_names]).to be_an(Array)
    end

    it 'memoizes the result' do
      expect(service.participation_stats.object_id).to eq(service.participation_stats.object_id)
    end
  end

  describe '#calculate_rating_stats' do
    let!(:huddle) { create(:huddle, huddle_playbook: playbook, started_at: 1.day.ago) }
    let!(:person1) { create(:person) }
    let!(:person2) { create(:person) }
    let!(:teammate1) { create(:teammate, person: person1, organization: company) }
    let!(:teammate2) { create(:teammate, person: person2, organization: company) }
    let!(:feedback1) { create(:huddle_feedback, huddle: huddle, teammate: teammate1, informed_rating: 4, connected_rating: 5, goals_rating: 3, valuable_rating: 4) }
    let!(:feedback2) { create(:huddle_feedback, huddle: huddle, teammate: teammate2, informed_rating: 5, connected_rating: 5, goals_rating: 5, valuable_rating: 5) }

    it 'calculates average rating correctly' do
      stats = service.calculate_rating_stats
      # feedback1: 4+5+3+4 = 16, feedback2: 5+5+5+5 = 20, total = 36, count = 2, average = 18
      expect(stats[:average_rating]).to eq(18.0)
    end

    it 'includes rating distribution' do
      stats = service.calculate_rating_stats
      expect(stats[:rating_distribution]).to be_a(Hash)
    end

    it 'includes conflict style distributions' do
      stats = service.calculate_rating_stats
      expect(stats[:personal_conflict_styles]).to be_a(Hash)
      expect(stats[:team_conflict_styles]).to be_a(Hash)
    end

    it 'memoizes the result' do
      expect(service.rating_stats.object_id).to eq(service.rating_stats.object_id)
    end
  end

  describe '#calculate_weekly_stats' do
    let!(:huddle1) { create(:huddle, huddle_playbook: playbook, started_at: 1.day.ago) }
    let!(:huddle2) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: team), started_at: 2.days.ago) }

    it 'groups huddles by week' do
      stats = service.calculate_weekly_stats
      expect(stats).to be_a(Hash)
      expect(stats.keys.first).to be_a(Time)
    end

    it 'includes weekly participation and rating stats' do
      stats = service.calculate_weekly_stats
      week_stats = stats.values.first
      expect(week_stats).to include(:total_huddles, :participation_rate, :average_rating)
    end

    it 'memoizes the result' do
      expect(service.weekly_stats.object_id).to eq(service.weekly_stats.object_id)
    end
  end

  describe '#calculate_overall_stats' do
    it 'combines participation and rating stats' do
      stats = service.calculate_overall_stats
      expect(stats).to include(:total_huddles, :total_participants, :total_feedbacks, :average_rating)
    end

    it 'memoizes the result' do
      expect(service.overall_stats.object_id).to eq(service.overall_stats.object_id)
    end
  end

  describe '#calculate_playbook_stats' do
    let!(:huddle) { create(:huddle, huddle_playbook: playbook, started_at: 1.day.ago) }

    it 'groups stats by playbook' do
      stats = service.calculate_playbook_stats
      expect(stats).to be_a(Hash)
      expect(stats.keys.first).to eq(playbook.id)
    end

    it 'includes playbook metadata' do
      stats = service.calculate_playbook_stats
      playbook_stats = stats.values.first
      expect(playbook_stats).to include(:id, :display_name, :organization_id, :organization_name)
    end

    it 'includes playbook-specific stats' do
      stats = service.calculate_playbook_stats
      playbook_stats = stats.values.first
      expect(playbook_stats).to include(:total_huddles, :participation_rate, :average_rating)
    end

    it 'memoizes the result' do
      expect(service.playbook_stats.object_id).to eq(service.playbook_stats.object_id)
    end
  end

  describe 'edge cases' do
    it 'handles organization with no huddles' do
      empty_company = create(:organization, :company, name: 'Empty Company')
      service = described_class.new(empty_company)
      
      expect { service.huddles_in_range }.not_to raise_error
      expect(service.huddles_in_range).to be_empty
      expect(service.calculate_feedback_stats[:feedback_count]).to eq(0)
      expect(service.calculate_participation_stats[:total_participants]).to eq(0)
    end

    it 'handles huddles without playbooks gracefully' do
      huddle_without_playbook = create(:huddle, huddle_playbook: nil, started_at: 1.day.ago)
      
      expect { service.huddles_in_range }.not_to raise_error
      # Should not include huddles without playbooks due to the join
      expect(service.huddles_in_range).not_to include(huddle_without_playbook)
    end

    it 'handles date ranges with no huddles' do
      future_range = 1.week.from_now..2.weeks.from_now
      service = described_class.new(company, future_range)
      
      expect { service.huddles_in_range }.not_to raise_error
      expect(service.huddles_in_range).to be_empty
    end
  end

  describe 'performance' do
    it 'uses includes to avoid N+1 queries' do
      # Create different playbooks for each huddle to avoid validation errors
      3.times do |i|
        create(:huddle, huddle_playbook: create(:huddle_playbook, organization: team), started_at: 1.day.ago)
      end
      
      # Test that the includes are working by accessing associations without N+1 queries
      huddles = service.huddles_in_range
      expect(huddles).not_to be_empty
      
      # This should not cause additional queries due to includes
      huddles.each do |huddle|
        expect(huddle.huddle_playbook.organization.name).to be_present
      end
    end
  end
end
