require 'bundler/setup'
Bundler.require
require 'yaml'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/array'

class Base
  class_attribute :url
  attr_reader :conf, :session

  def initialize
    @conf = YAML.load(open('secret.yml').read)[self.class.name.underscore]
    Capybara.javascript_driver = :webkit
    @session = Capybara::Session.new(:webkit)
    @session.visit self.class.url
  end

  def s
    session
  end

  def top
    @session.visit self.class.url
  end

  def delay(n=3)
    sleep n
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
