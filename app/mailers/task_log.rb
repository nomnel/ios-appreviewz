class TaskLog < ActionMailer::Base
  default from: ENV['MAIL_ADDRESS']

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.task_log.scraping.subject
  #
  def scraping logs
    @logs = logs
    mail(
      to: ENV['RECEIVER_ADDRESS'],
      subject: "#{DateTime.now}のレビュー取得結果"
    )
  end
end
