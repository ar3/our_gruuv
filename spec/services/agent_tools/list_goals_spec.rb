# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::ListGoals, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:other_person) { create(:person) }
  let(:other_teammate) { create(:teammate, person: other_person, organization: organization) }
  let(:context) do
    AgentTools::Context.new(
      organization: organization,
      person: person,
      company_teammate: teammate
    )
  end

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  def create_visible_goal(**attrs)
    create(
      :goal,
      :everyone_in_company,
      company: organization,
      most_likely_target_date: Date.today + 1.month,
      **attrs
    )
  end

  it "includes ownership and creator context on every goal" do
    owned = create_visible_goal(creator: teammate, owner: teammate, title: "Mine owned")
    created_only = create_visible_goal(creator: teammate, owner: organization, title: "I created org goal")
    visible_other = create_visible_goal(creator: other_teammate, owner: other_teammate, title: "Other visible")

    result = described_class.call(context: context, limit: 50)

    expect(result.ok?).to be(true)
    by_title = result.data[:goals].index_by { |g| g[:title] }

    expect(by_title["Mine owned"]).to include(
      owned_by_me: true,
      created_by_me: true,
      privacy_level: "everyone_in_company"
    )
    expect(by_title["Mine owned"][:owner]).to include(type: "CompanyTeammate", name: person.display_name)
    expect(by_title["Mine owned"][:creator][:path]).to be_present

    expect(by_title["I created org goal"]).to include(owned_by_me: false, created_by_me: true)
    expect(by_title["I created org goal"][:owner]).to include(type: "Organization")

    expect(by_title["Other visible"]).to include(owned_by_me: false, created_by_me: false)

    expect(owned).to be_persisted
    expect(created_only).to be_persisted
    expect(visible_other).to be_persisted
  end

  it "filters owned_by_me and created_by_me with AND" do
    create_visible_goal(creator: teammate, owner: teammate, title: "Both")
    create_visible_goal(creator: teammate, owner: organization, title: "Created only")
    create_visible_goal(creator: other_teammate, owner: teammate, title: "Owned only", privacy_level: "everyone_in_company")

    both = described_class.call(context: context, owned_by_me: true, created_by_me: true, limit: 50)
    expect(both.data[:goals].map { |g| g[:title] }).to eq(["Both"])

    owned = described_class.call(context: context, owned_by_me: true, limit: 50)
    expect(owned.data[:goals].map { |g| g[:title] }).to contain_exactly("Both", "Owned only")

    created = described_class.call(context: context, created_by_me: true, limit: 50)
    expect(created.data[:goals].map { |g| g[:title] }).to contain_exactly("Both", "Created only")
  end

  it "filters everyone_in_company and specific organization owner" do
    create_visible_goal(creator: teammate, owner: organization, title: "Org public")
    create(
      :goal,
      creator: teammate,
      owner: teammate,
      company: organization,
      title: "Private mine",
      privacy_level: "only_creator",
      most_likely_target_date: Date.today + 1.month
    )

    public_only = described_class.call(context: context, everyone_in_company: true, limit: 50)
    expect(public_only.data[:goals].map { |g| g[:title] }).to include("Org public")
    expect(public_only.data[:goals].map { |g| g[:title] }).not_to include("Private mine")

    by_owner = described_class.call(
      context: context,
      owner_type: "Organization",
      owner_id: organization.id,
      limit: 50
    )
    expect(by_owner.data[:goals].map { |g| g[:title] }).to eq(["Org public"])
  end

  it "filters my_relevant_goals to company-visible or owned by me" do
    create_visible_goal(creator: other_teammate, owner: other_teammate, title: "Public other").tap do |g|
      g.update!(started_at: 1.day.ago)
    end
    create_visible_goal(creator: teammate, owner: teammate, title: "Mine").tap do |g|
      g.update!(started_at: 1.day.ago)
    end

    result = described_class.call(context: context, my_relevant_goals: true, limit: 50)
    titles = result.data[:goals].map { |g| g[:title] }
    expect(titles).to include("Public other", "Mine")
  end
end
