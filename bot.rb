# coding: utf-8
require 'croudia'
require 'okura/serializer'
require './timer'
require './db'

class Bot
  MAX_TEXT_LENGTH = 372

  attr_reader :croudia, :tagger, :timer

  def initialize
    @croudia = Croudia::Client.new
    @tagger = Okura::Serializer::FormatInfo.create_tagger('naist-jdic')
    @timer = Timer.new(Time.at(DB.last_time.to_i))
  end

  def register
    refresh_token
    yield self if block_given?
    self
  end

  def refresh_token
    rt = DB.refresh_token
    at = croudia.get_access_token(
      grant_type: :refresh_token,
      refresh_token: rt
    )
    croudia.access_token = at.access_token
    DB.refresh_token = at.refresh_token
  rescue
    next_refresh = 1
  else
    next_refresh = at.expires_in / 120
  ensure
    timer.mins_after(next_refresh) { refresh_token }
  end

  def update
    dictionary, originals = dictionary_from_timeline
    100.times do
      status = create_from dictionary
      unless originals.include?(status)
        begin
          croudia.update(status[0...MAX_TEXT_LENGTH])
        rescue Croudia::Error::BadRequest
          retry_count ||= 0
          retry_count += 1
          sleep(4)
          retry if retry_count < 5
        end
        break
      end
    end
    DB.last_time = timer.last_time.to_i
  end

  def reply
    mentions = croudia.mentions(count: 200, since_id: last_replied_status)
    return if mentions.empty?

    dictionary, originals = dictionary_from_timeline
    replied_users = []
    mentions.reverse.each do |mention|
      last_replied_status(mention.id)
      next if replied_users.include?(mention.user.id)

      100.times do
        status = create_from dictionary
        unless originals.include?(status)
          begin
            @croudia.update(
              "@#{mention.user.screen_name} #{status}"[0...MAX_TEXT_LENGTH],
              in_reply_to_status_id: mention.id_str
            )
          rescue Croudia::Error::BadRequest
            retry_count ||= 0
            retry_count += 1
            sleep(4)
            retry if retry_count < 5
          end
          break
        end
      end
      replied_users << mention.user.id
    end
    DB.last_time = timer.last_time.to_i
  end

  def last_replied_status(new_value=nil)
    last_replied_status = nil
    (@last_replied_status_mutex ||= Mutex.new).synchronize do
      last_replied_status = DB.last_replied_status.to_i

      if new_value && last_replied_status > new_value.to_i
        DB.last_replied_status = new_value
        last_replied_status = new_value
      end
    end
    last_replied_status
  end

  def update_friendships
    current_user = croudia.current_user

    friends = []
    cursor = -1
    while cursor.nonzero?
      ids = croudia.friend_ids(current_user, cursor: cursor, count: 100)
      friends.push(*ids.ids)
      cursor = ids.next_cursor
    end

    followers = []
    cursor = -1
    while cursor.nonzero?
      ids = croudia.follower_ids(current_user, cursor: cursor, count: 100)
      followers.push(*ids.ids)
      cursor = ids.next_cursor
    end

    users_to_follow = (followers - friends).reverse
    users_to_unfollow = (friends - followers).reverse
    users_to_follow.map! { |id| croudia.follow(id) }
    users_to_unfollow.map! { |id| croudia.unfollow(id) }
  end

  def join
    timer.join
  end

private
  def dictionary_from_timeline
    tl = croudia.home_timeline(count: 200).reject! do |status|
      status.user.protected || URI.regexp.match(status.text)
    end.map! do |status|
      status.text.gsub(/[@＠]\w+/, '')
    end
    tl = tl[0...40]
    dictionary = Hash.new([].freeze)
    tl.each do |text|
      words = tagger.wakati(text)
      prev = words.shift
      words.each do |word|
        dictionary[prev] += [word]
        prev = word
      end
    end
    [dictionary, tl]
  end

  def create_from(dictionary)
    status = ''
    prev = 'BOS/EOS'
    loop do
      word = dictionary[prev].sample
      break if 'BOS/EOS' == word
      status << word
      break if status.size > MAX_TEXT_LENGTH
      prev = word
    end
    status
  end
end
