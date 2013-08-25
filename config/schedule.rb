log_path = Whenever.path + '/log/cron.log'
error_log_path = Whenever.path + '/log/error.log'

every '5 7-22/3 * * *' do
  command 'MAIL_ADDRESS="$MAIL_ADDRESS" MAIL_PASSWORD="$MAIL_PASSWORD" RECEIVER_ADDRESS="$RECEIVER_ADDRESS" LINKSYNERGY_TOKEN="$LINKSYNERGY_TOKEN" bundle exec rails runner Tasks::Scraping.all_feeds!', :output, {error: error_log_path, standard: log_path}
end
