# frozen_string_literal: true

class Organizations::ClarityDocumentsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_document, only: %i[show edit update destroy unlink_assignment]
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    authorize Document
    @documents = policy_scope(Document).for_organization(@organization).ordered.includes(:owner, :blocks)
    @can_create = DocumentPolicy.new(pundit_user, Document.new(organization: @organization)).create?
  end

  def show
    authorize @document
    @blocks = @document.blocks.to_a
    @linked_assignments = @document.linked_assignments.ordered.includes(:department)
    @can_edit = policy(@document).update?
    @can_manage_assignment_links = policy(@document).manage_assignment_links?
  end

  def new
    @document = Document.new(
      organization: @organization,
      kind: "how_to",
      owner: current_company_teammate,
      owner_type: "CompanyTeammate",
      owner_id: current_company_teammate.id
    )
    authorize @document
    prefill_from_assignment
    @document.kind = "playbook" if @prefill_assignment
    load_form_collections
  end

  def create
    @document = Document.new(organization: @organization)
    assign_document_attributes(@document)
    apply_create_assignment_link(@document)
    ensure_creator_owner_unless_admin!(@document)
    authorize @document

    if @document.save
      redirect_after_create(@document)
    else
      prefill_from_assignment
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @document
    @document.body = @document.primary_text_block&.content
    load_form_collections
  end

  def update
    authorize @document
    assign_document_attributes(@document)
    ensure_creator_owner_unless_admin!(@document) unless clarity_library_admin?

    if @document.save
      redirect_to organization_clarity_document_path(@organization, @document),
                  notice: "Document updated."
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @document
    @document.destroy!
    redirect_to organization_clarity_documents_path(@organization),
                notice: "Document removed from the OG Clarity Library."
  end

  def unlink_assignment
    authorize @document, :manage_assignment_links?
    assignment = @organization.assignments.find(params[:assignment_id])
    @document.document_links.where(linkable: assignment).destroy_all
    redirect_to organization_clarity_document_path(@organization, @document),
                notice: "Removed link to #{assignment.title}."
  end

  private

  def set_document
    @document = Document.for_organization(@organization).find(params[:id])
  end

  def document_params
    params.require(:document).permit(
      :title,
      :kind,
      :body,
      :owner_key
    )
  end

  def assign_document_attributes(document)
    permitted = document_params
    document.title = permitted[:title]
    document.kind = permitted[:kind]
    document.body = permitted[:body] if permitted.key?(:body)
    document.assign_owner_from_key!(permitted[:owner_key]) if permitted[:owner_key].present?
  end

  def ensure_creator_owner_unless_admin!(document)
    return if clarity_library_admin?

    # Non-admins may own as themselves or as a Team they belong to — never another teammate.
    forced_to_self = false

    if document.owner_type == "CompanyTeammate" && document.owner_id != current_company_teammate.id
      forced_to_self = true
    elsif document.owner_type == "Team"
      team = @organization.teams.find_by(id: document.owner_id)
      forced_to_self = !team&.company_teammates&.exists?(id: current_company_teammate.id)
    elsif document.owner_type.in?(%w[Department Organization])
      forced_to_self = true
    end

    return unless forced_to_self

    document.assign_owner_from_key!("CompanyTeammate_#{current_company_teammate.id}")
    document.owner = current_company_teammate
  end

  def clarity_library_admin?
    current_company_teammate&.can_manage_clarity_library?
  end

  def prefill_from_assignment
    assignment = assignment_from_param
    return unless assignment

    @prefill_assignment = assignment
  end

  def apply_create_assignment_link(document)
    assignment = assignment_from_param
    return unless assignment

    @prefill_assignment = assignment
    document.assignment_ids_to_link = [assignment.id]
  end

  def redirect_after_create(document)
    assignment = @prefill_assignment || assignment_from_param
    if assignment
      redirect_to organization_assignment_path(@organization, assignment),
                  notice: "Document added to #{assignment.title}."
    else
      redirect_to organization_clarity_document_path(@organization, document),
                  notice: "Document created in the OG Clarity Library."
    end
  end

  def assignment_from_param
    assignment_id = params[:assignment_id].presence
    return if assignment_id.blank?

    @organization.assignments.find_by(id: assignment_id)
  end

  def load_form_collections
    @owner_options = clarity_document_owner_options
    @clarity_library_admin = clarity_library_admin?
  end

  def clarity_document_owner_options
    if clarity_library_admin?
      admin_owner_options
    else
      author_owner_options
    end
  end

  def author_owner_options
    me_label = current_company_teammate.person&.display_name.presence ||
               current_company_teammate.person&.full_name.presence ||
               "Me"
    grouped = [
      ["Me", [[me_label, "CompanyTeammate_#{current_company_teammate.id}"]]]
    ]

    my_teams = current_company_teammate.teams.merge(Team.for_company(@organization).active).includes(:department)
    grouped.concat(teams_owner_optgroups(my_teams, prefix: "My teams"))
    grouped
  end

  def admin_owner_options
    company_options = [["Everyone in #{@organization.display_name}", "Organization_#{@organization.id}"]]

    department_options = @organization.departments.order(:name).map do |department|
      [department.display_name, "Department_#{department.id}"]
    end

    teammate_options = @organization.company_teammates.includes(:person).map do |teammate|
      name = teammate.person&.display_name.presence || teammate.person&.full_name.presence || "Teammate ##{teammate.id}"
      [name, "CompanyTeammate_#{teammate.id}", name.to_s.downcase]
    end.sort_by { |(_, _, sort_key)| sort_key }.map { |label, value, _| [label, value] }

    grouped = []
    grouped << ["Company", company_options]
    grouped << ["Departments", department_options] if department_options.any?
    grouped.concat(teams_owner_optgroups(@organization.teams.active.includes(:department)))
    grouped << ["Teammates", teammate_options] if teammate_options.any?
    grouped
  end

  # Company-wide teams first, then departments A-Z; teams A-Z within each group.
  def teams_owner_optgroups(teams, prefix: "Teams")
    teams_by_department = Array(teams).group_by(&:department)
    ordered_departments = teams_by_department.keys.sort_by { |dept| dept ? [1, dept.display_name.to_s.downcase] : [0, ""] }

    ordered_departments.filter_map do |department|
      department_teams = teams_by_department[department]
                          .sort_by { |team| team.display_name.to_s.downcase }
      next if department_teams.empty?

      group_label =
        if department
          "#{prefix} · #{department.display_name}"
        else
          "#{prefix} · Company-wide"
        end

      [group_label, department_teams.map { |team| [team.display_name, "Team_#{team.id}"] }]
    end
  end
end
