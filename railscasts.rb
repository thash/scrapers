require 'bundler/setup'
Bundler.require(:default, :railscasts)

require 'yaml'
require 'capybara/poltergeist'

use_cookie = false

@conf = YAML.load(open('secret.yml').read)
cookies_file = 'cookies_railscasts.txt'

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
    js_errors: false,
    phantomjs: Phantomjs.path,
  #  debug: true
  })
end
Capybara.javascript_driver = :poltergeist

@page = Capybara::Session.new(:poltergeist)

def parse_cookie(cookie_str)
  options = {}
  cookie_str.chomp.split(/; ?/).map{|str| str.split('=') }.each.with_index do |pair, i|
    value = if pair.size > 2
              pair[1..-1].join('=')
            else
              pair[1].nil? ? true : pair[1]
            end
    options[pair[0]] = value
  end
  return options
end

open(cookies_file).each do |l|
  # webkit: @page.driver.browser.set_cookie(l.chomp)
  @page.driver.browser.set_cookie(parse_cookie(l))
end if use_cookie

@page.visit 'http://railscasts.com/'
 puts @page.driver.cookies
# puts @page.has_content?('Logged in')

# binding.pry

def login_and_save_cookies
  @page.click_link 'Sign in through GitHub'

  puts @page.driver.cookies
  puts @conf

  @page.fill_in('login', with: @conf['github']['login'])
  @page.fill_in('password', with: @conf['github']['password'])
  @page.find(:css, '[name=commit]').click # Phangomjs crash here

  # Two-factor Verification.
  print "Verification Code: "; input = gets.strip
  @page.fill_in 'otp', with: input
  @page.click_button 'Verify'

  open(cookies_file, 'w+') do |f|
    # webkit code
    @page.driver.browser.get_cookies.each do |cookie|
      f.puts cookie
    end
  end
end

login_and_save_cookies if !@page.has_content?('Logged in')

names = []
#loop do
3.times do
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
