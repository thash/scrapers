require 'bundler/setup'
Bundler.require
require 'twitter'

namespace :megurolib do

  def mlib
    require File.expand_path('../megurolib.rb', __FILE__)
    @mlib ||= MeguroLib.new
  end

  def twitter_conf
    @conf ||= YAML.load(open('secret.yml').read)['twitter']
  end

  def twitter
    @client ||= Twitter::REST::Client.new do |c|
      c.consumer_key        = twitter_conf['consumer_key']
      c.consumer_secret     = twitter_conf['consumer_secret']
      c.access_token        = twitter_conf['access_token']
      c.access_token_secret = twitter_conf['access_token_secret']
    end
  end

  task :borrowing do
    borrowing_books = mlib.borrowing
    approaching_books = borrowing_books.select{|book| Time.now.since(3.days) >= book.due }
    if approaching_books.present?
      msg = "@T_Hash "
      msg += "『#{approaching_books.first.title}』"
      msg += "など, #{approaching_books.size}冊" if approaching_books.size > 1
      msg += "の返却日が明後日です."
      twitter.update(msg)
    end
  end

  task :reserving do
    reserving_books = mlib.reserving
    reserved_books = reserving_books.select{|book| book.status.include?('確保済') }
    if reserved_books.present?
      first = reserved_books.first
      msg = "@T_Hash 予約していた"
      msg += "『#{first.title}』"
      msg += "など, #{reserved_books.size}冊" if reserved_books.size > 1
      msg += "が図書館で確保済です."
      msg += " (#{first.reserved_until.to_date.to_s} 迄)" if first.reserved_until
      twitter.update(msg)
    end
  end

end
