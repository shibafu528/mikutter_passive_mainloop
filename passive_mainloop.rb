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
    pipes = []
    pipes << prepare_remain_hook
    pipes << prepare_reserve_hook
    pipes << prepare_sigusr1
    pipes << prepare_allen if ENV["ALLEN"] == "1"

    notice "Started. My PID is #{Process.pid}"

    while (readable, = IO.select(pipes))
      readable.each do |pipe|
        event = pipe.gets.strip
        notice "Run: #{event}"
        Delayer.run
      end
    end
  ensure
    SerialThreadGroup.force_exit!
  end

  def exception_filter(e)
    e
  end

  private

  def prepare_remain_hook
    rx, tx = IO.pipe
    
    Delayer.register_remain_hook do
      er = caller.find { |c| not c.include?("delayer") }
      tx.puts("remain_hook by #{er}")
    end
    
    rx
  end

  def prepare_reserve_hook
    rx, tx = IO.pipe
   
    Delayer.register_reserve_hook do |delay|
      er = caller.find { |c| not c.include?("delayer") }
      Thread.new do
        sleep delay
        tx.puts("reserve_hook(#{delay}) by #{er}")
      end
    end
    
    rx
  end

  def prepare_sigusr1
    rx, tx = IO.pipe
    
    Signal.trap(:USR1) do
      tx.puts("USR1")
    end

    rx
  end

  def prepare_allen
    rx, tx = IO.pipe
    
    Thread.new do
      loop do
        sleep 0.25
        tx.puts("Allen")
      end
    end

    rx
  end
end
