require "../spec_helper"

describe Qt::Timer do
  it "fires in an event loop" do
    loop = Qt::EventLoop.new
    timer = Qt::Timer.new
    ticks = 0
    timer.interval = 1
    timer.on_timeout do
      ticks += 1
      loop.quit if ticks == 3
    end
    timer.start
    timer.active?.should be_true
    loop.exec.should eq(0)
    timer.stop
    timer.active?.should be_false
    ticks.should eq(3)
  end

  it "fires single shot timers once" do
    loop = Qt::EventLoop.new
    timer = Qt::Timer.new
    timer.single_shot = true
    ticks = 0
    timer.on_timeout do
      ticks += 1
      loop.quit
    end
    timer.start(0)
    loop.exec
    Qt::Application.process_events
    timer.active?.should be_false
    ticks.should eq(1)
  end
end

describe Qt::EventDispatcherTimerInfo do
  it "describes the timers of an object" do
    info = Qt::EventDispatcherTimerInfo.new(1, 100, Qt::TimerType::CoarseTimer)
    {info.timer_id, info.interval, info.timer_type}.should eq({1, 100, Qt::TimerType::CoarseTimer})
    info.interval = 50
    info.interval.should eq(50)

    timer = Qt::Timer.new
    timer.start(250)
    timers = Qt::AbstractEventDispatcher.instance.not_nil!.registered_timers(timer).to_a
    timers.map(&.timer_id).should eq([timer.timer_id])
    timers.first.interval.should eq(250)
    timer.stop
  end
end
