require 'test_helper'

class TaskLogTest < ActionMailer::TestCase
  test "scraping" do
    mail = TaskLog.scraping
    assert_equal "Scraping", mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

end
