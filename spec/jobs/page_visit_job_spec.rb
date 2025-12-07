require 'rails_helper'

RSpec.describe PageVisitJob, type: :job do
  describe '#perform' do
    let(:person) { create(:person) }
    let(:url) { '/test/path' }
    let(:page_title) { 'Test Page' }
    let(:user_agent) { 'Test Agent' }

    context 'when creating a new page visit' do
      it 'creates a new page visit with visit_count of 1' do
        expect {
          described_class.new.perform(person.id, url, page_title, user_agent)
        }.to change(PageVisit, :count).by(1)

        visit = PageVisit.last
        expect(visit.person).to eq(person)
        expect(visit.url).to eq(url)
        expect(visit.page_title).to eq(page_title)
        expect(visit.user_agent).to eq(user_agent)
        expect(visit.visit_count).to eq(1)
        expect(visit.visited_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'when updating an existing page visit' do
      let!(:existing_visit) do
        create(:page_visit, person: person, url: url, visit_count: 5, visited_at: 1.day.ago)
      end

      it 'increments visit_count' do
        expect {
          described_class.new.perform(person.id, url, page_title, user_agent)
        }.not_to change(PageVisit, :count)

        existing_visit.reload
        expect(existing_visit.visit_count).to eq(6)
      end

      it 'updates visited_at to current time' do
        old_visited_at = existing_visit.visited_at
        sleep(0.1) # Ensure time difference
        
        described_class.new.perform(person.id, url, page_title, user_agent)
        
        existing_visit.reload
        expect(existing_visit.visited_at).to be > old_visited_at
        expect(existing_visit.visited_at).to be_within(1.second).of(Time.current)
      end

      it 'updates page_title' do
        new_title = 'Updated Title'
        described_class.new.perform(person.id, url, new_title, user_agent)
        
        existing_visit.reload
        expect(existing_visit.page_title).to eq(new_title)
      end

      it 'updates user_agent' do
        new_agent = 'Updated Agent'
        described_class.new.perform(person.id, url, page_title, new_agent)
        
        existing_visit.reload
        expect(existing_visit.user_agent).to eq(new_agent)
      end
    end

    context 'when person does not exist' do
      it 'logs an error and does not raise' do
        expect(Rails.logger).to receive(:error).with(/Person with ID \d+ not found/)
        
        expect {
          described_class.new.perform(999999, url, page_title, user_agent)
        }.not_to raise_error
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(Person).to receive(:find).and_raise(StandardError.new('Unexpected error'))
      end

      it 'logs the error and re-raises it' do
        expect(Rails.logger).to receive(:error).at_least(:once)
        
        expect {
          described_class.new.perform(person.id, url, page_title, user_agent)
        }.to raise_error(StandardError, 'Unexpected error')
      end
    end
  end
end

