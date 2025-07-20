require 'rails_helper'

RSpec.describe Person, type: :model do
  describe 'associations' do
    it { should have_many(:huddle_participants).dependent(:destroy) }
    it { should have_many(:huddles).through(:huddle_participants) }
    it { should have_many(:huddle_feedbacks).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:unique_textable_phone_number) }
    
    it 'validates email format' do
      person = Person.new(email: 'invalid-email')
      expect(person).not_to be_valid
      expect(person.errors[:email]).to include('is invalid')
    end

    it 'accepts valid email format' do
      person = Person.new(email: 'test@example.com')
      expect(person).to be_valid
    end
  end

  describe 'name parsing' do
    context 'with single name' do
      it 'sets first_name only' do
        person = Person.new(full_name: 'John', email: 'john@example.com')
        person.valid?
        
        expect(person.first_name).to eq('John')
        expect(person.middle_name).to be_nil
        expect(person.last_name).to be_nil
        expect(person.suffix).to be_nil
      end
    end

    context 'with two names' do
      it 'sets first_name and last_name' do
        person = Person.new(full_name: 'John Doe', email: 'john@example.com')
        person.valid?
        
        expect(person.first_name).to eq('John')
        expect(person.middle_name).to be_nil
        expect(person.last_name).to eq('Doe')
        expect(person.suffix).to be_nil
      end
    end

    context 'with three names' do
      it 'sets first_name, middle_name, and last_name' do
        person = Person.new(full_name: 'John A Doe', email: 'john@example.com')
        person.valid?
        
        expect(person.first_name).to eq('John')
        expect(person.middle_name).to eq('A')
        expect(person.last_name).to eq('Doe')
        expect(person.suffix).to be_nil
      end
    end

    context 'with four or more names' do
      it 'sets first_name, middle_name (combined), and last_name' do
        person = Person.new(full_name: 'John A B Doe', email: 'john@example.com')
        person.valid?
        
        expect(person.first_name).to eq('John')
        expect(person.middle_name).to eq('A B')
        expect(person.last_name).to eq('Doe')
        expect(person.suffix).to be_nil
      end

      it 'handles very long names' do
        person = Person.new(full_name: 'John A B C D E F Doe', email: 'john@example.com')
        person.valid?
        
        expect(person.first_name).to eq('John')
        expect(person.middle_name).to eq('A B C D E F')
        expect(person.last_name).to eq('Doe')
      end
    end

    context 'with existing suffix' do
      it 'preserves existing suffix when parsing full_name' do
        person = Person.new(suffix: 'Jr.', full_name: 'John A Doe', email: 'john@example.com')
        person.valid?
        
        expect(person.first_name).to eq('John')
        expect(person.middle_name).to eq('A')
        expect(person.last_name).to eq('Doe')
        expect(person.suffix).to eq('Jr.')
      end
    end

    context 'with whitespace' do
      it 'handles extra whitespace' do
        person = Person.new(full_name: '  John   A   Doe  ', email: 'john@example.com')
        person.valid?
        
        expect(person.first_name).to eq('John')
        expect(person.middle_name).to eq('A')
        expect(person.last_name).to eq('Doe')
      end
    end

    context 'with empty full_name' do
      it 'does not parse when full_name is empty' do
        person = Person.new(first_name: 'John', last_name: 'Doe', email: 'john@example.com')
        person.full_name = ''
        person.valid?
        
        expect(person.first_name).to eq('John')
        expect(person.last_name).to eq('Doe')
      end
    end
  end

  describe '#combined_name' do
    it 'combines name parts into full name' do
      person = Person.new(
        first_name: 'John',
        middle_name: 'A',
        last_name: 'Doe',
        suffix: 'Jr.'
      )
      
      expect(person.combined_name).to eq('John A Doe Jr.')
    end

    it 'handles missing parts gracefully' do
      person = Person.new(first_name: 'John', last_name: 'Doe')
      expect(person.combined_name).to eq('John Doe')
    end

    it 'returns empty string when no name parts' do
      person = Person.new
      expect(person.combined_name).to eq('')
    end
  end

  describe '#display_name' do
    it 'returns full name when available' do
      person = Person.new(
        first_name: 'John',
        last_name: 'Doe',
        email: 'john@example.com'
      )
      
      expect(person.display_name).to eq('John Doe')
    end

    it 'returns email when no name available' do
      person = Person.new(email: 'john@example.com')
      expect(person.display_name).to eq('john@example.com')
    end
  end

  describe 'factory' do
    it 'can be created with valid attributes' do
      person = Person.new(
        email: 'test@example.com',
        full_name: 'John Doe'
      )
      
      expect(person).to be_valid
    end
  end
end 