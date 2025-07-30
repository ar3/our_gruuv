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
