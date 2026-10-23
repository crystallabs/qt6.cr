require "../spec_helper"

# Qt threads must not call into Crystal (see the README), so these only
# construct, start and wait for threads running Qt code.
describe Qt::Thread do
  it "runs an event loop" do
    main = Qt::Thread.current_thread.not_nil!
    {% if Qt::QT_VERSION >= 0x060800 %}
      main.current_thread?.should be_true
      Qt::Thread.main_thread?.should be_true
    {% end %}
    Qt::Thread.ideal_thread_count.should be > 0

    thread = Qt::Thread.new
    thread.running?.should be_false
    thread.finished?.should be_false
    main_thread_id = Qt::Thread.current_thread_id
    started_in = Pointer(Void).null
    thread.on_started { started_in = Qt::Thread.current_thread_id }
    thread.start
    thread.running?.should be_true
    {% if Qt::QT_VERSION >= 0x060800 %}
      thread.current_thread?.should be_false
    {% end %}
    thread.interruption_requested?.should be_false
    thread.quit
    thread.wait.should be_true
    thread.finished?.should be_true
    thread.running?.should be_false
    # The started signal is queued to the main thread: delivered by the
    # event loop, not from the Qt thread.
    started_in.should eq(Pointer(Void).null)
    Qt::CoreApplication.process_events
    started_in.should eq(main_thread_id)
    {% if Qt::QT_VERSION >= 0x060600 %}
      Qt::Thread.sleep(1.millisecond)
    {% else %}
      Qt::Thread.msleep(1) # The duration overload is Qt 6.6+
    {% end %}
  end
end

describe Qt::ThreadPool do
  it "is configured" do
    pool = Qt::ThreadPool.new
    pool.max_thread_count.should eq(Qt::Thread.ideal_thread_count)
    pool.max_thread_count = 2
    pool.max_thread_count.should eq(2)
    pool.active_thread_count.should eq(0)
    pool.expiry_timeout = 1000
    pool.expiry_timeout.should eq(1000)
    pool.wait_for_done.should be_true
    Qt::ThreadPool.global_instance.not_nil!.max_thread_count.should be > 0
  end
end

describe Qt::Mutex do
  it "locks" do
    mutex = Qt::Mutex.new
    mutex.try_lock.should be_true
    mutex.try_lock(10).should be_false
    mutex.try_lock_for(10.milliseconds).should be_false # Declared: a template
    mutex.unlock
    mutex.try_lock_for(10.milliseconds).should be_true
    mutex.unlock
    mutex.lock
    mutex.unlock

    recursive = Qt::RecursiveMutex.new
    recursive.lock
    recursive.try_lock.should be_true
    recursive.unlock
    recursive.unlock

    lock = Qt::ReadWriteLock.new
    lock.try_lock_for_read.should be_true
    lock.try_lock_for_write.should be_false
    lock.unlock
    lock.lock_for_write
    lock.unlock
  end
end

describe Qt::Semaphore do
  it "counts" do
    semaphore = Qt::Semaphore.new(2)
    semaphore.available.should eq(2)
    semaphore.acquire
    semaphore.try_acquire(2).should be_false
    semaphore.try_acquire(1, 10).should be_true
    semaphore.available.should eq(0)
    semaphore.release(3)
    semaphore.available.should eq(3)
    releaser = Qt::SemaphoreReleaser.new(semaphore, 2)
    releaser.semaphore.not_nil!.to_unsafe.should eq(semaphore.to_unsafe)
    releaser.cancel.not_nil!.to_unsafe.should eq(semaphore.to_unsafe)

    condition = Qt::WaitCondition.new
    mutex = Qt::Mutex.new
    mutex.lock
    condition.wait(mutex, Qt::DeadlineTimer.new(1_i64)).should be_false
    mutex.unlock
    condition.wake_all
  end
end

describe Qt::SharedMemory do
  it "creates and attaches a segment" do
    key = "qt6cr-spec-#{::Process.pid}"
    memory = Qt::SharedMemory.new(key)
    memory.key.should eq(key)
    {% if Qt::QT_VERSION >= 0x060600 %}
      memory.native_ipc_key.valid?.should be_true
    {% end %}
    memory.attached?.should be_false
    memory.create(64).should be_true
    memory.error.should eq(Qt::SharedMemory::SharedMemoryError::NoError)
    memory.attached?.should be_true
    memory.size.should be >= 64
    memory.lock.should be_true
    memory.data.as(UInt8*)[0] = 42_u8
    memory.unlock.should be_true

    other = {% if Qt::QT_VERSION >= 0x060600 %} Qt::SharedMemory.new(memory.native_ipc_key) {% else %} Qt::SharedMemory.new(key) {% end %}
    other.attach(Qt::SharedMemory::AccessMode::ReadOnly).should be_true
    other.const_data.as(UInt8*)[0].should eq(42)
    other.detach.should be_true
    memory.detach.should be_true
    memory.attached?.should be_false

    missing = Qt::SharedMemory.new("qt6cr-spec-missing-#{::Process.pid}")
    missing.attach.should be_false
    missing.error.should eq(Qt::SharedMemory::SharedMemoryError::NotFound)
    missing.error_string.should_not eq("")
  end
end

describe Qt::SystemSemaphore do
  it "acquires and releases" do
    # QNativeIpcKey is Qt 6.6+; older Qt keys the semaphore by a string.
    key = {% if Qt::QT_VERSION >= 0x060600 %} Qt::NativeIpcKey.new("qt6cr-spec-#{::Process.pid}") {% else %} "qt6cr-spec-#{::Process.pid}" {% end %}
    semaphore = Qt::SystemSemaphore.new(key, 1, Qt::SystemSemaphore::AccessMode::Create)
    semaphore.error.should eq(Qt::SystemSemaphore::SystemSemaphoreError::NoError)
    {% if Qt::QT_VERSION >= 0x060600 %}
      semaphore.native_ipc_key.should eq(key)
    {% end %}
    semaphore.acquire.should be_true
    semaphore.release.should be_true
  end
end

{% if Qt::QT_VERSION >= 0x060600 %}
  describe Qt::NativeIpcKey do
    it "names a key" do
      key = Qt::NativeIpcKey.new("spec", Qt::NativeIpcKey::Type::PosixRealtime)
      key.valid?.should be_true
      key.native_key.should eq("spec")
      key.type.should eq(Qt::NativeIpcKey::Type::PosixRealtime)
      Qt::NativeIpcKey.from_string(key.to_string).should eq(key)
      Qt::NativeIpcKey.new.empty?.should be_true
      Qt::SharedMemory.platform_safe_key("spec").valid?.should be_true
    end
  end
{% end %}
