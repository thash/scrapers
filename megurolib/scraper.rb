class MeguroLib < Base
  class Scraper

    def initialize(context, type, callback=nil)
      @context = context
      @type = type
      @target_table = type == :borrow ? @context.method(:borrowing_table) : @context.method(:reserving_table)
      @date_column  = type == :borrow ? 4 : 8
      @shown_hashed_titles = []
      @callback = callback
    end

    def method_missing(name, *args)
      @context.method(name).call(*args)
    end

    def known_event?(hashed_title, type)
      dynamo.scan(table_name: :events).items
        .find {|e| e['hashed_title'] == hashed_title &&
                   e['type'] == @type.to_s }
    end

    def scrape
      logger.debug("before: #{scan}")
      login

      unless my_page?
        logger.error("Could not move to mypage.")
        return false
      end

      # 行数のみ保存しておき, loop 内で毎回 DOM を取得して処理行数を進めていく
      rows_count = @target_table.call().rows.count
      rows_count.times do |i|
        row = @target_table.call().rows[i]
        cells = row.cells.map(&:text)

        title = splite_title(cells[2]).first
        hashed_title = Digest::SHA1.hexdigest(title)
        @shown_hashed_titles << hashed_title

        # 既に登録済のイベントならスキップ
        if known_event?(hashed_title, @type.to_s)
          logger.info("skip -- known '#{@type}' event for: #{title}")
          next
        end

        new_event = {
          uuid: SecureRandom.uuid,
          isbn: nil,
          hashed_title: hashed_title,
          type: @type,
          date: Date.parse(cells[@date_column]).to_s
        }
        dynamo.put_item({ table_name: :events, item: new_event })
        logger.info("[#{__method__}] add -- '#{@type}' event for: #{title}")

        # go to detail page
        row.element.find('a').click
        delay

        # put information into books table
        isbn = Lisbn.new(val_of(s, 'ISBN')).isbn13 # nil is set if isbn row doesn't exist
        isbn = val_of(s, '書誌コード') unless isbn
        new_book = {
          isbn: isbn,
          title: val_of(s, 'タイトル').gsub(Moji.han, ''),
          author: val_of(s, '著者事項')
        }

        if isbn
          # update event with isbn
          dynamo.put_item({ table_name: :events, item: new_event.merge(isbn: isbn) })
          logger.info("update -- '#{@type}' event with isbn=#{isbn} for: #{new_book[:title]}")

          # skip saving the book if it already exists.
          if dynamo.get_item(table_name: :books, key: {isbn: isbn}).item
            logger.info("skip -- known book: (#{isbn}) #{new_book[:title]}")
          else
            # save new book
            dynamo.put_item(table_name: :books, item: new_book)
            logger.info("add -- new book: (#{isbn}) #{new_book[:title]}")
          end
        else
          logger.info("ISBN or shoshi_code missing -- #{new_book[:title]}")
        end

        s.find(:xpath, "//a//*[text()[contains(., '利用状況の一覧')]]").click
        delay # 利用状況の一覧ページへ
      end
      @callback.call(@shown_hashed_titles) if @callback
      logger.debug("after : #{scan}")
    end

    def val_of(session, header)
      data_table = session.find(:xpath, "//table//tr//*[text()[contains(.,'ISBN')]]/ancestor::table[1]")
      data_table.all(:xpath, "//td//*[text()[contains(.,\'#{header}\')]]/ancestor::td[1]/following-sibling::td")[0].text
    end

    def scan
      {
        events: dynamo.scan(table_name: :events).items,
        books: dynamo.scan(table_name: :books).items
      }
    end

    def clear_all
     dynamo.scan(table_name: :events).items.each do |item|
       # return events are hard to reproduce
       next if item['type'] == 'return'
       p dynamo.delete_item(table_name: :events, key: { uuid: item['uuid'] } )
     end
     dynamo.scan(table_name: :books).items.each do |item|
       p dynamo.delete_item(table_name: :books, key: { isbn: item['isbn'] } )
     end
     nil
    end

  end

  class BorrowScraper < Scraper

    def initialize(context)
      callback = -> (shown_hashed_titles) do
        borrow_events = query_events(:borrow, 60)
        return_events = query_events(:return, 60)
        missing_borrowing = borrow_events
                              .reject{|be| return_events.find{|re| re['hashed_title'] == be['hashed_title'] }}
                              .reject{|be| shown_hashed_titles.include?(be['hashed_title']) }
        logger.debug("borrow_events: #{borrow_events}")
        logger.debug("return_events: #{return_events}")
        logger.debug("missing_borrowing: #{missing_borrowing}")
        missing_borrowing.each do |be|
          dynamo.put_item(table_name: :events,
                          item: { uuid: SecureRandom.uuid,
                                  isbn: be['isbn'],
                                  hashed_title: be['hashed_title'],
                                  type: :return,
                                  date: (Date.today - 1).to_s })
          logger.info("[#{__method__}] add -- 'return' event for: #{be['isbn']}")
        end
      end
      super(context, :borrow, callback)
      # logger.level = Logger::DEBUG
    end

    private def query_events(type, past_days)
              dynamo.query(table_name: :events,
                           index_name: :type_date_index,
                           key_conditions: { type: { comparison_operator: :EQ, attribute_value_list: [type.to_s] },
                                             date: { comparison_operator: :GT, attribute_value_list: [(Date.today - past_days).to_s] } } ).items
            end
  end

  class ReserveScraper < Scraper
    def initialize(context)
      super(context, :reserve)
    end
  end

end
