# ENM Specs

This directory contains all specs for the ENM (Ethical Non-Monogamy) Alignment Typology application.

## Directory Structure

```
spec/enm/
├── controllers/     # Controller specs
├── forms/          # Form object specs  
├── services/       # Service object specs
├── system/         # System/integration specs
└── spec_helper.rb  # ENM-specific RSpec configuration
```

## Running ENM Specs

### Option 1: Using Rake Tasks

```bash
# Run all ENM specs
bundle exec rake spec:enm:all

# Run specific categories
bundle exec rake spec:enm:controllers
bundle exec rake spec:enm:forms
bundle exec rake spec:enm:services
bundle exec rake spec:enm:system
```

### Option 2: Using RSpec Directly

```bash
# Run all ENM specs
bundle exec rspec spec/enm/

# Run specific directories
bundle exec rspec spec/enm/controllers/
bundle exec rspec spec/enm/forms/
bundle exec rspec spec/enm/services/
bundle exec rspec spec/enm/system/
```

### Option 3: Using the ENM Specs Script

```bash
# Run all ENM specs
./bin/enm-specs
```

### Option 4: Using ENM Tag

```bash
# Run specs tagged with :enm
bundle exec rspec --tag enm
```

## Notes

- ENM specs are completely isolated from the main application specs
- They can be run independently without affecting other test suites
- All ENM specs are automatically tagged with `:enm` for easy filtering
- The ENM specs use their own spec_helper.rb for any specific configuration needs

