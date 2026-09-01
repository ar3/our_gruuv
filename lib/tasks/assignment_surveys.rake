# frozen_string_literal: true

namespace :assignment_surveys do
  desc "Backfill survey responses from check-in personal alignment (DRY_RUN=1 by default; DRY_RUN=0 to write)"
  task backfill_check_in_alignment: :environment do
    dry_run = ENV.fetch("DRY_RUN", "1") != "0"
    organization_id = ENV["ORGANIZATION_ID"].presence
    organization = organization_id ? Organization.find(organization_id) : nil

    result = AssignmentSurveys::CheckInAlignmentBackfill.call(
      dry_run: dry_run,
      organization: organization
    )

    puts "dry_run=#{result.dry_run} scanned=#{result.scanned} created=#{result.created} skipped=#{result.skipped} errors=#{result.errors.size}"
    result.errors.first(20).each do |error|
      puts "  check_in_id=#{error[:check_in_id]} #{error[:message]}"
    end
  end
end
