require 'bundler/setup'
Bundler.require

require 'yaml'
require 'capybara/poltergeist'

# Capybara.javascript_driver = :poltergeist
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
    js_errors: false,
    timeout:   1000
  })
end

def leaf?(node)
  node.css('.text').count == 0
end

def has_thread?(node)
  node.css('.thread-badge')
end

# TODO: putsしたものが重複しないように住んだものはリストに突っ込んでいく必要ありそう
def hoge(base, level=0)
  puts "---- #{level} ----"
  base.css('.text').each do |node|
    if leaf?(node)
      print "  " * level
      puts node.text
    else
      print "  " * level
      puts node.child.text
      hoge(node, level + 1)
    end
  end
end


conf = YAML.load(open('secret.yml').read)
@page = Capybara::Session.new(:poltergeist)

@page.visit 'https://www.co-meeting.com/en/'
sleep 5
@page.click_link 'Login'

@page.fill_in('user[email]', with: conf['co_meeting']['login'])
@page.fill_in('user[password]', with: conf['co_meeting']['password'])

@page.save_page

@page.find(:css, '#user_submit').click
sleep 5

@page.save_page

# expand all meetings
loop do
  begin
    @page.find('.more-meeting').click
    sleep 3
  rescue Capybara::ElementNotFound
    break
  end
end

meeting_links = @page.all('.meeting-item a').map{|a|
  @page.current_url.gsub(/#!.*$/,'') + a[:href]
}

l = meeting_links.sample(1).first
@page.visit l

sleep 5

p "url: #{@page.current_url}"
p "title: #{@page.find_by_id('meeting-name').text}"

doc = Nokogiri::XML(@page.html)
discussion = doc.at_css('.discussionPanel')
p discussion.css('[kind="b"]')
