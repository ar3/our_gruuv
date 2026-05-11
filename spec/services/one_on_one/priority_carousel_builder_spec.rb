require "rails_helper"

RSpec.describe OneOnOne::PriorityCarouselBuilder, type: :service do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }

  describe ".call" do
    it "builds 12 ordered priorities and starts at first attention item" do
      one_on_one_link = create(:one_on_one_link, teammate: teammate, url: "https://app.asana.com/0/123/456")

      result = described_class.call(
        organization: organization,
        teammate: teammate,
        one_on_one_link: one_on_one_link
      )

      expect(result[:priorities].size).to eq(12)
      expect(result[:priorities].first[:title]).to eq(described_class::ASANA_URGENT_TASKS_TITLE)
      expect(result[:priorities].first[:needs_attention]).to eq(true)
      expect(result[:first_attention_index]).to eq(0)
    end

    it "marks Asana-specific priorities as not applicable when no Asana source" do
      one_on_one_link = create(:one_on_one_link, teammate: teammate, url: "https://example.com/1-1")

      result = described_class.call(
        organization: organization,
        teammate: teammate,
        one_on_one_link: one_on_one_link
      )

      first = result[:priorities][0]
      eighth = result[:priorities][8]
      remaining_asana = result[:priorities][10]

      expect(first[:title]).to eq(described_class::ASANA_URGENT_TASKS_TITLE)
      expect(first[:not_applicable]).to eq(true)
      expect(first[:needs_attention]).to eq(false)
      expect(eighth[:title]).to eq("Does #{teammate.person.casual_name} have at least one active goal?")
      expect(remaining_asana[:title]).to eq(described_class::REMAINING_ASANA_TASKS_TITLE)
      expect(remaining_asana[:not_applicable]).to eq(true)
    end

    it "includes Asana task permalinks in urgent-task concrete items when tasks have gids" do
      due = Date.current.strftime("%Y-%m-%d")
      one_on_one_link = create(
        :one_on_one_link,
        teammate: teammate,
        url: "https://app.asana.com/0/999888/777",
        deep_integration_config: { "asana_project_id" => "999888" }
      )
      create(
        :external_project_cache,
        cacheable: one_on_one_link,
        items_data: [
          {
            "gid" => "task-abc",
            "name" => "Ship feature",
            "completed" => false,
            "due_on" => due
          }
        ]
      )

      result = described_class.call(
        organization: organization,
        teammate: teammate,
        one_on_one_link: one_on_one_link
      )

      urgent = result[:priorities].find { |p| p[:title] == described_class::ASANA_URGENT_TASKS_TITLE }
      expect(urgent[:needs_attention]).to eq(true)
      item = urgent[:concrete_items].first
      expect(item).to be_a(Hash)
      expect(item[:url]).to eq("https://app.asana.com/0/999888/task-abc")
      expect(item[:label]).to include("Ship feature")
    end

    it "priority 3 (WTM without goals) explains why goals matter, links each row to the teammate lens, and adds a compact goal CTA" do
      employee_person = create(:person, first_name: "Jamie", last_name: "Taylor")
      wtm_teammate = create(:teammate, organization: organization, person: employee_person)
      one_on_one_link = create(:one_on_one_link, teammate: wtm_teammate, url: "https://example.com/hub")

      assignment = create(:assignment, company: organization, title: "Ship Widgets")
      create(:assignment_tenure, teammate: wtm_teammate, assignment: assignment)
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: wtm_teammate, assignment: assignment)

      aspiration = create(:aspiration, company: organization, name: "Customer Love")
      create(:aspiration_check_in, :finalized, teammate: wtm_teammate, aspiration: aspiration,
        employee_rating: "working_to_meet", manager_rating: "working_to_meet", official_rating: "working_to_meet")

      result = described_class.call(
        organization: organization,
        teammate: wtm_teammate,
        one_on_one_link: one_on_one_link
      )

      wtm_priority = result[:priorities].find do |p|
        p[:title] == "Are any working-to-meet assignments or aspirational values missing active goals?"
      end

      expect(wtm_priority[:needs_attention]).to eq(true)
      expect(wtm_priority[:reason]).to eq(
        "Whenever we are working to meet expectations, we should have goals that help give clarity as to what has to be done in order to be meeting expectations"
      )

      assignment_item = wtm_priority[:concrete_items].find { |i| i[:label].start_with?("Assignment:") }
      aspiration_item = wtm_priority[:concrete_items].find { |i| i[:label].start_with?("Aspiration:") }

      routes = Rails.application.routes.url_helpers
      expect(assignment_item[:url]).to eq(routes.organization_teammate_assignment_path(organization, wtm_teammate, assignment))
      expect(assignment_item[:add_goal_label]).to eq("Add goal for JT + this assignment")
      expect(assignment_item[:add_goal_url]).to eq(
        routes.choose_manage_goals_organization_assignment_path(
          organization,
          assignment,
          return_url: routes.organization_company_teammate_one_on_one_link_path(organization, wtm_teammate),
          return_text: "Back to 1:1 Hub",
          for_company_teammate_id: wtm_teammate.id
        )
      )

      expect(aspiration_item[:url]).to eq(routes.organization_teammate_aspiration_path(organization, wtm_teammate, aspiration))
      expect(aspiration_item[:add_goal_label]).to eq("Add goal for JT + this aspirational value")
      expect(aspiration_item[:add_goal_url]).to eq(
        routes.choose_manage_goals_organization_aspiration_path(
          organization,
          aspiration,
          return_url: routes.organization_company_teammate_one_on_one_link_path(organization, wtm_teammate),
          return_text: "Back to 1:1 Hub",
          for_company_teammate_id: wtm_teammate.id
        )
      )
    end

    it "priority 3 when WTM areas have active goals lists each with goal counts and teammate lens links" do
      employee_person = create(:person, first_name: "Rae", last_name: "Lee")
      tm = create(:teammate, organization: organization, person: employee_person)
      one_on_one_link = create(:one_on_one_link, teammate: tm, url: "https://example.com/hub")

      assignment = create(:assignment, company: organization, title: "Build API")
      create(:assignment_tenure, teammate: tm, assignment: assignment)
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: tm, assignment: assignment)

      goal = create(:goal, owner: tm, creator: tm, company_id: organization.id)
      create(:goal_association, goal: goal, associable: assignment)
      create(:goal_association, goal: create(:goal, owner: tm, creator: tm, company_id: organization.id), associable: assignment)

      aspiration = create(:aspiration, company: organization, name: "Team First")
      create(:aspiration_check_in, :finalized, teammate: tm, aspiration: aspiration,
        employee_rating: "working_to_meet", manager_rating: "working_to_meet", official_rating: "working_to_meet")
      goal2 = create(:goal, owner: tm, creator: tm, company_id: organization.id)
      create(:goal_association, goal: goal2, associable: aspiration)
      create(:goal_association, goal: create(:goal, owner: tm, creator: tm, company_id: organization.id), associable: aspiration)

      result = described_class.call(organization: organization, teammate: tm, one_on_one_link: one_on_one_link)
      wtm_priority = result[:priorities].find { |p| p[:title].include?("working-to-meet assignments") }

      expect(wtm_priority[:needs_attention]).to eq(false)
      expect(wtm_priority[:reason]).to be_nil
      routes = Rails.application.routes.url_helpers
      expect(wtm_priority[:concrete_items].size).to eq(2)
      api_item = wtm_priority[:concrete_items].find { |i| i[:label].include?("Build API") }
      expect(api_item[:label]).to include("2 active goals")
      expect(api_item[:url]).to eq(routes.organization_teammate_assignment_path(organization, tm, assignment))
      asp_item = wtm_priority[:concrete_items].find { |i| i[:label].include?("Team First") }
      expect(asp_item[:label]).to include("2 active goals")
      expect(asp_item[:url]).to eq(routes.organization_teammate_aspiration_path(organization, tm, aspiration))
    end

    it "priority 3 when no WTM surfaces two reason lines and more details link to review_most_recent" do
      employee_person = create(:person, first_name: "Sam", last_name: "Pat")
      tm = create(:teammate, organization: organization, person: employee_person)
      one_on_one_link = create(:one_on_one_link, teammate: tm, url: "https://example.com/hub")

      assignment = create(:assignment, company: organization, title: "Ops")
      create(:assignment_tenure, teammate: tm, assignment: assignment)
      create(:assignment_check_in, :finalized, teammate: tm, assignment: assignment)

      aspiration = create(:aspiration, company: organization, name: "Growth")
      create(:aspiration_check_in, :finalized, teammate: tm, aspiration: aspiration)

      result = described_class.call(organization: organization, teammate: tm, one_on_one_link: one_on_one_link)
      wtm_priority = result[:priorities].find { |p| p[:title].include?("working-to-meet assignments") }

      expect(wtm_priority[:needs_attention]).to eq(false)
      expect(wtm_priority[:reason]).to eq(
        [
          "#{tm.person.casual_name} is meeting or exceeding expectations for 1 required and active assignment and 1 aspirational value.",
          "#{tm.person.casual_name} has had all relevant check-ins."
        ]
      )
      expect(wtm_priority[:concrete_items]).to eq([])
      routes = Rails.application.routes.url_helpers
      expect(wtm_priority[:cta_label]).to eq("More details")
      expect(wtm_priority[:cta_path]).to eq(routes.review_most_recent_organization_company_teammate_check_ins_path(organization, tm))
    end

    it "priority 3 when no WTM and an aspiration lacks a check-in, second line calls out missing aspirational check-ins" do
      employee_person = create(:person, first_name: "Alex", last_name: "Kim")
      tm = create(:teammate, organization: organization, person: employee_person)
      one_on_one_link = create(:one_on_one_link, teammate: tm, url: "https://example.com/hub")

      assignment = create(:assignment, company: organization, title: "Ops")
      create(:assignment_tenure, teammate: tm, assignment: assignment)
      create(:assignment_check_in, :finalized, teammate: tm, assignment: assignment)

      create(:aspiration, company: organization, name: "Growth")

      result = described_class.call(organization: organization, teammate: tm, one_on_one_link: one_on_one_link)
      wtm_priority = result[:priorities].find { |p| p[:title].include?("working-to-meet assignments") }

      expect(wtm_priority[:reason]).to eq(
        [
          "#{tm.person.casual_name} is meeting or exceeding expectations for 1 required and active assignment and 0 aspirational values.",
          "#{tm.person.casual_name} has not had a check-in on 1 aspirational value."
        ]
      )
    end

    it "priority 5 when published OGOs were given uses linked summary with observees and rateables" do
      routes = Rails.application.routes.url_helpers
      observer_person = create(:person, first_name: "Pat", last_name: "Lee")
      hub_tm = create(:teammate, organization: organization, person: observer_person)
      observee_person = create(:person, first_name: "Quinn", last_name: "River")
      observee_tm = create(:teammate, organization: organization, person: observee_person)
      one_on_one_link = create(:one_on_one_link, teammate: hub_tm, url: "https://example.com/hub")

      assignment = create(:assignment, company: organization, title: "Revenue goal")
      aspiration = create(:aspiration, company: organization, name: "Customer focus")
      ability = create(:ability, company: organization, name: "Facilitation")

      obs = create(
        :observation,
        observer: observer_person,
        company: organization,
        published_at: Time.current,
        observed_at: Time.current,
        privacy_level: :observed_only,
        story: "Great collaboration today!"
      )
      obs.observees.destroy_all
      create(:observee, observation: obs, teammate: observee_tm)
      create(:observation_rating, observation: obs, rateable: assignment, rating: :agree)
      create(:observation_rating, observation: obs, rateable: aspiration, rating: :agree)
      create(:observation_rating, observation: obs, rateable: ability, rating: :agree)

      result = described_class.call(
        organization: organization,
        teammate: hub_tm,
        one_on_one_link: one_on_one_link
      )
      p5 = result[:priorities][4]

      expect(p5[:title]).to include("given a published observation")
      expect(p5[:needs_attention]).to eq(false)
      expect(p5[:reason]).to be_nil
      expect(p5[:concrete_items]).to eq([])
      expect(p5[:reason_plain]).to include("published OGO")
      expect(p5[:reason_plain]).to include(observee_person.casual_name)
      expect(p5[:reason_plain]).to include("Revenue goal")
      expect(p5[:reason_plain]).to include("Customer focus")
      expect(p5[:reason_plain]).to include("Facilitation")
      expect(p5[:reason_plain]).to end_with("in the last 30 days!!")

      html = p5[:reason_html].to_s
      expect(html).to include(routes.organization_observations_path(organization, involving_teammate_id: hub_tm.id))
      expect(html).to include(routes.internal_organization_company_teammate_path(organization, observee_tm))
      expect(html).to include(routes.organization_assignment_path(organization, assignment))
      expect(html).to include(routes.organization_aspiration_path(organization, aspiration))
      expect(html).to include(routes.organization_ability_path(organization, ability))
    end

    it "priority 6 when observations were received shows count sentence and linked observer/date/about lines" do
      routes = Rails.application.routes.url_helpers
      observer_person = create(:person, first_name: "Morgan", last_name: "Lee")
      observer_tm = create(:teammate, organization: organization, person: observer_person)
      hub_person = create(:person, first_name: "Riley", last_name: "Kim")
      hub_tm = create(:teammate, organization: organization, person: hub_person)
      one_on_one_link = create(:one_on_one_link, teammate: hub_tm, url: "https://example.com/hub")

      assignment = create(:assignment, company: organization, title: "Launch v2")
      ability = create(:ability, company: organization, name: "Writing")

      obs = create(
        :observation,
        observer: observer_person,
        company: organization,
        published_at: Time.current,
        observed_at: Time.current,
        privacy_level: :observed_only,
        story: "Strong progress on the launch."
      )
      obs.observees.destroy_all
      create(:observee, observation: obs, teammate: hub_tm)
      create(:observation_rating, observation: obs, rateable: assignment, rating: :agree)
      create(:observation_rating, observation: obs, rateable: ability, rating: :agree)

      result = described_class.call(
        organization: organization,
        teammate: hub_tm,
        one_on_one_link: one_on_one_link
      )
      p6 = result[:priorities][5]

      expect(p6[:title]).to include("received a published observation")
      expect(p6[:needs_attention]).to eq(false)
      expect(p6[:reason]).to eq("1 Published non-journal observations were received in the last 30 days.")
      expect(p6[:concrete_items].size).to eq(1)
      line = p6[:concrete_items].first[:label_html].to_s
      involving_href = routes.organization_observations_path(organization, involving_teammate_id: observer_tm.id)
      show_href = routes.organization_observation_path(organization, obs)
      expect(line).to include(" on ")
      anchors = Nokogiri::HTML::DocumentFragment.parse(line).css("a")
      expect(anchors[0]["href"]).to eq(involving_href)
      expect(anchors[1]["href"]).to eq(show_href)
      expect(line).to include("about:")
      expect(line).to include(routes.organization_assignment_path(organization, assignment))
      expect(line).to include(routes.organization_ability_path(organization, ability))
    end

    it "priority 7 when all WTM areas have observations shows summary with linked observations word and per-area observer links" do
      routes = Rails.application.routes.url_helpers
      hub_person = create(:person, first_name: "Casey", last_name: "Ng")
      hub_tm = create(:teammate, organization: organization, person: hub_person)
      observer_person = create(:person, first_name: "Dana", last_name: "Fox")
      create(:teammate, organization: organization, person: observer_person)
      one_on_one_link = create(:one_on_one_link, teammate: hub_tm, url: "https://example.com/hub")

      assignment = create(:assignment, company: organization, title: "Ship MVP")
      create(:assignment_check_in, :finalized, :working_to_meet, teammate: hub_tm, assignment: assignment)

      obs_a = create(
        :observation,
        observer: observer_person,
        company: organization,
        published_at: 2.days.ago,
        observed_at: 2.days.ago,
        privacy_level: :observed_only,
        story: "First note on WTM area."
      )
      obs_a.observees.destroy_all
      create(:observee, observation: obs_a, teammate: hub_tm)
      create(:observation_rating, observation: obs_a, rateable: assignment, rating: :agree)

      obs_b = create(
        :observation,
        observer: observer_person,
        company: organization,
        published_at: 1.day.ago,
        observed_at: 1.day.ago,
        privacy_level: :observed_only,
        story: "Second note on WTM area."
      )
      obs_b.observees.destroy_all
      create(:observee, observation: obs_b, teammate: hub_tm)
      create(:observation_rating, observation: obs_b, rateable: assignment, rating: :agree)

      result = described_class.call(
        organization: organization,
        teammate: hub_tm,
        one_on_one_link: one_on_one_link
      )
      p7 = result[:priorities].find { |p| p[:title].include?("working-to-meet assignments and aspirational values") }

      expect(p7[:needs_attention]).to eq(false)
      involving = routes.organization_observations_path(organization, involving_teammate_id: hub_tm.id)
      expect(p7[:reason_html].to_s).to include(involving)
      expect(p7[:reason_plain]).to eq("1 Working-to-meet assignment/aspiration area has 2 recent published observations.")
      expect(p7[:reason_html].to_s).to include("1 Working-to-meet assignment/aspiration area has 2 recent published")

      line = p7[:concrete_items].first[:label_html].to_s
      expect(line).to include(routes.organization_teammate_assignment_path(organization, hub_tm, assignment))
      anchors = Nokogiri::HTML::DocumentFragment.parse(line).css("a")
      obs_hrefs = anchors.map { |a| a["href"] }
      expect(obs_hrefs).to include(routes.organization_observation_path(organization, obs_a))
      expect(obs_hrefs).to include(routes.organization_observation_path(organization, obs_b))
    end

    it "priority 9 when teammate has active goals shows linked count in reason only, no bullet list" do
      routes = Rails.application.routes.url_helpers
      hub_tm = create(:teammate, organization: organization)
      one_on_one_link = create(:one_on_one_link, teammate: hub_tm, url: "https://example.com/hub")
      3.times do
        create(
          :goal,
          owner: hub_tm,
          creator: hub_tm,
          company_id: organization.id,
          started_at: 1.day.ago,
          completed_at: nil,
          deleted_at: nil
        )
      end

      result = described_class.call(
        organization: organization,
        teammate: hub_tm,
        one_on_one_link: one_on_one_link
      )
      p9 = result[:priorities][8]

      expect(p9[:title]).to include("at least one active goal")
      expect(p9[:needs_attention]).to eq(false)
      expect(p9[:reason]).to be_nil
      expect(p9[:concrete_items]).to eq([])
      expect(p9[:reason_plain]).to eq("There are 3 active goals in progress.")
      expect(p9[:reason_html].to_s).to include(routes.my_growth_goals_organization_company_teammate_path(organization, hub_tm))
      expect(p9[:reason_html].to_s).to include("3 active goals")
    end
  end
end
