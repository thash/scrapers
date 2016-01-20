require 'bundler'
Bundler.require(:development)

require_relative '../megurolib'

class TestMeguroLib < Test::Unit::TestCase
  def setup
    @megurolib = MeguroLib.new(url: File.expand_path('../lib_my_20160120.html', __FILE__))
    @r_scraper = MeguroLib::ReserveScraper.new(@megurolib)
  end

  def test_reserving
    reservings = @megurolib.reserving
    assert_equal 4, reservings.count
    assert_equal ['確保済', '文法理論の諸相'], -> (b) { [b.status, b.title] }.call(reservings.first)
    assert_equal [Time, 'JST'], -> (t) { [t.class, t.zone] }.call(reservings.first.reserved_at)
    assert_equal [Time, 'JST'], -> (t) { [t.class, t.zone] }.call(reservings.first.reserved_until)
  end
end
