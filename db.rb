require 'data_mapper'

DataMapper.setup(:default, ENV['DATABASE_URL'])

class DB
  include DataMapper::Resource

  property :name, String, length: 255, key: true
  property :value, Text

  def self.method_missing(method, *args)
    attribute = method.to_s
    if attribute =~ /=\z/
      column = attribute[0, attribute.size - 1]
      o = self.first_or_new(name: column)
      o.value = args.first.to_s
      o.save
    else
      self.first_or_new(name: attribute).value
    end
  end
end

DataMapper.auto_upgrade!
