# frozen_string_literal: true

module Organizations
  class ExternalPeopleController < Organizations::OrganizationNamespaceBaseController
    before_action :authenticate_person!
    after_action :verify_authorized

    def show
      @person = Person.find(params[:id])

      if (teammate = active_teammate_in_org_or_company(@person))
        skip_authorization
        redirect_to organization_company_teammate_path(organization, teammate),
                    notice: "#{@person.casual_name} is a teammate — opened their teammate profile."
        return
      end

      authorize @person, policy_class: ExternalPersonPolicy

      visibility = ObservationVisibilityQuery.new(current_person, company)
      @observations = visibility.visible_observations
        .where(observer_id: @person.id)
        .published
        .where(deleted_at: nil)
        .includes(:observer, { observed_teammates: :person }, :observation_ratings)
        .order(Arel.sql('COALESCE(published_at, observed_at) DESC'))
        .limit(100)
    end

    private

    def active_teammate_in_org_or_company(person)
      person.active_teammates.find_by(organization_id: [organization.id, company.id].uniq)
    end
  end
end
