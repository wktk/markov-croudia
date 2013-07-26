class Timer
  attr_reader :last_time, :thread

  def initialize(last_time)
    @last_time = last_time || Time.now
    @tasks = Hash.new([].freeze)
    @thread = Thread.new do
      loop { sleep(0.1) && callback }
    end
  end

  def at_each(min_regexp, &block)
    @tasks[min_regexp] += [block]
  end

  def mins_after(min, &block)
    @tasks[Time.now + min * 60] += [block]
  end

  def join
    thread.join
  end

  def callback
    now = Time.now
    return if now.sec.nonzero? || last_time.min == now.min
    @tasks.each do |key, value|
      if case key
        when Regexp
          key.match("#{now.hour}:#{now.min}")
        when Time
          key.to_i < now.to_i && @tasks.delete(key)
        else
          @tasks.delete(key) && false
        end

        value.each { |proc| Thread.new(&proc) }
      end
    end
    @last_time = now
  end
end
