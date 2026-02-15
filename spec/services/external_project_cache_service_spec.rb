require 'rails_helper'

RSpec.describe ExternalProjectCacheService do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:one_on_one_link) { create(:one_on_one_link, teammate: teammate, url: 'https://app.asana.com/0/123456/789') }

  describe '.limit_items_to_200' do
    it 'limits to 200 items prioritizing incomplete' do
      incomplete = (1..150).map { |i| { 'gid' => i.to_s, 'name' => "Task #{i}", 'completed' => false } }
      completed = (151..200).map { |i| { 'gid' => i.to_s, 'name' => "Task #{i}", 'completed' => true, 'completed_at' => 1.day.ago.iso8601 } }
      
      result = ExternalProjectCacheService.limit_items_to_200(incomplete, completed)
      
      expect(result[:items].length).to eq(200)
      expect(result[:has_more]).to be false
    end

    it 'sets has_more flag when total exceeds 200' do
      incomplete = (1..150).map { |i| { 'gid' => i.to_s, 'name' => "Task #{i}", 'completed' => false } }
      completed = (151..250).map { |i| { 'gid' => i.to_s, 'name' => "Task #{i}", 'completed' => true, 'completed_at' => 1.day.ago.iso8601 } }
      
      result = ExternalProjectCacheService.limit_items_to_200(incomplete, completed)
      
      expect(result[:items].length).to eq(200)
      expect(result[:has_more]).to be true
      expect(result[:total_count]).to eq(250)
    end
  end

  describe '.format_sections_for_cache' do
    it 'formats sections data' do
      sections = [
        { 'gid' => '1', 'name' => 'Section 1' },
        { 'gid' => '2', 'name' => 'Section 2' }
      ]
      
      formatted = ExternalProjectCacheService.format_sections_for_cache(sections)
      
      expect(formatted.length).to eq(2)
      expect(formatted[0]['gid']).to eq('1')
      expect(formatted[0]['name']).to eq('Section 1')
      expect(formatted[0]['position']).to eq(0)
    end
  end

  describe '.format_items_for_cache' do
    it 'formats items data' do
      items = [
        { 'gid' => '1', 'name' => 'Task 1', 'section_gid' => 'section_1', 'completed' => false, 'assignee' => { 'gid' => 'user_1', 'name' => 'Alice' } }
      ]
      
      formatted = ExternalProjectCacheService.format_items_for_cache(items)
      
      expect(formatted.length).to eq(1)
      expect(formatted[0]['gid']).to eq('1')
      expect(formatted[0]['name']).to eq('Task 1')
      expect(formatted[0]['assignee']['name']).to eq('Alice')
    end
  end

  describe '.sync_project' do
    let(:asana_identity) { create(:teammate_identity, :asana, teammate: teammate) }
    let(:asana_service) { instance_double(AsanaService) }

    before do
      allow(AsanaService).to receive(:new).with(teammate).and_return(asana_service)
      allow(asana_service).to receive(:authenticated?).and_return(true)
      allow(ExternalProjectUrlParser).to receive(:extract_project_id).and_return('12345')
      allow(ExternalProjectUrlParser).to receive(:detect_source).and_return('asana')
    end

    context 'when sections fetch fails' do
      it 'propagates token_expired error' do
        allow(asana_service).to receive(:fetch_project_sections).and_return({
          success: false,
          error: 'token_expired',
          message: 'Token expired'
        })

        result = ExternalProjectCacheService.sync_project(one_on_one_link, 'asana', teammate)

        expect(result[:success]).to be false
        expect(result[:error_type]).to eq('token_expired')
        expect(result[:error]).to eq('Token expired')
      end

      it 'propagates permission_denied error' do
        allow(asana_service).to receive(:fetch_project_sections).and_return({
          success: false,
          error: 'permission_denied',
          message: 'Permission denied'
        })

        result = ExternalProjectCacheService.sync_project(one_on_one_link, 'asana', teammate)

        expect(result[:success]).to be false
        expect(result[:error_type]).to eq('permission_denied')
      end

      it 'propagates not_found error' do
        allow(asana_service).to receive(:fetch_project_sections).and_return({
          success: false,
          error: 'not_found',
          message: 'Project not found'
        })

        result = ExternalProjectCacheService.sync_project(one_on_one_link, 'asana', teammate)

        expect(result[:success]).to be false
        expect(result[:error_type]).to eq('not_found')
      end
    end

    context 'when tasks fetch fails' do
      it 'propagates error from fetch_all_project_tasks' do
        allow(asana_service).to receive(:fetch_project_sections).and_return({
          success: true,
          sections: [{ 'gid' => '1', 'name' => 'Section 1' }]
        })
        allow(asana_service).to receive(:fetch_all_project_tasks).and_return({
          success: false,
          error: 'token_expired',
          message: 'Token expired'
        })

        result = ExternalProjectCacheService.sync_project(one_on_one_link, 'asana', teammate)

        expect(result[:success]).to be false
        expect(result[:error_type]).to eq('token_expired')
      end
    end

    context 'when cache save fails' do
      it 'returns validation error' do
        allow(asana_service).to receive(:fetch_project_sections).and_return({
          success: true,
          sections: []
        })
        allow(asana_service).to receive(:fetch_all_project_tasks).and_return({
          success: true,
          incomplete: [],
          completed: []
        })
        allow(asana_service).to receive(:format_for_cache).and_return({
          sections: [],
          tasks: []
        })
        allow_any_instance_of(ExternalProjectCache).to receive(:save).and_return(false)
        allow_any_instance_of(ExternalProjectCache).to receive(:errors).and_return(
          double(full_messages: ['Validation failed'])
        )

        result = ExternalProjectCacheService.sync_project(one_on_one_link, 'asana', teammate)

        expect(result[:success]).to be false
        expect(result[:error_type]).to eq('validation_error')
      end
    end

    context 'when exception occurs' do
      it 'returns exception error' do
        allow(asana_service).to receive(:fetch_project_sections).and_raise(StandardError.new('Unexpected error'))

        result = ExternalProjectCacheService.sync_project(one_on_one_link, 'asana', teammate)

        expect(result[:success]).to be false
        expect(result[:error_type]).to eq('exception')
        expect(result[:error]).to eq('Unexpected error')
      end
    end
  end

  describe 'TeamAsanaLink support' do
    let(:team) { create(:team, company: organization) }
    let(:team_asana_link) { create(:team_asana_link, team: team, url: 'https://app.asana.com/0/999888/777', deep_integration_config: { 'asana_project_id' => '999888' }) }
    let(:asana_service) { instance_double(AsanaService) }

    before do
      allow(AsanaService).to receive(:new).with(teammate).and_return(asana_service)
      allow(asana_service).to receive(:authenticated?).and_return(true)
      allow(asana_service).to receive(:fetch_project_sections).and_return(success: true, sections: [])
      allow(asana_service).to receive(:fetch_all_project_tasks).and_return(success: true, incomplete: [], completed: [])
      allow(asana_service).to receive(:format_for_cache).and_return(sections: [], tasks: [])
    end

    it 'syncs project for TeamAsanaLink using asana_project_id' do
      create(:teammate_identity, :asana, teammate: teammate)
      expect {
        ExternalProjectCacheService.sync_project(team_asana_link, 'asana', teammate)
      }.to change(ExternalProjectCache, :count).by(1)
      cache = ExternalProjectCache.find_by(cacheable: team_asana_link, source: 'asana')
      expect(cache).to be_present
      expect(cache.external_project_id).to eq('999888')
    end
  end
end

