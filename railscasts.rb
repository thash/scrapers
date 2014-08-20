require 'bundler/setup'
Bundler.require(:default, :railscasts)

require 'yaml'
require 'capybara/poltergeist'

@conf = YAML.load(open('secret.yml').read)
cookies_file = 'cookies_railscasts.txt'

Capybara.javascript_driver = :webkit
@page = Capybara::Session.new(:webkit)

open(cookies_file).each do |l|
  @page.driver.browser.set_cookie(l.chomp)
end

@page.visit 'http://railscasts.com/'

def login_and_save_cookies
  @page.click_link 'Sign in through GitHub'

  @page.fill_in('login', with: @conf['github']['login'])
  @page.fill_in('password', with: @conf['github']['password'])
  @page.find(:css, '[name=commit]').click

  # Two-factor Verification.
  print "Verification Code: "; input = gets.strip
  @page.fill_in 'otp', with: input
  @page.click_button 'Verify'

  open(cookies_file, 'w+') do |f|
    @page.driver.browser.get_cookies.each do |cookie|
      f.puts cookie
    end
  end
end

login_and_save_cookies if !@page.has_content?('Logged in')

names = []
# loop do
5.times do
  names += @page.driver.find_css('.episode .screenshot a').map{|a| a['href'].gsub(%r|/episodes/|, '') }
  begin
    @page.click_link 'Next Page >'
  rescue => e
    puts e
    break
  end
end

open('movie_links.txt', 'w+') do |f|
  names.each do |name|
    f.puts "http://media.railscasts.com/assets/episodes/videos/#{name}.mp4"
  end
end

# binding.pry
