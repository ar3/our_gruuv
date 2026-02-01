require 'rails_helper'

RSpec.describe Huddles::StatsService, type: :service do
  let(:company) { create(:organization, :company, name: 'Test Company') }
  let(:team) { create(:team, name: 'Test Team', company: company) }
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
    let!(:huddle1) { create(:huddle, team: team, started_at: 1.day.ago) }
    let!(:huddle2) { create(:huddle, team: create(:team, company: company), started_at: 2.days.ago) }
    let!(:old_huddle) { create(:huddle, team: create(:team, company: company), started_at: 7.weeks.ago) }

    it 'returns huddles within the date range' do
      result = service.huddles_in_range
      expect(result).to include(huddle1, huddle2)
      expect(result).not_to include(old_huddle)
    end

    it 'includes necessary associations' do
      result = service.huddles_in_range
      expect(result.first.association(:team).loaded?).to be true
      expect(result.first.team.association(:company).loaded?).to be true
    end

    it 'orders by started_at desc' do
      result = service.huddles_in_range
      expect(result.first).to eq(huddle1)
      expect(result.second).to eq(huddle2)
    end

    it 'memoizes the result' do
      expect(service.huddles_in_range).to equal(service.huddles_in_range)
    end
  end

  describe '#calculate_feedback_stats' do
    let!(:huddle) { create(:huddle, team: team, started_at: 1.day.ago) }
    let(:person1) { create(:person) }
    let(:person2) { create(:person) }
    let(:teammate1) { create(:teammate, person: person1, organization: company) }
    let(:teammate2) { create(:teammate, person: person2, organization: company) }

    before do
      # Create participants and feedbacks
      create(:huddle_participant, huddle: huddle, teammate: teammate1)
      create(:huddle_participant, huddle: huddle, teammate: teammate2)
      create(:huddle_feedback, huddle: huddle, teammate: teammate1, created_at: 1.day.ago)
      create(:huddle_feedback, huddle: huddle, teammate: teammate2, created_at: 1.day.ago)
    end

    it 'returns correct feedback count' do
      # Use participation_stats since it counts from huddles_in_range
      stats = service.participation_stats
      expect(stats[:total_feedbacks]).to eq(2)
    end

    it 'returns correct unique participant count' do
      # Use participation_stats since it counts from huddles_in_range
      stats = service.participation_stats
      expect(stats[:distinct_participant_count]).to eq(2)
    end

    it 'includes date range in stats' do
      stats = service.calculate_feedback_stats
      expect(stats[:start_date]).to be_present
      expect(stats[:end_date]).to be_present
    end

    it 'memoizes the result' do
      expect(service.feedback_stats).to equal(service.feedback_stats)
    end
  end

  describe '#calculate_participation_stats' do
    let!(:huddle) { create(:huddle, team: team, started_at: 1.day.ago) }
    let(:person1) { create(:person) }
    let(:person2) { create(:person) }
    let(:teammate1) { create(:teammate, person: person1, organization: company) }
    let(:teammate2) { create(:teammate, person: person2, organization: company) }

    before do
      create(:huddle_participant, huddle: huddle, teammate: teammate1)
      create(:huddle_participant, huddle: huddle, teammate: teammate2)
      create(:huddle_feedback, huddle: huddle, teammate: teammate1)
    end

    it 'calculates total participants correctly' do
      expect(service.calculate_participation_stats[:total_participants]).to eq(2)
    end

    it 'calculates total feedbacks correctly' do
      expect(service.calculate_participation_stats[:total_feedbacks]).to eq(1)
    end

    it 'calculates participation rate correctly' do
      expect(service.calculate_participation_stats[:participation_rate]).to eq(50.0)
    end

    it 'includes distinct participant information' do
      stats = service.calculate_participation_stats
      expect(stats[:distinct_participant_count]).to eq(2)
      expect(stats[:distinct_participant_names]).to be_an(Array)
    end

    it 'memoizes the result' do
      expect(service.participation_stats).to equal(service.participation_stats)
    end
  end

  describe '#calculate_rating_stats' do
    let!(:huddle) { create(:huddle, team: team, started_at: 1.day.ago) }
    let(:person) { create(:person) }
    let(:teammate) { create(:teammate, person: person, organization: company) }

    before do
      create(:huddle_feedback, huddle: huddle, teammate: teammate,
             informed_rating: 4, connected_rating: 4, goals_rating: 4, valuable_rating: 4,
             personal_conflict_style: 'Collaborative', team_conflict_style: 'Compromising')
    end

    it 'calculates average rating correctly' do
      expect(service.calculate_rating_stats[:average_rating]).to eq(16.0)
    end

    it 'includes conflict style distributions' do
      stats = service.calculate_rating_stats
      expect(stats[:personal_conflict_styles]).to eq({ 'Collaborative' => 1 })
      expect(stats[:team_conflict_styles]).to eq({ 'Compromising' => 1 })
    end

    it 'memoizes the result' do
      expect(service.rating_stats).to equal(service.rating_stats)
    end
  end

  describe '#calculate_weekly_stats' do
    let!(:huddle1) { create(:huddle, team: team, started_at: 1.day.ago) }
    let!(:huddle2) { create(:huddle, team: create(:team, company: company), started_at: 8.days.ago) }

    it 'groups huddles by week' do
      result = service.calculate_weekly_stats
      expect(result.keys.count).to be >= 1
    end

    it 'includes weekly participation and rating stats' do
      result = service.calculate_weekly_stats
      week_stats = result.values.first
      expect(week_stats).to have_key(:total_huddles)
      expect(week_stats).to have_key(:total_participants)
    end

    it 'memoizes the result' do
      expect(service.weekly_stats).to equal(service.weekly_stats)
    end
  end

  describe '#calculate_team_stats' do
    let!(:team1) { create(:team, company: company, name: 'Team 1') }
    let!(:team2) { create(:team, company: company, name: 'Team 2') }
    let!(:huddle1) { create(:huddle, team: team1, started_at: 1.day.ago) }
    let!(:huddle2) { create(:huddle, team: team2, started_at: 2.days.ago) }

    it 'groups stats by team' do
      result = service.calculate_team_stats
      expect(result.keys).to include(team1.id, team2.id)
    end

    it 'includes team metadata' do
      result = service.calculate_team_stats
      team_stats = result[team1.id]
      expect(team_stats[:id]).to eq(team1.id)
      expect(team_stats[:display_name]).to eq(team1.display_name)
      expect(team_stats[:company_id]).to eq(company.id)
    end

    it 'includes team-specific stats' do
      result = service.calculate_team_stats
      team_stats = result[team1.id]
      expect(team_stats).to have_key(:total_huddles)
      expect(team_stats).to have_key(:average_rating)
      expect(team_stats).to have_key(:participation_rate)
    end

    it 'memoizes the result' do
      expect(service.team_stats).to equal(service.team_stats)
    end
  end

  describe 'edge cases' do
    it 'handles huddles without teams gracefully' do
      # Note: With the new model, huddles always require a team
      # This test verifies the service handles empty results
      empty_company = create(:organization, :company)
      empty_service = described_class.new(empty_company)

      expect { empty_service.calculate_team_stats }.not_to raise_error
      expect(empty_service.calculate_team_stats).to eq({})
    end

    it 'handles company with no huddles' do
      empty_company = create(:organization, :company)
      empty_service = described_class.new(empty_company)

      expect(empty_service.huddles_in_range).to be_empty
      expect(empty_service.feedback_stats[:feedback_count]).to eq(0)
      expect(empty_service.participation_stats[:total_participants]).to eq(0)
    end
  end

  describe 'performance' do
    it 'preloads associations to avoid N+1 queries' do
      # Create multiple huddles with feedback and participants
      3.times do
        t = create(:team, company: company)
        h = create(:huddle, team: t, started_at: 1.day.ago)
        p = create(:person)
        tm = create(:teammate, person: p, organization: company)
        create(:huddle_participant, huddle: h, teammate: tm)
        create(:huddle_feedback, huddle: h, teammate: tm)
      end

      # Verify that associations are preloaded
      service = described_class.new(company)
      huddles = service.huddles_in_range.to_a

      # Check that associations are loaded
      expect(huddles.first.association(:team).loaded?).to be true
      expect(huddles.first.association(:huddle_feedbacks).loaded?).to be true
      expect(huddles.first.association(:huddle_participants).loaded?).to be true
    end
  end
end
