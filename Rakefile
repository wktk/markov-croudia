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
