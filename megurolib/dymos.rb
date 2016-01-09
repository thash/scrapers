require File.expand_path('../../base.rb', __FILE__)

p Dymos
p Dymos::Client
p Dymos::Client.new(region: 'ap-northeast-1')

conf = YAML.load(open(File.expand_path('../../secret.yml', __FILE__)).read)

Aws.config.update({
  region: 'ap-northeast-1',
  credentials: Aws::Credentials.new(conf['meguro_lib']['aws_library_scraper_key'],
                                    conf['meguro_lib']['aws_library_scraper_secret'])
})

p Dymos::Client.new

class Book < Dymos::Model
  table 'books'
  field :isbn, :string
  field :title, :string
  field :author, :string
end

puts '--- ---'

Book.all.each do |book|
  puts "[#{book.isbn}] #{book.title} / #{book.author}"
end

# binding.pry
