class Tasks::Scraping
  def self.all_feeds!
    agent = make_agent
    logs = []

    Reviewer.all.each do |reviewer|
      log = {code: reviewer.code, name: reviewer.name, entries: []}
      logs << log

      r = Feedzirra::Feed.fetch_and_parse(reviewer.feed_url)
      next if r.instance_of? Fixnum

      r.entries.map{|e| [e.url, e.title, e.published]}.each do |e_url, e_title, e_published|
        agent.get e_url
        e_url = agent.page.uri.to_s
        break if Review.where(url: e_url).present?

        e_log = {title: e_title, url: e_url, apps: [], error: nil}
        log[:entries] << e_log
        begin
          appcodes = find_appcodes reviewer, agent
          save_review_data reviewer, e_title, e_url, e_published, appcodes, e_log
        rescue => e
          e_log[:error] = {inspect: e.inspect, backtrace: e.backtrace}
        end
      end
    end
    TaskLog.scraping(logs).deliver
    create_affiliate_url
  end

  def self.archives!
    agent = make_agent
    starts = DateTime.now.yesterday
    Reviewer.all.each do |reviewer|
      i = 0
      begin
        crawl_archive_urls(reviewer).each do |url|
          next if Review.where(url: url).present?

          agent.get url
          title = agent.page.title
          begin
            appcodes = find_appcodes reviewer, agent
            i += 1
            save_review_data reviewer, title, url, (starts - i.minutes), appcodes, nil
          rescue
            next
          end
        end
      rescue
        next
      end
    end
  end

  def self.test_feed reviewer_code
    r = Reviewer.where(code: reviewer_code).first
    raise "reviewer not found (code: #{code})" if r.blank?
    a = make_agent
    es = Feedzirra::Feed.fetch_and_parse(r.feed_url).entries
    es.map{|e| [e.url, e.title]}.each do |u, t|
      puts "start: #{t}: #{u}"
      a.get u
      puts find_appcodes(r, a)
    end
  end

  def self.test_url code, url
    r = Reviewer.where(code: code).first
    raise "reviewer not found (code: #{code})" if r.blank?
    a = make_agent
    a.get url
    puts find_appcodes(r, a)
  end

  private
    def self.save_review_data reviewer, review_title, review_url, review_published, appcodes, log
      return if appcodes.blank?
      ActiveRecord::Base.transaction do
        review = Review.create(
          reviewer_id: reviewer.id,
          title: review_title,
          url: review_url,
          published_at: review_published
        )

        appcodes.each do |appcode|
          r = ITunesSearchAPI.lookup id: appcode, country: 'JP'

          r['genreIds'].map(&:to_i).each_with_index do |code, i|
            if Category.where(code: code).blank?
              Category.create name: r['genres'][i], code: code
            end
          end

          if Developer.where(code: r['artistId']).blank?
            Developer.create name: r['artistName'], code: r['artistId']
          end

          app = App.where(code: r['trackId']).first
          app_params = App.itunes_res_to_params r
          if app.blank?
            app = App.create app_params
          else
            app.update_attributes app_params
          end
          log[:apps] << {name: app.name, url: app.url} if log.present?

          AppCategory.where(app_id: app.id).each(&:delete)
          Category.where(code: r['genreIds'].map(&:to_i)).each do |category|
            AppCategory.create app_id: app.id, category_id: category.id
          end

          AppReview.create app_id: app.id, review_id: review.id
        end
      end
    end

    def self.create_affiliate_url
      apps = App.where(affiliate_url: nil)
      token = ENV['LINKSYNERGY_TOKEN']
      return if token.nil?
      mid = 13894
      generator = 'http://getdeeplink.linksynergy.com/createcustomlink.shtml'
      apps.each do |app|
        begin
          affiliate_url = Net::HTTP.get(URI.parse("#{generator}?token=#{token}&mid=#{mid}&murl=#{app.url}"))
          app.update_attribute(:affiliate_url, affiliate_url)
        rescue
          next
        end
      end
    end

    def self.crawl_archive_urls reviewer
      agent = make_agent
      agent.get archive_url(reviewer)
      r = []
      30.times do
        (r << entry_urls_finder(reviewer).call(agent.page).uniq).flatten!.uniq!
        next_url = next_page_finder(reviewer).call(agent.page)
        break if next_url.nil? or r[100].present?
        agent.get next_url
      end
      r
    end

    def self.make_agent
      agent = Mechanize.new
      agent.max_history = 1
      agent.user_agent_alias = 'Mac Safari'
      agent
    end

    def self.itunes_url? url
      not url.match(/^https:\/\/itunes.apple.com/).nil?
    end

    def self.extract_appcode url
      if itunes_url?(url)
        m = url.match(/id\d{9}/)
        m.nil? ? nil : m[0].gsub(/id/, '').to_i
      else
        nil
      end
    end

    def self.find_appcodes reviewer, agent
      app_urls_finder(reviewer).call(agent.page).uniq.map{|url|
        begin
          agent.get url
          url = agent.page.uri.to_s

          3.times do
            break if itunes_url? url
            agent.get url
            url = agent.page.uri.to_s
          end

        rescue Mechanize::ResponseCodeError => e
          extract_appcode e.page.uri.to_s
        else
          extract_appcode url
        end
      }.uniq.compact
    end

    def self.archive_url reviewer
      case reviewer.code
      when 1 then 'http://www.appbank.net/category/iphone-application'
      when 2 then 'http://app-library.com/archives/category/app'
      when 3 then 'http://www.danshihack.com/category/iphone_app'
      when 4 then 'http://appmaga.net/archives/category/app'
      when 5 then 'http://www.appps.jp/'
      when 6 then 'http://www.applefan2.com/'
      when 7 then 'http://appwoman.jp/archives/category/iphone'
      when 8 then 'http://www.iphonejoshibu.com/new/'
      when 9 then 'http://girlsapp.jp/archives/category/review/'
      when 10 then 'http://www.iphone-girl.jp/application-review/'
      when 11 then 'http://ketchapp.jp/app/ip/'
      when 12 then 'http://iphones.cx/app/'
      when 13 then 'http://www.kids-app.com/'
      when 14 then 'http://blog.rainbowapps.com/'
      when 15 then 'http://touchlab.jp/category/apps/'
      else raise "finder for #{reviewer.name} is not implemented."
      end
    end

    def self.entry_urls_finder reviewer
      case reviewer.code
      when 1 then -> page {page./('.link a').map{|e| e.attribute('href').to_s}}
      when 2 then -> page {page./('.entryList .infoTxt a').map{|e| e.attribute('href').to_s}}
      when 3 then -> page {page./('.posts h2 a').map{|e| e.attribute('href').to_s}}
      when 4 then -> page {page./('#content .entry-title a').map{|e| e.attribute('href').to_s}}
      when 5 then -> page {page./('.article-title a').map{|e| e.attribute('href').to_s}}
      when 6 then -> page {page./('.post h2 a').map{|e| e.attribute('href').to_s}}
      when 7 then -> page {page./('.entry-title a').map{|e| e.attribute('href').to_s}}
      when 8 then -> page {page./('.article .section.cf h2 a').map{|e| e.attribute('href').to_s}}
      when 9 then -> page {page./('.entry .entry-heading a').map{|e| e.attribute('href').to_s}}
      when 10 then -> page {page./('.post .postTtl a').map{|e| e.attribute('href').to_s}}
      when 11 then -> page {page./('.rev_list_area a').map{|e| e.attribute('href').to_s}}
      when 12 then -> page {page./('#content .main h3 a').map{|e| e.attribute('href').to_s}}
      when 13 then -> page {page./('.post .title a').map{|e| e.attribute('href').to_s}}
      when 14 then -> page {page./('.post-group .title a').map{|e| e.attribute('href').to_s}}
      when 15 then -> page {page./('.entry-title a').map{|e| e.attribute('href').to_s}}
      else raise "finder for #{reviewer.name} is not implemented."
      end
    end

    def self.next_page_finder reviewer
      case reviewer.code
      when 1 then -> page {page./('.page .next').first.attribute('href').to_s}
      when 2 then -> page {page./('#nav-below .current+a').first.attribute('href').to_s}
      when 3 then -> page {page./('.pagination .current+a').first.attribute('href').to_s}
      when 4 then -> page {page./('.nav-previous a').first.attribute('href').to_s}
      when 5 then -> page {page./('.paging-next a').first.attribute('href').to_s}
      when 6 then -> page {page./('.std-nav a:first-child').first.attribute('href').to_s}
      when 7 then -> page {page./('.tab_nav a.next').first.attribute('href').to_s}
      when 8 then -> page {page./('.module_pager .next a').first.attribute('href').to_s}
      when 9 then -> page {page./('.pagination .current+a').first.attribute('href').to_s}
      when 10 then -> page {page./('.pageListNav .next').first.attribute('href').to_s}
      when 11 then -> page {page./('.tablenav .current+a').first.attribute('href').to_s}
      when 12 then -> page {page./('.page-navi .link_next').first.attribute('href').to_s}
      when 13 then -> page {nil}
      when 14 then -> page {page./('.pagination .next').first.attribute('href').to_s}
      when 15 then -> page {page./('.pagination a:last-child').first.attribute('href').to_s}
      else raise "finder for #{reviewer.name} is not implemented."
      end
    end

    def self.app_urls_finder reviewer
      case reviewer.code
      when 1 then # AppBank
        -> page {page./('img[src="http://img.blog.appbank.net/appdl.png"]').map{|e| e./('..')[0].attribute('href').to_s}.presence || page./('img[src*="phobos.apple.com/"]').map{|e| e./('..')[0].attribute('href').to_s}}
      when 2 then # AppLibrary
        -> page {page./('img[src="http://app-library.com/wp-content/uploads/2013/01/download2.png"]').map{|e| e./('..')[0].attribute('href').to_s}}
      when 3 then # 男子ハック
        -> page {page./('img[src="http://www.danshihack.com/wordpress_r/wp-content/uploads/2013/02/AppDownloadButton-2.jpg"]').map{|e| e./('..')[0].attribute('href').to_s}}
      when 4 then # あぷまがどっとねっと
        -> page {page./('a[href^="http://click.linksynergy.com/"] > img[src*="phobos.apple.com/"], a[href^="https://itunes.apple.com/"] > img[src*="phobos.apple.com/"]').map{|e| e./('..')[0].attribute('href').to_s}}
      when 5 then # アップス！
        -> page {page./('a[href^="http://click.linksynergy.com/"] > img[src*="phobos.apple.com/"], a[href^="https://itunes.apple.com/"] > img[src*="phobos.apple.com/"]').map{|e| e./('..')[0].attribute('href').to_s}}
      when 6 then # AppleFan
        -> page {page./('img[src^="http://www.applefan2.com/wp-content/uploads/2010/06/itunes_button"]').map{|e| e./('..')[0].attribute('href').to_s}.presence || page./('img[src*="phobos.apple.com/"]').map{|e| e./('..')[0].attribute('href').to_s}}
      when 7 then # App Woman
        -> page {page./('#ilink').map{|e| e.attribute('href').to_s}}
      when 8 then # iPhone女子部
        -> page {page./('img[src="http://www.iphonejoshibu.com/wp-content/uploads/2013/04/banner_appstore113.png"], img[src="http://www.iphonejoshibu.com/wp-content/uploads/2013/07/banner_appstore1131.png"]').map{|e| e./('..')[0].attribute('href').to_s}}
      when 9 then # Girl's App
        -> page {page./('img[src="/img/btn_go_itunes_big_01.gif"]').map{|e| e./('..')[0].attribute('href').to_s}}
      when 10 then # iPhone女史
        -> page {page./('img[src="http://www.iphone-girl.jp/wp-content/themes/iphone_joshi_new/img/page/post_btn_app.png"]').map{|e| e./('..')[0].attribute('href').to_s}}
      when 11 then # Ketchapp!
        -> page {page./('.button_iphone').map{|e| e.attribute('href').to_s}}
      when 12 then # iStation
        -> page {page./('img[src="/image/appBtn.jpg"]').map{|e| e./('..')[0].attribute('href').to_s}}
      when 13 then # キッズアプリCOM
        -> page {page./('img[src="http://www.kids-app.com/image/itunes_store_check_red.png"]').map{|e| e./('..')[0].attribute('href').to_s}}
      when 14 then # RainbowApps
        -> page {page./('img[src="http://blog.rainbowapps.com/wp-content/uploads/2010/12/download.png"]').map{|e| e./('..')[0].attribute('href').to_s}}
      when 15 then # Touch Lab
        -> page {page./('a[href^="http://click.linksynergy.com/"]').map{|e| e.attribute('href').to_s}.presence || page./('a[href^="https://itunes.apple.com/"]').map{|e| e.attribute('href').to_s}}
      else
        raise "finder for #{reviewer.name} is not implemented."
      end
    end
end