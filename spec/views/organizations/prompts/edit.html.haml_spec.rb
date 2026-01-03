require 'rails_helper'

RSpec.describe 'organizations/prompts/edit', type: :view do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, :company) }
  let(:teammate) do
    CompanyTeammate.find_or_create_by!(person: person, organization: organization)
  end
  let(:template) { create(:prompt_template, :available, company: organization) }
  let(:prompt) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }
  let(:goal1) { create(:goal, owner: teammate, creator: teammate, company: organization, goal_type: 'stepping_stone_activity') }
  let(:goal2) { create(:goal, owner: teammate, creator: teammate, company: organization, goal_type: 'quantitative_key_result') }
  let(:prompt_goal1) { PromptGoal.create!(prompt: prompt, goal: goal1) }
  let(:prompt_goal2) { PromptGoal.create!(prompt: prompt, goal: goal2) }

  before do
    assign(:organization, organization)
    assign(:prompt, prompt)
    assign(:prompt_template, template)
    assign(:prompt_questions, [])
    assign(:archived_questions, [])
    assign(:prompt_answers, {})
    assign(:archived_answers, {})
    assign(:can_edit, true)
    assign(:prompt_goals, [prompt_goal1, prompt_goal2])
    
    # Mock policy
    allow(view).to receive(:policy) do |obj|
      if obj.is_a?(PromptGoal)
        double(destroy?: true)
      elsif obj == prompt
        double(update?: true, show?: true)
      else
        double(update?: true, show?: true, destroy?: true)
      end
    end
    
    # Mock route helpers
    allow(view).to receive(:organization_prompts_path).and_return("/organizations/#{organization.id}/prompts")
    allow(view).to receive(:edit_organization_prompt_path).and_return("/organizations/#{organization.id}/prompts/#{prompt.id}/edit")
    allow(view).to receive(:organization_prompt_path).and_return("/organizations/#{organization.id}/prompts/#{prompt.id}")
    allow(view).to receive(:manage_goals_organization_prompt_path).and_return("/organizations/#{organization.id}/prompts/#{prompt.id}/manage_goals")
    allow(view).to receive(:organization_goal_path).and_wrap_original do |method, *args|
      "/organizations/#{args[0].id}/goals/#{args[1].id}"
    end
    allow(view).to receive(:organization_prompt_prompt_goal_path).and_wrap_original do |method, *args|
      "/organizations/#{args[0].id}/prompts/#{args[1].id}/prompt_goals/#{args[2].id}"
    end
    
    # Mock helper methods
    allow(view).to receive(:format_time_in_user_timezone).and_return("Jan 1, 2024 12:00 PM")
    allow(view).to receive(:goal_category_badge_class).and_return("bg-primary")
    allow(view).to receive(:goal_category_label).and_return("Category")
    allow(view).to receive(:goal_privacy_tooltip_text).and_return("Privacy tooltip")
    allow(view).to receive(:goal_privacy_rings_with_label).and_return("🔒 Private")
    allow(view).to receive(:goal_badge_class).and_return("bg-primary")
    allow(view).to receive(:goal_status_icon).and_return("bi-circle")
    allow(view).to receive(:goal_should_be_struck_through?).and_return(false)
    allow(view).to receive(:request).and_return(double(url: "/organizations/#{organization.id}/prompts/#{prompt.id}/edit"))
  end

  it 'renders the edit form' do
    render
    expect(rendered).to have_content('Reflection Details')
    expect(rendered).to have_content('Answer Questions')
  end

  context 'when prompt has associated goals' do
    before do
      prompt_goal1
      prompt_goal2
      prompt.reload
    end

    it 'displays associated goals grouped by type' do
      render
      expect(rendered).to have_content('Associated Goals')
      expect(rendered).to have_content('Stepping Stones/Activities')
      expect(rendered).to have_content('Measurable Outcomes')
    end

    it 'uses the goal_list_item partial for each goal' do
      # The partial will be rendered, we just verify the page renders successfully
      # The actual partial rendering is tested in integration/request specs
      render
      expect(rendered).to have_content(goal1.title)
      expect(rendered).to have_content(goal2.title)
    end

    it 'shows disassociate button when can_edit is true' do
      render
      # Should have delete forms for each prompt_goal
      expect(rendered).to have_css('form[action*="prompt_goals"]', count: 2)
      # Should have trash icons in the delete buttons
      expect(rendered).to have_css('i.bi-trash', count: 2)
    end

    it 'does not show disassociate button when can_edit is false' do
      assign(:can_edit, false)
      allow(view).to receive(:policy).and_return(double(update?: false, show?: true))
      
      render
      expect(rendered).not_to have_css('form[action*="prompt_goals"]')
    end
  end

  context 'when prompt has no associated goals' do
    before do
      prompt.prompt_goals.destroy_all
      prompt.reload
    end

    it 'shows message about no goals' do
      render
      expect(rendered).to have_content('No goals associated with this prompt.')
    end

    it 'shows link to associate goals when can_edit is true' do
      render
      expect(rendered).to have_link('Associate goals')
    end
  end
end

