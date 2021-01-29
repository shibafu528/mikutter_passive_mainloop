# frozen_string_literal: true

Plugin.create(:passive_mainloop) do
end

unless Delayer::Extend.method_defined?(:register_reserve_hook)
  notice 'patched!'
  
  module Delayer::Extend
    def reserve(procedure)
      lock.synchronize do
        if @last_reserve
          if @last_reserve > procedure
            @reserves.add(@last_reserve)
            @last_reserve = procedure
          else
            @reserves.add(procedure)
          end
        else
          @last_reserve = procedure
        end
      end
      # -- begin patch --
      @reserve_hook&.call([procedure.reserve_at - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0].max)
      # -- end patch --
      self
    end
    
    def register_reserve_hook(&proc)
      @reserve_hook = proc
    end
  end
end

module Mainloop
  def before_mainloop
  end

  def mainloop
    delayer_read, delayer_write = IO.pipe
    
    Delayer.register_remain_hook do
      er = caller.find { |c| not c.include?("delayer") }
      delayer_write.puts("remain_hook by #{er}")
    end

    Delayer.register_reserve_hook do |delay|
      er = caller.find { |c| not c.include?("delayer") }
      Thread.new do
        sleep delay
        delayer_write.puts("reserve_hook(#{delay}) by #{er}")
      end
    end

    Signal.trap(:USR1) do
      delayer_write.puts("USR1")
    end

    Thread.new do
      loop do
        sleep 0.25
        delayer_write.puts("Allen")
      end
    end

    while (readable, = IO.select([delayer_read]))
      event = readable.first.gets.strip
      notice "Run: #{event}"
      Delayer.run
    end
  ensure
    SerialThreadGroup.force_exit!
  end

  def exception_filter(e)
    e
  end
end
