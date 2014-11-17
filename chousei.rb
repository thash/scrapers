require 'bundler/setup'
Bundler.require
require 'active_support/core_ext/date/calculations'

Capybara.javascript_driver = :webkit
@page = Capybara::Session.new(:webkit)

OFFSET = 33

def num(date)
  ((date.year - 2014) * 54) + date.cweek + OFFSET
end

def kouho(start_date)
  str = ""
  (start_date..start_date + 6).each do |date|
    wd = %w(日 月 火 水 木 金 土)[date.wday]
    if %w(土 日).include?(wd)
      str << date.strftime("%m月%d日(#{wd}) 10:00-\n")
      str << date.strftime("%m月%d日(#{wd}) 22:00-\n")
    else
      str << date.strftime("%m月%d日(#{wd}) 22:30-\n")
    end
  end
  str
end

@page.visit 'https://chouseisan.com/'

base_date = Date.today.next_week.beginning_of_week
@page.fill_in :name, with: "第#{num(base_date)}回 Bio x IT輪読会"
@page.fill_in :kouho, with: kouho(base_date)
@page.find(:css, '#createBtn').click

p @page.current_url # complete page

p @page.find(:css, 'input').value
# => "https://chouseisan.com/schedule/List?h=4d06d87f127d4dae8fd2634764375720201409"
