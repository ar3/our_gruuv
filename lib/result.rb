# lib/result.rb
Result = Data.define(:ok?, :value, :error) do
  def self.ok(value=nil) = new(true, value, nil)
  def self.err(error)    = new(false, nil, error)
end
