# coding: utf-8
require './bot'

Bot.new.register do |bot|
  bot.timer.at_each(/:[25]5/) { bot.update }
#  bot.timer.at_each(//) { bot.reply }
end.join
