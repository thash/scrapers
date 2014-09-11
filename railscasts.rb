require 'bundler/setup'
Bundler.require

require 'yaml'
require 'capybara/poltergeist'
require 'open-uri'

class RailsCasts
  attr_reader :conf, :cookies_file, :page

  def initialize
    @conf = YAML.load(open('secret.yml').read)
    @cookies_file = 'cookies_railscasts.txt'
    Capybara.javascript_driver = :webkit
    @page = Capybara::Session.new(:webkit)
    load_cookies
    @page.visit 'http://railscasts.com/'
  end

  def load_cookies
    open(@cookies_file).each do |l|
      @page.driver.browser.set_cookie(l.chomp)
    end
  end

  def login
    @page.click_link 'Sign in through GitHub'

    @page.fill_in('login', with: @conf['github']['login'])
    @page.fill_in('password', with: @conf['github']['password'])
    @page.find(:css, '[name=commit]').click

    # Two-factor Verification.
    print "Verification Code: "; input = gets.strip
    @page.fill_in 'otp', with: input
    @page.click_button 'Verify'
    true
  end

  def save_cookies
    open(@cookies_file, 'w+') do |f|
      @page.driver.browser.get_cookies.each do |cookie|
        f.puts cookie
      end
    end
  end

  def scrape_names
    names = []
    loop do
    # 2.times do
      names += @page.driver.find_css('.episode .screenshot a')
                 .map{|a| a['href'].gsub(%r|/episodes/|, '') }
      begin
        @page.click_link 'Next Page >'
        sleep 2
      rescue => e
        puts e
        break
      end
    end
    return names
  end

  def save_movie_links(file)
    login && save_cookies if !@page.has_content?('Logged in')
    open(file, 'w+') do |f|
      scrape_names.each do |name|
        @page.visit "http://railscasts.com/episodes/#{name}?autoplay=true"
        doc = Nokogiri::XML(@page.source)
        f.puts doc.css('video source')[0]['src']
      end
    end
  end

  def download_movies(links_file, target)
    system "mkdir -p #{target}"
    open(links_file).each do |line|
      filename = line.chomp.gsub(%r|^.*/(\d+-[\w_-]+.mp4)$|) { $1 }
      if File.exist?("#{target}/#{filename}")
        puts "skip - #{filename}"
      else
        puts "downloading... - #{filename}"
        open("#{target}/#{filename}", 'wb') do |file|
          file << open(line.chomp).read
        end
      end
    end
  end
end

rc = RailsCasts.new
txt = 'movie_links.txt'
case ARGV[0]
when 'link'
  rc.save_movie_links(txt)
when 'down'
  rc.download_movies(txt, 'output')
end
