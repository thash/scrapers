require File.expand_path('../../megurolib.rb', __FILE__)

class MeguroLib
  class IsbnLookup

    attr_reader :vacuum

    def initialize

      # こっからでは conf がみつからない

      @vacuum = Vacuum.new('JP')
      @vacuum.configure({
        aws_access_key_id: conf['product_advertising_api_key'],
        aws_secret_access_key: conf['product_advertising_api_secret'],
        associate_tag: conf['amazon_associate_tag']
      })
    end

    def search(title, author)
      res = vacuum.item_search({
        Title: title,
        Author: author,
        ResponseGroup: 'ItemAttributes',
        SearchIndex: 'Books'
      })
      # TODO: 出版年度
      # 書籍の場合 ASIN = ISBN
      # puts res.parse['ItemSearchResponse']['Items']['Item'].count
      res.parse['ItemSearchResponse']['Items']['Item'].each do |item|
        pp item["ItemAttributes"]
        pp '-------'
      end
    end
  end
end
