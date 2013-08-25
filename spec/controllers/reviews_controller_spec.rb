require 'spec_helper'

describe ReviewsController do
  fixtures :reviews

  describe "GET index" do
    it "assigns all reviews as @reviews" do
      get :index
      assigns(:reviews).should eq(Review.order('published_at desc').page(1).to_a)
    end
  end
end