require 'bundler'
Bundler.require
require 'yaml'
require 'logger'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/array'
require 'active_support/core_ext/numeric/time'

module Kernel
  def delay(n=3)
    sleep n
  end
end

class Base
  attr_reader :conf, :url
  attr_accessor :session, :logger

  # @url should be defined in child classes
  def initialize
    raise 'no url given' unless url
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @conf = YAML.load(open('secret.yml').read)[self.class.name.underscore]
    Capybara.javascript_driver = :webkit
    @session = Capybara::Session.new(:webkit)
    @session.driver.header('user-agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/602.1.50 (KHTML, like Gecko) Version/10.0 Safari/602.1.50')
    @logger.info "visiting: #{url}"
    @session.visit url
  end

  def s
    session
  end

  def cd(other_session)
    @session = other_session
  end

  def contains_text?(text)
    if text =~ /'/
      # element_present? "//*[not(self::script) and text()[contains(.,\"#{text}\")]]"
      element_present? "//*[text()[contains(.,\"#{text}\")]]"
    else
      element_present? "//*[text()[contains(.,'#{text}')]]"
    end
  end

  def element_present?(query)
    s.all(*query_with_type(query)).present?
  end

  def query_with_type(query)
    type = query.index('//') ? :xpath : :css
    [type, query]
  end

  def scrape_table(query)
    elem = s.find(*query_with_type(query))
    raise 'not a elem selector' if elem.tag_name != 'table'
    Table.new(elem)
  end

  class Table
    def initialize(element)
      @element = element
    end

    def headers
      @element.all('th')
    end

    def rows
      item_rows = @element.all('tr')
      item_rows = item_rows.drop(1) if headers.present?
      item_rows.map{|row| Row.new(row) }
    end

    class Row
      attr_reader :element
      def initialize(element)
        @element = element
      end

      def tds
        @element.all('td')
      end
      alias :cells :tds
    end
  end
end
