# frozen_string_literal: true

namespace :digest do
  desc 'Diagnose why 1:1 / About Me / GSD digests are not sending for a teammate (TEAMMATE_ID). Set TRY_SLACK=1 to test opening the Slack DM.'
  task :diagnose, [:teammate_id] => :environment do |_t, args|
    teammate_id = args[:teammate_id]
    abort 'Usage: rake digest:diagnose[TEAMMATE_ID]' if teammate_id.blank?

    teammate = CompanyTeammate.find_by(id: teammate_id)
    abort "No CompanyTeammate with id #{teammate_id}" unless teammate

    person = teammate.person
    organization = teammate.organization
    prefs = UserPreference.for_person(person)
    manager = teammate.active_employment_tenure&.manager_teammate
    manager_prefs = manager ? UserPreference.for_person(manager.person) : nil
    gsd_count = GetShitDoneQueryService.new(teammate: teammate).all_pending_items[:total_pending].to_i

    status = Digest::TeammateDigestStatusService.new(
      teammate: teammate,
      organization: organization,
      gsd_pending_count: gsd_count
    )

    puts '=' * 72
    puts "Digest diagnose: #{teammate} (person #{person.id}, org #{organization.id})"
    puts '=' * 72

    puts "\n## Employment"
    puts "  employed scope: #{teammate.employed?}"
    puts "  first_employed_at: #{teammate.first_employed_at.inspect}"
    puts "  last_terminated_at: #{teammate.last_terminated_at.inspect}"
    puts "  active tenure: #{teammate.active_employment_tenure.present?}"
    puts "  manager: #{manager&.person&.display_name || 'none'}"

    puts "\n## Person"
    puts "  timezone (stored): #{person.timezone.inspect}"
    puts "  timezone_or_default: #{person.timezone_or_default}"

    puts "\n## Employee preferences (stored)"
    %w[
      digest_slack about_me_weekly_day one_on_one_digest_enabled about_me_digest_enabled
      one_on_one_last_sent_week about_me_last_sent_week
    ].each do |key|
      stored = prefs.preferences[key]
      effective = prefs.preference(key)
      puts "  #{key}: stored=#{stored.inspect} effective=#{effective.inspect}"
    end

    if manager_prefs
      puts "\n## Manager preferences (#{manager.person.display_name})"
      puts "  digest_slack: #{manager_prefs.preference(:digest_slack).inspect}"
      puts "  slack identity: #{manager.has_slack_identity?} uid=#{manager.slack_user_id.inspect}"
    end

    puts "\n## Slack identities"
    puts "  employee slack: #{teammate.has_slack_identity?} uid=#{teammate.slack_user_id.inspect}"
    puts "  org slack configured: #{organization.calculated_slack_config&.configured?}"

    puts "\n## UI blockers (TeammateDigestStatusService)"
    puts "  1:1: #{status.one_on_one_blockers.presence || ['(none)']}"
    puts "  About Me: #{status.about_me_blockers.presence || ['(none)']}"
    puts "  GSD: #{status.gsd_blockers.presence || ['(none)']}"

    puts "\n## Scheduler simulation (Digest::ScheduleAboutMeJob rules)"
    status.schedule_diagnosis.each { |line| puts "  - #{line}" }

    tz = person.timezone.presence || 'UTC'
    local = Time.current.in_time_zone(tz)
    puts "\n  Local time now: #{local.strftime('%A %Y-%m-%d %H:%M %Z')}"
    puts "  Next 1:1 window: #{status.next_weekly_send_label(:one_on_one)}"

    puts "\n## Recent notifications (root, last 3 weeks)"
    events = status.recent_events(weeks: 3)
    if events.empty?
      puts '  (none)'
    else
      events.each do |e|
        puts "  #{e.sent_at.iso8601} #{e.label} #{e.status} #{e.medium}"
      end
    end

    puts "\n## Solid Queue (recent jobs for this teammate)"
    job_class_names = %w[Digest::SendOneOnOneDigestJob Digest::SendAboutMeJob Digest::SendDigestJob Digest::ScheduleAboutMeJob]
    recent_jobs = SolidQueue::Job
      .where(class_name: job_class_names)
      .where('created_at > ?', 2.weeks.ago)
      .order(created_at: :desc)
      .limit(30)
    matching = recent_jobs.select { |j| j.arguments.to_s.include?(teammate.id.to_s) }
    if matching.empty?
      puts '  (no matching jobs in last 2 weeks — scheduler may not be enqueueing)'
    else
      matching.first(10).each do |j|
        puts "  #{j.created_at.iso8601} #{j.class_name} finished_at=#{j.finished_at.inspect} args=#{j.arguments}"
      end
    end

    failed = SolidQueue::FailedExecution
      .joins(:job)
      .where(solid_queue_jobs: { class_name: 'Digest::SendOneOnOneDigestJob' })
      .where('solid_queue_jobs.created_at > ?', 2.weeks.ago)
      .order('solid_queue_jobs.created_at DESC')
      .limit(10)
    failed_matching = failed.select { |f| f.job.arguments.to_s.include?(teammate.id.to_s) }
    if failed_matching.any?
      puts "\n## Failed SendOneOnOneDigestJob executions"
      failed_matching.each do |f|
        puts "  #{f.job.created_at.iso8601} #{f.error}"
      end
    end

    if ENV['TRY_SLACK'] == '1'
      puts "\n## Slack channel dry run (TRY_SLACK=1)"
      job = Digest::SendOneOnOneDigestJob.new
      channel = job.send(:open_weekly_digest_slack_channel, teammate)
      if channel
        puts "  channel opened: #{channel[:digest_metadata][:channel]}"
      else
        puts '  channel open returned nil (same silent failure as send job — check Slack IDs and digest_slack prefs)'
      end
    else
      puts "\n## Slack channel dry run skipped (set TRY_SLACK=1 to test conversations.open)"
    end

    puts "\n## Manual test"
    puts "  rails runner \"Digest::SendOneOnOneDigestJob.perform_now(#{teammate.id})\""
    puts '  Then re-check Notification.where(notifiable_id: teammate.id, notification_type: \"one_on_one_digest\")'
    puts '=' * 72
  end
end
