desc 'Complete the OAuth authorize process'
task :auth, [:code] do |t, args|
  print 'Verifying the DB...  '
  require './db'
  puts 'done.'

  print 'Retrieving access token...  '
  require 'croudia'
  at = Croudia.get_access_token(args[:code])
  puts 'done.'

  print 'Verifying credential...  '
  Croudia.access_token = at.access_token
  user = Croudia.verify_credentials
  puts 'done.'

  print 'Writing to the DB...  '
  DB.refresh_token = at.refresh_token
  puts 'done.'

  puts "Refresh token for @#{user.screen_name} has been added to the DB"
end

desc 'Update or verify last replied status id on DB'
task :last_reply, [:status_id] do |t, args|
  print 'Verifying the DB...  '
  require './db'
  puts 'done.'

  if args[:status_id]
    print 'Updating last_replied_status...  '
    DB.last_replied_status = args[:status_id]
    puts 'done.'
  else
    puts "Current last_replied_status is #{DB.last_replied_status}"
  end
end
