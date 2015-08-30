class MeguroLib < Base
  class Scraper

    def initialize(context, type)
      @context = context
      @type = type
      @target_table = type == :borrow ? @context.method(:borrowing_table) : @context.method(:reserving_table)
      @date_column  = type == :borrow ? 4 : 8
    end

    def method_missing(name, *args)
      @context.method(name).call(*args)
    end

    def scrape
      logger.debug("before: #{scan}")
      login

      unless my_page?
        logger.error("[#{__method__}] Not in mypage.")
        return false
      end

      # 行数のみ保存しておき, loop 内で毎回 DOM を取得して処理行数を進めていく
      rows_count = @target_table.call().rows.count
      rows_count.times do |i|
        row = @target_table.call().rows[i]
        cells = row.cells.map(&:text)

        title = splite_title(cells[2]).first
        hashed_title = Digest::SHA1.hexdigest(title)

        # 既に登録済のイベントならスキップ
        event = dynamo.scan(table_name: :events).items.find{|e| e['hashed_title'] == hashed_title && e['type'] == @type.to_s }
        logger.info("[#{__method__}] skip -- known '#{@type}' event for: #{title}") && next if event

        item = {
          uuid: SecureRandom.uuid,
          isbn: nil,
          hashed_title: hashed_title,
          type: @type,
          date: Date.parse(cells[@date_column]).to_s
        }
        dynamo.put_item({ table_name: :events, item: item })

        row.element.find('a').click
        delay # detail page

        # put into books table, then return back isbn-13 code.
        isbn = put_book
        dynamo.put_item({ table_name: :events, item: item.merge(isbn: isbn) }) if isbn

        logger.info("[#{__method__}] add -- '#{@type}' event for: (#{isbn}) #{title}")

        s.find(:xpath, '/html/body/table[4]//a[./b]').click
        delay # 利用状況の一覧ページへ
      end
      logger.debug("after : #{scan}")
    end

    # in detail page
    def put_book
      unless detail_page?
        logger.error("[#{__method__}] Not in book detail page.")
        return false
      end

      val_of = -> (header) {
        s.find(:xpath, "//td[./nobr/b[text()='#{header}']]/following-sibling::td").text
      }

      title  = val_of.call('タイトル').gsub(Moji.han, '')
      author = val_of.call('著者事項')
      isbn13 = Lisbn.new(val_of.call('ISBN')).isbn13

      if dynamo.get_item(table_name: :books, key: {isbn: isbn13}).item
        logger.info("[#{__method__}] skip -- known isbn: (#{isbn13}) #{title}")
      else
        dynamo.put_item(table_name: :books,
        item: {isbn: isbn13, title: title, author: author})
        logger.info("[#{__method__}] add -- new book: (#{isbn13}) #{title}")
      end

      return isbn13
    end

    def scan
      {
        events: dynamo.scan(table_name: :events).items,
        books: dynamo.scan(table_name: :books).items
      }
    end

    def clear_all
     dynamo.scan(table_name: :events).items.each do |item|
       p dynamo.delete_item(table_name: :events, key: { uuid: item['uuid'] } )
     end
     dynamo.scan(table_name: :books).items.each do |item|
       p dynamo.delete_item(table_name: :books, key: { isbn: item['isbn'] } )
     end
     nil
    end

  end
end
