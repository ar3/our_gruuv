require 'rails_helper'

RSpec.describe Prompt, type: :model do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: company) }
  let(:template) { create(:prompt_template, company: company) }

  describe 'associations' do
    it { should belong_to(:company_teammate) }
    it { should belong_to(:prompt_template) }
    it { should have_many(:prompt_answers).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:company_teammate) }
    it { should validate_presence_of(:prompt_template) }
  end

  describe 'scopes' do
    let!(:open_prompt) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }
    let!(:closed_prompt) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template) }

    describe '.open' do
      it 'returns prompts with closed_at = nil' do
        expect(described_class.open).to include(open_prompt)
        expect(described_class.open).not_to include(closed_prompt)
      end
    end

    describe '.closed' do
      it 'returns prompts with closed_at not nil' do
        expect(described_class.closed).to include(closed_prompt)
        expect(described_class.closed).not_to include(open_prompt)
      end
    end

    describe '.for_teammate' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: company) }
      let!(:other_prompt) { create(:prompt, company_teammate: other_teammate, prompt_template: template) }

      it 'returns prompts for specific teammate' do
        expect(described_class.for_teammate(teammate)).to include(open_prompt, closed_prompt)
        expect(described_class.for_teammate(teammate)).not_to include(other_prompt)
      end
    end

    describe '.for_template' do
      let(:other_template) { create(:prompt_template, company: company) }
      let(:other_teammate) { CompanyTeammate.create!(person: create(:person), organization: company) }
      let!(:other_prompt) { create(:prompt, company_teammate: other_teammate, prompt_template: other_template) }

      it 'returns prompts for specific template' do
        expect(described_class.for_template(template)).to include(open_prompt, closed_prompt)
        expect(described_class.for_template(template)).not_to include(other_prompt)
      end
    end

    describe '.ordered' do
      # Close existing prompts first
      before do
        open_prompt.close! if open_prompt.open?
        closed_prompt # ensure it exists
      end
      
      let!(:old_prompt) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template, created_at: 2.days.ago) }
      let!(:new_prompt) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template, created_at: 1.day.ago) }

      it 'returns prompts ordered by created_at descending' do
        ordered = described_class.ordered.to_a
        # Find our test prompts in the ordered list
        old_idx = ordered.index(old_prompt)
        new_idx = ordered.index(new_prompt)
        expect(old_idx).to be_present
        expect(new_idx).to be_present
        # New prompt should come before old prompt (more recent first)
        expect(new_idx).to be < old_idx
      end
    end
  end

  describe 'validations for one open prompt per teammate' do
    let!(:existing_open) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }

    it 'allows only one open prompt per teammate' do
      new_open = build(:prompt, :open, company_teammate: teammate, prompt_template: template)
      expect(new_open).not_to be_valid
      expect(new_open.errors[:base]).to include('Only one open prompt allowed per teammate')
    end

    it 'allows multiple closed prompts per teammate' do
      closed1 = create(:prompt, :closed, company_teammate: teammate, prompt_template: template)
      closed2 = build(:prompt, :closed, company_teammate: teammate, prompt_template: template)
      expect(closed2).to be_valid
    end

    it 'allows open prompt for different teammate' do
      other_person = create(:person)
      other_teammate = CompanyTeammate.create!(person: other_person, organization: company)
      other_open = build(:prompt, :open, company_teammate: other_teammate, prompt_template: template)
      expect(other_open).to be_valid
    end
  end

  describe '#open?' do
    it 'returns true when closed_at is nil' do
      prompt = create(:prompt, closed_at: nil)
      expect(prompt.open?).to be true
    end

    it 'returns false when closed_at is present' do
      prompt = create(:prompt, closed_at: Time.current)
      expect(prompt.open?).to be false
    end
  end

  describe '#closed?' do
    it 'returns true when closed_at is present' do
      prompt = create(:prompt, closed_at: Time.current)
      expect(prompt.closed?).to be true
    end

    it 'returns false when closed_at is nil' do
      prompt = create(:prompt, closed_at: nil)
      expect(prompt.closed?).to be false
    end
  end

  describe '#close!' do
    it 'sets closed_at to current time' do
      prompt = create(:prompt, :open, company_teammate: teammate, prompt_template: template)
      expect(prompt.closed_at).to be_nil
      
      prompt.close!
      expect(prompt.closed_at).to be_present
      expect(prompt.closed_at).to be_within(1.second).of(Time.current)
    end
  end
end

