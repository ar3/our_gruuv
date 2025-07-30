# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Seed PositionMajorLevel data for Base 10x3 set
position_major_levels = [
  { description: "Associates / Early Career / Juniors", major_level: 1, set_name: "Base 10x3" },
  { description: "Mid Career", major_level: 2, set_name: "Base 10x3" },
  { description: "Senior / Quad", major_level: 3, set_name: "Base 10x3" },
  { description: "Staff / Lead / Manager", major_level: 4, set_name: "Base 10x3" },
  { description: "Sr. Staff / Sr. Lead / Sr. Manager", major_level: 5, set_name: "Base 10x3" },
  { description: "Principal / Director", major_level: 6, set_name: "Base 10x3" },
  { description: "Sr. Principal / Sr. Director", major_level: 7, set_name: "Base 10x3" },
  { description: "Vice President", major_level: 8, set_name: "Base 10x3" },
  { description: "SVP / President / CxO", major_level: 9, set_name: "Base 10x3" },
  { description: "CEO / Board", major_level: 10, set_name: "Base 10x3" }
]

position_major_levels.each do |level_data|
  PositionMajorLevel.find_or_create_by!(set_name: level_data[:set_name], major_level: level_data[:major_level]) do |level|
    level.description = level_data[:description]
  end
end

# Seed PositionLevel data for Base 10x3 set
position_levels = [
  { major_level: 1, level: "1.1", ideal_assignment_goal_types: "100% judged on Activities" },
  { major_level: 1, level: "1.2", ideal_assignment_goal_types: "100% judged on Activities" },
  { major_level: 1, level: "1.3", ideal_assignment_goal_types: "100% judged on Activities" },
  { major_level: 2, level: "2.1", ideal_assignment_goal_types: "70% Activities / 30% Individual Output" },
  { major_level: 2, level: "2.2", ideal_assignment_goal_types: "50% Activities / 50% IndividualOutput" },
  { major_level: 2, level: "2.3", ideal_assignment_goal_types: "30% Activities / 70% IndividualOutput" },
  { major_level: 3, level: "3.1", ideal_assignment_goal_types: "70% Individual Output\n30% Team Output & Launch Effectiveness Outcomes" },
  { major_level: 3, level: "3.2", ideal_assignment_goal_types: "50% Individual Output\n50% Team Output & Launch Effectiveness Outcomes" },
  { major_level: 3, level: "3.3", ideal_assignment_goal_types: "30% Individual Output\n70% Team Output & Launch Effectiveness Outcomes" },
  { major_level: 4, level: "4.1", ideal_assignment_goal_types: "70% Team Output & Launch Effectiveness Outcomes\n30% KIS & KPI Lagging Outcomes" },
  { major_level: 4, level: "4.2", ideal_assignment_goal_types: "50% Team Output & Launch Effectiveness Outcomes\n50% KIS & KPI Lagging Outcomes" },
  { major_level: 4, level: "4.3", ideal_assignment_goal_types: "30% Team Output & Launch Effectiveness Outcomes\n70% KIS & KPI Lagging Outcomes" },
  { major_level: 5, level: "5.1", ideal_assignment_goal_types: "70% KIS & KPI Lagging Outcomes \n30% Strategic Leading Outcomes" },
  { major_level: 5, level: "5.2", ideal_assignment_goal_types: "50% KIS & KPI Lagging Outcomes \n50% Strategic Leading Outcomes" },
  { major_level: 5, level: "5.3", ideal_assignment_goal_types: "30% KIS & KPI Lagging Outcomes \n70% Strategic Leading Outcomes" },
  { major_level: 6, level: "6.1", ideal_assignment_goal_types: "70% Strategic Leading Outcomes\n30% Strategic Lagging Outcomes" },
  { major_level: 6, level: "6.2", ideal_assignment_goal_types: "50% Strategic Leading Outcomes\n50% Strategic Lagging Outcomes" },
  { major_level: 6, level: "6.3", ideal_assignment_goal_types: "30% Strategic Leading Outcomes\n70% Strategic Lagging Outcomes" },
  { major_level: 7, level: "7.1", ideal_assignment_goal_types: "70% Strategic Lagging Outcomes\n30% Departmental Goal Impact" },
  { major_level: 7, level: "7.2", ideal_assignment_goal_types: "50% Strategic Lagging Outcomes\n50% Departmental Goal Impact" },
  { major_level: 7, level: "7.3", ideal_assignment_goal_types: "30% Strategic Lagging Outcomes\n70% Departmental Goal Impact" },
  { major_level: 8, level: "8.1", ideal_assignment_goal_types: "70% Departmental Goal Impact\n30% Company Goal Impact" },
  { major_level: 8, level: "8.2", ideal_assignment_goal_types: "50% Departmental Goal Impact\n50% Company Goal Impact" },
  { major_level: 8, level: "8.3", ideal_assignment_goal_types: "30% Departmental Goal Impact\n70% Company Goal Impact" },
  { major_level: 9, level: "9.1", ideal_assignment_goal_types: "70% Company Goal Impact / 30% Industry Impact" },
  { major_level: 9, level: "9.2", ideal_assignment_goal_types: "50% Company Goal Impact / 50% Industry Impact" },
  { major_level: 9, level: "9.3", ideal_assignment_goal_types: "30% Company Goal Impact / 70% Industry Impact" },
  { major_level: 10, level: "10.0", ideal_assignment_goal_types: "" }
]

position_levels.each do |level_data|
  # Find the corresponding PositionMajorLevel
  major_level = PositionMajorLevel.find_by!(set_name: "Base 10x3", major_level: level_data[:major_level])
  
  PositionLevel.find_or_create_by!(position_major_level: major_level, level: level_data[:level]) do |level|
    level.ideal_assignment_goal_types = level_data[:ideal_assignment_goal_types]
  end
end
