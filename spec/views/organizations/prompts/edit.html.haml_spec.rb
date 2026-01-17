require 'rails_helper'
require 'cgi'

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
    assign(:linked_goals, { goal1.id => goal1, goal2.id => goal2 })
    assign(:linked_goal_check_ins, {})
    
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
    allow(view).to receive(:manage_goals_organization_prompt_path) do |org, prompt_obj, options = {}|
      base_path = "/organizations/#{org.id}/prompts/#{prompt_obj.id}/manage_goals"
      if options.present?
        query_params = options.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
        "#{base_path}?#{query_params}"
      else
        base_path
      end
    end
    allow(view).to receive(:close_tab_path) do |options = {}|
      base_path = "/close_tab"
      if options.present?
        query_params = options.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
        "#{base_path}?#{query_params}"
      else
        base_path
      end
    end
    allow(view).to receive(:organization_goal_path).and_wrap_original do |method, *args|
      "/organizations/#{args[0].id}/goals/#{args[1].id}"
    end
    allow(view).to receive(:organization_prompt_prompt_goal_path).and_wrap_original do |method, *args|
      "/organizations/#{args[0].id}/prompts/#{args[1].id}/prompt_goals/#{args[2].id}"
    end
    
    # Define helper methods that are available in views
    def view.current_organization
      @current_organization
    end
    
    view.instance_variable_set(:@current_organization, organization)
    
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
    
    # Mock prompt associations (use relation so .pluck, .any?, .group_by work in view)
    allow(prompt).to receive(:goals).and_return(Goal.where(id: [goal1.id, goal2.id]))
    allow(prompt).to receive(:prompt_goals).and_return([prompt_goal1, prompt_goal2])
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

    it 'displays goals in hierarchy' do
      render
      expect(rendered).to have_content(goal1.title)
      expect(rendered).to have_content(goal2.title)
    end
  end

  context 'when prompt has no associated goals' do
    before do
      PromptGoal.where(prompt: prompt).destroy_all
      prompt.reload
      allow(prompt).to receive(:goals).and_return([])
      allow(prompt).to receive(:prompt_goals).and_return([])
    end

    it 'shows message about no goals' do
      render
      expect(rendered).to have_content('No goals associated with this prompt.')
    end

    it 'shows link to associate goals when can_edit is true' do
      render
      expect(rendered).to have_link('Associate goals')
    end

    it 'opens associate goals link in new window with return_url=edit and return_text=template title' do
      render
      link = Capybara.string(rendered).find_link('Associate goals')
      expect(link[:target]).to eq('_blank')
      expect(link[:href]).to include('return_url')
      expect(link[:href]).to include('return_text')
      expect(CGI.unescape(link[:href])).to include(template.title)
    end
  end

  context 'when can_edit is true' do
    it 'shows Manage Goals as submit button (name=save_and_manage_goals) that saves and redirects to manage_goals' do
      render
      button = Capybara.string(rendered).find('button[name="save_and_manage_goals"]')
      expect(button[:form]).to eq('prompt-edit-form')
      expect(button).to have_content('Manage Goals')
    end
  end
end

