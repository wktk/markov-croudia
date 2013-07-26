# coding: utf-8
require 'croudia'
require 'okura/serializer'
require './timer'
require './models'

class Bot
  MAX_TEXT_LENGTH = 372

  attr_reader :croudia, :tagger, :timer

  def initialize
    @croudia = Croudia::Client.new
    @tagger = Okura::Serializer::FormatInfo.create_tagger('naist-jdic')
    @timer = Timer.new(Time.at(Option.last_time.to_i))
  end

  def register
    refresh_token
    yield self if block_given?
    self
  end

  def refresh_token
    rt = Option.refresh_token || ENV['INITIAL_REFRESH_TOKEN']
    at = croudia.get_access_token(
      grant_type: :refresh_token,
      refresh_token: rt
    )
    croudia.access_token = at.access_token
    Option.refresh_token = at.refresh_token
    timer.mins_after(at.expires_in / 120) { refresh_token }
  end

  def update
    dictionary, originals = dictionary_from_timeline
    100.times do
      status = create_from dictionary
      unless originals.include?(status)
        croudia.update(status[0...MAX_TEXT_LENGTH])
        break
      end
    end
    Option.last_time = timer.last_time.to_i
  end

  def reply
    last_id = Option.last_replied_id
    mentions = croudia.mentions.select { |s| s.id > last_id }
    return if mentions.empty?
    dictionary, originals = dictionary_from_timeline
    replied = []
    mentions.reverse.each do |mention|
      100.times do
        status = create_from dictionary
        unless originals.include?(status)
          @croudia.update(
            "@#{mention.user.screen_name} #{status}"[0...MAX_LENGTH],
            in_reply_to_status_id: mention.id_str
          )
          replied << mention.id
          break
        end
      end
    end
    Option.last_replied_id = replied.max
    Option.last_time = timer.last_time.to_i
  end

  def join
    timer.join
  end

private
  def dictionary_from_timeline
    tl = croudia.home_timeline(count: 40).reject! do |status|
      status.user.protected || URI.regexp.match(status.text)
    end.map! do |status|
      status.text.gsub(/[@＠]\w+/, '')
    end
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
