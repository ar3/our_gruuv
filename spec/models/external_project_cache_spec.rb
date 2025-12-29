require 'rails_helper'

RSpec.describe ExternalProjectCache, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:one_on_one_link) { create(:one_on_one_link, teammate: teammate) }

  describe 'associations' do
    it { should belong_to(:cacheable) }
    it { should belong_to(:last_synced_by_teammate).optional }
  end

  describe 'validations' do
    it 'validates source inclusion' do
      cache = build(:external_project_cache, cacheable: one_on_one_link, source: 'invalid')
      expect(cache).not_to be_valid
      expect(cache.errors[:source]).to be_present
    end

    it 'accepts valid sources' do
      %w[asana jira linear].each do |source|
        cache = build(:external_project_cache, cacheable: one_on_one_link, source: source)
        expect(cache).to be_valid
      end
    end

    it 'validates external_project_id presence' do
      cache = build(:external_project_cache, cacheable: one_on_one_link, external_project_id: nil)
      expect(cache).not_to be_valid
      expect(cache.errors[:external_project_id]).to be_present
    end

    it 'validates items_data limit' do
      items = (1..201).map { |i| { 'gid' => i.to_s, 'name' => "Item #{i}", 'completed' => false } }
      cache = build(:external_project_cache, cacheable: one_on_one_link, items_data: items)
      expect(cache).not_to be_valid
      expect(cache.errors[:items_data]).to be_present
    end

    it 'accepts up to 200 items' do
      items = (1..200).map { |i| { 'gid' => i.to_s, 'name' => "Item #{i}", 'completed' => false } }
      cache = build(:external_project_cache, cacheable: one_on_one_link, items_data: items)
      expect(cache).to be_valid
    end
  end

  describe 'scopes' do
    let!(:asana_cache) { create(:external_project_cache, cacheable: one_on_one_link, source: 'asana') }
    let!(:jira_cache) { create(:external_project_cache, cacheable: one_on_one_link, source: 'jira') }

    it 'filters by source' do
      expect(ExternalProjectCache.for_source('asana')).to include(asana_cache)
      expect(ExternalProjectCache.for_source('asana')).not_to include(jira_cache)
    end

    it 'filters recently synced' do
      other_teammate = create(:teammate, person: create(:person), organization: organization)
      other_link = create(:one_on_one_link, teammate: other_teammate, url: 'https://example.com/other')
      recent_cache = create(:external_project_cache, cacheable: other_link, source: 'asana', last_synced_at: 1.day.ago)
      old_cache = create(:external_project_cache, cacheable: other_link, source: 'jira', last_synced_at: 10.days.ago)
      
      expect(ExternalProjectCache.recently_synced).to include(recent_cache)
      expect(ExternalProjectCache.recently_synced).not_to include(old_cache)
    end

    it 'filters stale caches' do
      other_teammate = create(:teammate, person: create(:person), organization: organization)
      other_link = create(:one_on_one_link, teammate: other_teammate, url: 'https://example.com/other')
      recent_cache = create(:external_project_cache, cacheable: other_link, source: 'asana', last_synced_at: 1.day.ago)
      old_cache = create(:external_project_cache, cacheable: other_link, source: 'jira', last_synced_at: 10.days.ago)
      never_synced = create(:external_project_cache, cacheable: other_link, source: 'linear', last_synced_at: nil)
      
      expect(ExternalProjectCache.stale).to include(old_cache)
      expect(ExternalProjectCache.stale).to include(never_synced)
      expect(ExternalProjectCache.stale).not_to include(recent_cache)
    end
  end

  describe '#incomplete_items' do
    it 'returns only incomplete items' do
      items = [
        { 'gid' => '1', 'name' => 'Task 1', 'completed' => false },
        { 'gid' => '2', 'name' => 'Task 2', 'completed' => true },
        { 'gid' => '3', 'name' => 'Task 3', 'completed' => false }
      ]
      cache = create(:external_project_cache, cacheable: one_on_one_link, items_data: items)
      
      incomplete = cache.incomplete_items
      expect(incomplete.length).to eq(2)
      expect(incomplete.map { |i| i['gid'] }).to contain_exactly('1', '3')
    end
  end

  describe '#recently_completed_items' do
    it 'returns items completed within the specified days' do
      items = [
        { 'gid' => '1', 'name' => 'Task 1', 'completed' => true, 'completed_at' => 5.days.ago.iso8601 },
        { 'gid' => '2', 'name' => 'Task 2', 'completed' => true, 'completed_at' => 20.days.ago.iso8601 },
        { 'gid' => '3', 'name' => 'Task 3', 'completed' => true, 'completed_at' => 10.days.ago.iso8601 }
      ]
      cache = create(:external_project_cache, cacheable: one_on_one_link, items_data: items)
      
      recent = cache.recently_completed_items(14)
      expect(recent.length).to eq(2)
      expect(recent.map { |i| i['gid'] }).to contain_exactly('1', '3')
    end
  end

  describe '#items_for_section' do
    it 'returns sorted items for a section' do
      section_gid = 'section_1'
      items = [
        { 'gid' => '1', 'name' => 'Task 1', 'section_gid' => section_gid, 'completed' => false, 'due_on' => 3.days.from_now.to_date.to_s, 'assignee' => { 'name' => 'Alice' }, 'created_at' => 5.days.ago.iso8601 },
        { 'gid' => '2', 'name' => 'Task 2', 'section_gid' => section_gid, 'completed' => false, 'due_on' => 1.day.ago.to_date.to_s, 'assignee' => nil, 'created_at' => 3.days.ago.iso8601 },
        { 'gid' => '3', 'name' => 'Task 3', 'section_gid' => section_gid, 'completed' => false, 'due_on' => Date.current.to_s, 'assignee' => { 'name' => 'Bob' }, 'created_at' => 1.day.ago.iso8601 }
      ]
      cache = create(:external_project_cache, cacheable: one_on_one_link, items_data: items)
      
      section_items = cache.items_for_section(section_gid)
      expect(section_items.length).to eq(3)
      # Should be sorted: overdue first (Task 2), then due today (Task 3), then future (Task 1)
      expect(section_items[0]['gid']).to eq('2')
      expect(section_items[1]['gid']).to eq('3')
      expect(section_items[2]['gid']).to eq('1')
    end
  end

  describe '#synced_by_display' do
    it 'returns formatted string when synced' do
      syncer = create(:teammate, person: create(:person, first_name: 'John', last_name: 'Doe'))
      cache = create(:external_project_cache, 
                     cacheable: one_on_one_link, 
                     last_synced_at: Time.parse('2024-01-15 14:30:00'),
                     last_synced_by_teammate: syncer)
      
      display = cache.synced_by_display
      expect(display).to include('Synced by')
      expect(display).to include('John Doe')
      expect(display).to include('Jan 15, 2024')
    end

    it 'returns "Never synced" when not synced' do
      cache = create(:external_project_cache, cacheable: one_on_one_link, last_synced_at: nil)
      expect(cache.synced_by_display).to eq('Never synced')
    end
  end
end

