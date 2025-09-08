namespace :maap do
  desc "Import MAAP data from amy_maap.md for demo purposes"
  task import: :environment do
    require_relative 'import_maap_data'
    
    puts "🚀 Starting MAAP Data Import via Rake Task..."
    puts "=" * 50
    
    MaapDataImporter.new.run
  end
end
