# lib/tasks/enm_specs.rake
# Rake tasks for running ENM-specific specs

namespace :spec do
  namespace :enm do
    desc "Run all ENM specs"
    task :all => :environment do
      RSpec::Core::RakeTask.new(:enm_all) do |t|
        t.pattern = "spec/enm/**/*_spec.rb"
        t.rspec_opts = "--format progress"
      end
      Rake::Task[:enm_all].invoke
    end

    desc "Run ENM controller specs"
    task :controllers => :environment do
      RSpec::Core::RakeTask.new(:enm_controllers) do |t|
        t.pattern = "spec/enm/controllers/**/*_spec.rb"
        t.rspec_opts = "--format progress"
      end
      Rake::Task[:enm_controllers].invoke
    end

    desc "Run ENM form specs"
    task :forms => :environment do
      RSpec::Core::RakeTask.new(:enm_forms) do |t|
        t.pattern = "spec/enm/forms/**/*_spec.rb"
        t.rspec_opts = "--format progress"
      end
      Rake::Task[:enm_forms].invoke
    end

    desc "Run ENM service specs"
    task :services => :environment do
      RSpec::Core::RakeTask.new(:enm_services) do |t|
        t.pattern = "spec/enm/services/**/*_spec.rb"
        t.rspec_opts = "--format progress"
      end
      Rake::Task[:enm_services].invoke
    end

    desc "Run ENM system specs"
    task :system => :environment do
      RSpec::Core::RakeTask.new(:enm_system) do |t|
        t.pattern = "spec/enm/system/**/*_spec.rb"
        t.rspec_opts = "--format progress"
      end
      Rake::Task[:enm_system].invoke
    end
  end
end
