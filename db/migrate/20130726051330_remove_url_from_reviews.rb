class RemoveUrlFromReviews < ActiveRecord::Migration
  def change
    remove_column :reviews, :url
  end
end
