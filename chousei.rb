#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require
require 'active_support/core_ext/date/calculations'
require 'optparse'

opts = ARGV.getopts('n:', 'offset:', 'base-date:')

Capybara.javascript_driver = :webkit
@page = Capybara::Session.new(:webkit)


def num(date, opts)
  return opts['n'].to_i if opts['n']
  offset = opts['offset'] ? opts['offset'].to_i : 29
  ((date.year - 2014) * 54) + date.cweek + offset
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

base_date = if opts['base-date']
              Date.parse(opts['base-date'])
            else
              Date.today.next_week.beginning_of_week
            end

@page.fill_in :name, with: "第#{num(base_date, opts)}回 Bio x IT輪読会"
@page.fill_in :kouho, with: kouho(base_date)
@page.find(:css, '#newEventForm input[type="submit"]').click
sleep 3

p @page.current_url # complete page

p @page.all(:css, '.honmon input:nth-child(1)').first.value
# => "https://chouseisan.com/schedule/List?h=4d06d87f127d4dae8fd2634764375720201409"

puts "第#{num(base_date, opts)}回 Bio x IT輪読会の出欠確認"
puts "（#{base_date.strftime('%m/%d')} - #{(base_date + 6).strftime('%m/%d')}週）"
