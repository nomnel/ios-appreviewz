class AddAffiliateUrlToApps < ActiveRecord::Migration
  def change
    add_column :apps, :affiliate_url, :text
  end
end
