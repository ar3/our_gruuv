module BulkDownloadsHelper
  def download_type_display_name(type)
    case type
    when 'company_teammates'
      'Company Teammates'
    when 'assignments'
      'Assignments'
    when 'abilities'
      'Abilities'
    when 'positions'
      'Positions'
    when 'seats'
      'Seats'
    when 'titles'
      'Titles'
    when 'departments_and_teams'
      'Departments and Teams'
    else
      type.humanize
    end
  end

  def can_download_new?(download_type)
    case download_type
    when 'company_teammates'
      policy(current_organization).download_company_teammates_csv?
    else
      policy(current_organization).download_bulk_csv?
    end
  end
end
