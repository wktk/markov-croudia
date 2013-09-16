# coding: utf-8
require './bot'

Bot.new.register do |bot|
  bot.timer.at_each(/:25/) { bot.update }
  bot.timer.at_each(//) { bot.reply }
  bot.timer.at_each(//) { bot.update_friendships }
end.join
