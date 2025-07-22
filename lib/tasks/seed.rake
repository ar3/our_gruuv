namespace :seed do
  desc "Seed development data with different scenarios"
  task :scenarios => :environment do
    puts "Available scenarios:"
    puts "  rake seed:scenario[basic]     - 3 orgs, 3 teams each, mixed participation"
    puts "  rake seed:scenario[full]      - Full participation across all huddles"
    puts "  rake seed:scenario[low]       - Low participation across all huddles"
    puts "  rake seed:scenario[clean]     - Clean slate (delete all data first)"
  end

  desc "Seed a specific scenario"
  task :scenario, [:scenario_name] => :environment do |t, args|
    scenario = args[:scenario_name] || 'basic'
    
    case scenario
    when 'clean'
      clean_all_data
      puts "✅ All data cleaned"
    when 'basic'
      clean_all_data
      seed_basic_scenario
      puts "✅ Basic scenario seeded"
    when 'full'
      clean_all_data
      seed_full_participation_scenario
      puts "✅ Full participation scenario seeded"
    when 'low'
      clean_all_data
      seed_low_participation_scenario
      puts "✅ Low participation scenario seeded"
    else
      puts "❌ Unknown scenario: #{scenario}"
      puts "Run 'rake seed:scenarios' to see available options"
    end
  end

  private

  def clean_all_data
    puts "🧹 Cleaning all data..."
    HuddleFeedback.delete_all
    HuddleParticipant.delete_all
    Huddle.delete_all
    Person.delete_all
    Team.delete_all
    Organization.delete_all
  end

  def seed_basic_scenario
    puts "🌱 Seeding basic scenario..."
    
    # Create 3 organizations
    orgs = create_organizations(3)
    
    orgs.each_with_index do |org, org_index|
      # Create 3 teams per organization
      teams = create_teams(org, 3)
      
      teams.each_with_index do |team, team_index|
        # Create participants for this team
        participants = create_team_participants(team, rand(5..8))
        
        # First team gets 2 open huddles (one with alias, one without)
        if team_index == 0
          # Huddle with alias
          huddle_with_alias = create_huddle(team, participants.sample(rand(3..6)), true)
          # Huddle without alias
          huddle_without_alias = create_huddle(team, participants.sample(rand(3..6)), false)
          
          # Add some feedback with mixed participation
          add_mixed_feedback(huddle_with_alias, participants)
          add_mixed_feedback(huddle_without_alias, participants)
        else
          # Other teams get 1 huddle each
          huddle = create_huddle(team, participants.sample(rand(3..6)), [true, false].sample)
          add_mixed_feedback(huddle, participants)
        end
      end
      
      # Add guaranteed scenarios for the first organization
      if org_index == 0
        add_guaranteed_scenarios(org, teams.first)
      end
    end
  end

  def seed_full_participation_scenario
    puts "🌱 Seeding full participation scenario..."
    
    orgs = create_organizations(3)
    
    orgs.each_with_index do |org, org_index|
      teams = create_teams(org, 3)
      
      teams.each_with_index do |team, team_index|
        participants = create_team_participants(team, rand(5..8))
        
        if team_index == 0
          huddle_with_alias = create_huddle(team, participants.sample(rand(3..6)), true)
          huddle_without_alias = create_huddle(team, participants.sample(rand(3..6)), false)
          
          add_full_feedback(huddle_with_alias, participants)
          add_full_feedback(huddle_without_alias, participants)
        else
          huddle = create_huddle(team, participants.sample(rand(3..6)), [true, false].sample)
          add_full_feedback(huddle, participants)
        end
      end
      
      # Add guaranteed scenarios for the first organization
      if org_index == 0
        add_guaranteed_scenarios(org, teams.first)
      end
    end
  end

  def seed_low_participation_scenario
    puts "🌱 Seeding low participation scenario..."
    
    orgs = create_organizations(3)
    
    orgs.each_with_index do |org, org_index|
      teams = create_teams(org, 3)
      
      teams.each_with_index do |team, team_index|
        participants = create_team_participants(team, rand(5..8))
        
        if team_index == 0
          huddle_with_alias = create_huddle(team, participants.sample(rand(3..6)), true)
          huddle_without_alias = create_huddle(team, participants.sample(rand(3..6)), false)
          
          add_low_feedback(huddle_with_alias, participants)
          add_low_feedback(huddle_without_alias, participants)
        else
          huddle = create_huddle(team, participants.sample(rand(3..6)), [true, false].sample)
          add_low_feedback(huddle, participants)
        end
      end
      
      # Add guaranteed scenarios for the first organization
      if org_index == 0
        add_guaranteed_scenarios(org, teams.first)
      end
    end
  end

  def create_organizations(count)
    org_names = ['Konoha Industries', 'S.H.I.E.L.D. Enterprises', 'Starfleet Command']
    organizations = []
    
    count.times do |i|
      org = Company.create!(
        name: org_names[i]
      )
      organizations << org
      puts "  📊 Created organization: #{org.display_name}"
    end
    
    organizations
  end

  def create_teams(organization, count)
    team_names = ['Ninja Squad', 'Avengers Initiative', 'Starship Crew', 'Jedi Order', 'Vulcan Science', 'Wakanda Tech']
    teams = []
    
    count.times do |i|
      team = Team.create!(
        parent: organization,
        name: team_names[i]
      )
      teams << team
      puts "    👥 Created team: #{team.display_name}"
    end
    
    teams
  end

  def create_team_participants(team, count)
    # Fun names from popular franchises
    first_names = [
      # Naruto
      'Naruto', 'Sasuke', 'Sakura', 'Kakashi', 'Itachi', 'Hinata', 'Shikamaru', 'Ino', 'Choji', 'Neji',
      # Star Wars
      'Luke', 'Leia', 'Han', 'Chewbacca', 'Obi-Wan', 'Anakin', 'Padme', 'Mace', 'Qui-Gon', 'Yoda',
      # Star Trek
      'James', 'Spock', 'Leonard', 'Montgomery', 'Nyota', 'Pavel', 'Hikaru', 'Jean-Luc', 'William', 'Deanna',
      # Marvel
      'Tony', 'Steve', 'Natasha', 'Bruce', 'Thor', 'Clint', 'Peter', 'Wanda', 'Vision', 'Sam',
      'Scott', 'Hope', 'T\'Challa', 'Shuri', 'Stephen', 'Carol', 'Gamora', 'Rocket', 'Groot', 'Drax'
    ]
    
    last_names = [
      # Naruto
      'Uzumaki', 'Uchiha', 'Haruno', 'Hatake', 'Hyuga', 'Nara', 'Yamanaka', 'Akimichi', 'Aburame', 'Inuzuka',
      # Star Wars
      'Skywalker', 'Solo', 'Organa', 'Kenobi', 'Windu', 'Jinn', 'Fett', 'Calrissian', 'Ackbar', 'Tarkin',
      # Star Trek
      'Kirk', 'McCoy', 'Scott', 'Uhura', 'Chekov', 'Sulu', 'Picard', 'Riker', 'Troi', 'Crusher',
      # Marvel
      'Stark', 'Rogers', 'Romanoff', 'Banner', 'Odinson', 'Barton', 'Parker', 'Maximoff', 'Wilson', 'Lang',
      'Van Dyne', 'Pym', 'Strange', 'Danvers', 'T\'Challa', 'Shuri', 'Quill', 'Gamora', 'Drax', 'Mantis'
    ]
    
    participants = []
    count.times do |i|
      person = Person.create!(
        first_name: first_names[i % first_names.length],
        last_name: last_names[i % last_names.length],
        email: "#{first_names[i % first_names.length].downcase}.#{last_names[i % last_names.length].downcase}@#{team.parent.name.downcase.gsub(/\s+/, '')}.com",
        timezone: ActiveSupport::TimeZone.all.map(&:name).sample
      )
      participants << person
    end
    
    participants
  end

  def create_huddle(team, participants, use_alias = false)
    started_at = rand(24).hours.ago
    huddle = Huddle.create!(
      organization: team,
      started_at: started_at,
      expires_at: started_at + 24.hours,
      huddle_alias: use_alias ? generate_alias : nil
    )
    
    # Assign roles with proper distribution
    # 1-2 facilitators, mostly active participants, few others
    roles = assign_roles(participants.length)
    
    participants.each_with_index do |participant, index|
      HuddleParticipant.create!(
        huddle: huddle,
        person: participant,
        role: roles[index]
      )
    end
    
    puts "      🎯 Created huddle: #{huddle.display_name_without_organization} (#{participants.length} participants)"
    huddle
  end

  def assign_roles(participant_count)
    roles = []
    
    # Always have 1-2 facilitators
    facilitator_count = participant_count >= 6 ? 2 : 1
    roles.concat(['facilitator'] * facilitator_count)
    
    # Most others are active participants
    active_count = participant_count - facilitator_count - 1 # Leave room for 1 other role
    roles.concat(['active'] * active_count)
    
    # Add one other role if we have space
    if roles.length < participant_count
      other_roles = ['observer', 'note_taker', 'time_keeper']
      roles << other_roles.sample
    end
    
    # Shuffle the roles to make it more realistic
    roles.shuffle
  end

  def generate_alias
    # Thematic aliases based on franchises
    themes = [
      # Naruto themes
      ['shadow', 'clone', 'rasengan', 'chidori', 'kage', 'bunshin', 'jutsu', 'ninja'],
      # Star Wars themes  
      ['force', 'lightsaber', 'jedi', 'sith', 'rebel', 'empire', 'deathstar', 'falcon'],
      # Star Trek themes
      ['phaser', 'warp', 'transporter', 'holodeck', 'borg', 'klingon', 'vulcan', 'enterprise'],
      # Marvel themes
      ['shield', 'avenger', 'infinity', 'gauntlet', 'snap', 'hero', 'villian', 'suit']
    ]
    
    theme = themes.sample
    "#{theme.sample}-#{theme.sample}"
  end

  def add_mixed_feedback(huddle, participants)
    # Get actual huddle participants
    huddle_participants = huddle.huddle_participants.includes(:person)
    total_participants = huddle_participants.count
    
    # Determine participation pattern based on percentages
    participation_roll = rand(100)
    
    if participation_roll < 33
      # 33% chance: Everyone gives feedback
      feedback_participants = huddle_participants
      puts "        📝 Added feedback from #{total_participants}/#{total_participants} participants (100% - full participation)"
    elsif participation_roll < 43
      # 10% chance: No one gives feedback
      feedback_participants = []
      puts "        📝 Added feedback from 0/#{total_participants} participants (0% - no participation)"
    else
      # 57% chance: Random participation rate
      participation_rate = rand(0.1..0.9) # 10% to 90% participation
      feedback_count = (total_participants * participation_rate).round
      feedback_count = [feedback_count, 1].max # At least 1 participant if any
      feedback_participants = huddle_participants.sample(feedback_count)
      puts "        📝 Added feedback from #{feedback_participants.length}/#{total_participants} participants (#{(participation_rate * 100).round}% - mixed participation)"
    end
    
    feedback_participants.each do |huddle_participant|
      create_feedback(huddle, huddle_participant.person)
    end
  end

  def add_full_feedback(huddle, participants)
    # Get actual huddle participants
    huddle_participants = huddle.huddle_participants.includes(:person)
    total_participants = huddle_participants.count
    
    # Use realistic participation patterns even for "full" scenario
    # but with a bias toward higher participation rates
    participation_roll = rand(100)
    
    if participation_roll < 50
      # 50% chance: Everyone gives feedback (higher than mixed scenario)
      feedback_participants = huddle_participants
      puts "        📝 Added feedback from #{total_participants}/#{total_participants} participants (100% - full participation)"
    elsif participation_roll < 60
      # 10% chance: No one gives feedback
      feedback_participants = []
      puts "        📝 Added feedback from 0/#{total_participants} participants (0% - no participation)"
    else
      # 40% chance: Random participation rate (biased toward higher rates)
      participation_rate = rand(0.3..0.95) # 30% to 95% participation
      feedback_count = (total_participants * participation_rate).round
      feedback_count = [feedback_count, 1].max # At least 1 participant if any
      feedback_participants = huddle_participants.sample(feedback_count)
      puts "        📝 Added feedback from #{feedback_participants.length}/#{total_participants} participants (#{(participation_rate * 100).round}% - mixed participation)"
    end
    
    feedback_participants.each do |huddle_participant|
      create_feedback(huddle, huddle_participant.person)
    end
  end

  def add_low_feedback(huddle, participants)
    # Get actual huddle participants
    huddle_participants = huddle.huddle_participants.includes(:person)
    total_participants = huddle_participants.count
    
    # Determine participation pattern based on percentages
    participation_roll = rand(100)
    
    if participation_roll < 33
      # 33% chance: Everyone gives feedback
      feedback_participants = huddle_participants
      puts "        📝 Added feedback from #{total_participants}/#{total_participants} participants (100% - full participation)"
    elsif participation_roll < 43
      # 10% chance: No one gives feedback
      feedback_participants = []
      puts "        📝 Added feedback from 0/#{total_participants} participants (0% - no participation)"
    else
      # 57% chance: Random participation rate (biased toward lower rates)
      participation_rate = rand(0.05..0.6) # 5% to 60% participation
      feedback_count = (total_participants * participation_rate).round
      feedback_count = [feedback_count, 1].max # At least 1 participant if any
      feedback_participants = huddle_participants.sample(feedback_count)
      puts "        📝 Added feedback from #{feedback_participants.length}/#{total_participants} participants (#{(participation_rate * 100).round}% - low participation)"
    end
    
    feedback_participants.each do |huddle_participant|
      create_feedback(huddle, huddle_participant.person)
    end
  end

  def add_guaranteed_scenarios(organization, team)
    puts "      🎯 Adding guaranteed scenarios..."
    
    # Create new participants for the guaranteed scenarios
    participants = create_team_participants(team, 6)
    
    # 1. Perfect huddle - full participation with perfect scores
    perfect_huddle = create_huddle(team, participants.sample(5), true)
    add_perfect_feedback(perfect_huddle, participants)
    puts "        🌟 Created perfect huddle: #{perfect_huddle.display_name_without_organization}"
    
    # 2. No feedback huddle - multiple participants but no feedback
    no_feedback_huddle = create_huddle(team, participants.sample(6), true)
    puts "        🤐 Created no-feedback huddle: #{no_feedback_huddle.display_name_without_organization}"
    
    # 3. Disaster huddle - everyone gives feedback but all low ratings
    disaster_huddle = create_huddle(team, participants.sample(5), true)
    add_disaster_feedback(disaster_huddle, participants)
    puts "        💥 Created disaster huddle: #{disaster_huddle.display_name_without_organization}"
  end

  def add_perfect_feedback(huddle, participants)
    # Get actual huddle participants
    huddle_participants = huddle.huddle_participants.includes(:person)
    
    huddle_participants.each do |huddle_participant|
      HuddleFeedback.create!(
        huddle: huddle,
        person: huddle_participant.person,
        informed_rating: 5,
        connected_rating: 5,
        goals_rating: 5,
        valuable_rating: 5,
        personal_conflict_style: 'Collaborative',
        team_conflict_style: 'Collaborative',
        appreciation: "This was absolutely perfect! Our team synergy was off the charts!",
        change_suggestion: nil,
        private_department_head: nil,
        private_facilitator: nil
      )
    end
  end

  def add_disaster_feedback(huddle, participants)
    # Get actual huddle participants
    huddle_participants = huddle.huddle_participants.includes(:person)
    
    huddle_participants.each do |huddle_participant|
      HuddleFeedback.create!(
        huddle: huddle,
        person: huddle_participant.person,
        informed_rating: rand(1..3),
        connected_rating: rand(1..3),
        goals_rating: rand(1..3),
        valuable_rating: rand(1..3),
        personal_conflict_style: 'Avoiding',
        team_conflict_style: 'Competing',
        appreciation: nil,
        change_suggestion: "This was a complete waste of time. We need to completely restructure our approach.",
        private_department_head: "Team morale is at an all-time low. Immediate intervention needed.",
        private_facilitator: "I don't know how to fix this. The team is completely disengaged."
      )
    end
  end

  def create_feedback(huddle, participant)
    # Thematic feedback based on franchises
    appreciations = [
      "Great teamwork and coordination like a well-trained ninja squad!",
      "The force was strong with our collaboration today.",
      "Live long and prosper - excellent team dynamics!",
      "We assembled like true Avengers - unstoppable together!",
      "Perfect synchronization, like a well-oiled starship crew.",
      "Our communication was as clear as a Jedi mind link."
    ]
    
    suggestions = [
      "Could use more shadow clone techniques for parallel work.",
      "Need to channel the force more effectively in future sessions.",
      "Consider implementing more logical Vulcan approaches.",
      "Should deploy more advanced tech like Wakanda's finest.",
      "Could benefit from more strategic planning like a S.H.I.E.L.D. operation.",
      "Need to harness our powers more efficiently."
    ]
    
    private_notes = [
      "Some team members need to work on their chakra control.",
      "The dark side is strong with certain team dynamics.",
      "Emotional responses need more Vulcan discipline.",
      "Some heroes need to work on their solo missions.",
      "Team cohesion could use some Starfleet training.",
      "Certain members need to embrace their inner ninja."
    ]
    
    HuddleFeedback.create!(
      huddle: huddle,
      person: participant,
      informed_rating: rand(3..5),
      connected_rating: rand(3..5),
      goals_rating: rand(3..5),
      valuable_rating: rand(3..5),
      personal_conflict_style: HuddleConstants::CONFLICT_STYLES.sample,
      team_conflict_style: HuddleConstants::CONFLICT_STYLES.sample,
      appreciation: rand > 0.3 ? appreciations.sample : nil,
      change_suggestion: rand > 0.5 ? suggestions.sample : nil,
      private_department_head: rand > 0.7 ? private_notes.sample : nil,
      private_facilitator: rand > 0.8 ? private_notes.sample : nil
    )
  end
end 