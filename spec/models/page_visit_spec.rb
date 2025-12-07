require 'rails_helper'

RSpec.describe PageVisit, type: :model do
  describe 'associations' do
    it { should belong_to(:person) }
  end

  describe 'validations' do
    it { should validate_presence_of(:person) }
    it { should validate_presence_of(:url) }
    it { should validate_presence_of(:visit_count) }
    it { should validate_numericality_of(:visit_count).is_greater_than_or_equal_to(1) }
  end

  describe 'scopes' do
    let(:person) { create(:person) }
    let!(:visit1) { create(:page_visit, person: person, url: '/page1', visited_at: 3.days.ago, visit_count: 5) }
    let!(:visit2) { create(:page_visit, person: person, url: '/page2', visited_at: 1.day.ago, visit_count: 3) }
    let!(:visit3) { create(:page_visit, person: person, url: '/page3', visited_at: 2.days.ago, visit_count: 10) }
    let!(:other_person_visit) { create(:page_visit, url: '/other', visited_at: 1.hour.ago, visit_count: 1) }

    describe '.recent' do
      it 'orders by visited_at descending' do
        expect(PageVisit.recent.to_a).to eq([other_person_visit, visit2, visit3, visit1])
      end
    end

    describe '.most_visited' do
      it 'orders by visit_count descending, then visited_at descending' do
        expect(PageVisit.most_visited.to_a).to eq([visit3, visit1, visit2, other_person_visit])
      end
    end

    describe '.for_person' do
      it 'returns only visits for the specified person' do
        expect(PageVisit.for_person(person).to_a).to contain_exactly(visit1, visit2, visit3)
      end
    end
  end

  describe 'unique constraint' do
    let(:person) { create(:person) }
    let(:url) { '/test/path' }

    it 'enforces uniqueness of person_id and url combination' do
      create(:page_visit, person: person, url: url)
      
      expect {
        create(:page_visit, person: person, url: url)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows same url for different people' do
      person2 = create(:person)
      create(:page_visit, person: person, url: url)
      
      expect {
        create(:page_visit, person: person2, url: url)
      }.not_to raise_error
    end
  end
end
