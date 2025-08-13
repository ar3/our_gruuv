require 'rails_helper'

RSpec.describe HuddleDecorator, type: :decorator do
  let(:company) { Company.create!(name: 'Test Company') }
  let(:team) { Team.create!(name: 'Test Team', parent: company) }
  
  describe '#status_with_time' do
    context 'when huddle is active' do
      let(:huddle) { Huddle.create!(huddle_playbook: create(:huddle_playbook, organization: team), started_at: 1.hour.ago, expires_at: 23.hours.from_now) }
      let(:decorated_huddle) { huddle.decorate }
      
      it 'shows active status with remaining hours' do
        expect(decorated_huddle.status_with_time).to eq('Active for 23 more hours')
      end
      
      it 'shows singular hour when 1 hour remaining' do
        huddle.update!(expires_at: 1.hour.from_now)
        expect(decorated_huddle.status_with_time).to eq('Active for 1 more hour')
      end
    end
    
    context 'when huddle is closed' do
      let(:huddle) { Huddle.create!(huddle_playbook: create(:huddle_playbook, organization: team), started_at: 25.hours.ago, expires_at: 1.hour.ago) }
      let(:decorated_huddle) { huddle.decorate }
      
      it 'shows inactive status with hours ago' do
        expect(decorated_huddle.status_with_time).to eq('Inactive for 1 hour')
      end
      
      it 'shows plural hours when more than 1 hour ago' do
        huddle.update!(expires_at: 3.hours.ago)
        expect(decorated_huddle.status_with_time).to eq('Inactive for 3 hours')
      end
    end
  end
end 