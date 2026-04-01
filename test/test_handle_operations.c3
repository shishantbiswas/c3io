module uv::handle::test;

import uv;
import async::event_loop;
import async::timer;
import async::idle;
import async::tcp;
import std::io;

// ============================================================================
// Handle Operations Tests
// ============================================================================

// Test data structure for handle_set_data/handle_get_data
struct TestData
{
    int value;
    char* name;
}

// Simple close callback that frees the handle
fn void free_handle(uv::Handle* handle)
{
    free(handle);
}

fn void test_handle_data_operations() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create a timer handle to test on
    async::timer::Timer*? timer_opt = async::timer::create(&loop);
    if (catch err = timer_opt)
    {
        assert(false, "Should create timer");
        return;
    }
    async::timer::Timer* timer = timer_opt;

    // Test handle_set_data and handle_get_data
    TestData test_data;
    test_data.value = 42;
    test_data.name = "test";

    uv::handle_set_data((uv::Handle*)timer.handle, &test_data);

    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)timer.handle);
    assert(retrieved != null, "Should retrieve data");
    assert(retrieved.value == 42, "Data value should match");
    assert(retrieved.name == "test", "Data name should match");

    // Restore timer pointer before closing (close callback expects it)
    uv::handle_set(timer.handle, timer);

    // Close timer and run loop to process close
    timer.close();
    (void)loop.run();
}

fn void test_handle_ref_unref_operations() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create a timer handle
    async::timer::Timer*? timer_opt = async::timer::create(&loop);
    if (catch err = timer_opt)
    {
        assert(false, "Should create timer");
        return;
    }
    async::timer::Timer* timer = timer_opt;

    // Initially, handle should have a reference
    int has_ref_before = uv::has_ref((uv::Handle*)timer.handle);
    assert(has_ref_before == 1, "New handle should have reference");

    // Unref the handle
    uv::unref((uv::Handle*)timer.handle);
    int has_ref_after_unref = uv::has_ref((uv::Handle*)timer.handle);
    assert(has_ref_after_unref == 0, "Handle should not have reference after unref");

    // Ref the handle again
    uv::ref((uv::Handle*)timer.handle);
    int has_ref_after_ref = uv::has_ref((uv::Handle*)timer.handle);
    assert(has_ref_after_ref == 1, "Handle should have reference after ref");

    // Close timer and run loop to process close
    timer.close();
    (void)loop.run();
}

fn void test_handle_active_closing_states() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create a timer handle
    async::timer::Timer*? timer_opt = async::timer::create(&loop);
    if (catch err = timer_opt)
    {
        assert(false, "Should create timer");
        return;
    }
    async::timer::Timer* timer = timer_opt;

    // Initially, handle should not be active
    int is_active_before = uv::is_active((uv::Handle*)timer.handle);
    assert(is_active_before == 0, "New handle should not be active");

    // Start the timer to make it active
    timer.start(1000, 0, null, null);
    int is_active_after_start = uv::is_active((uv::Handle*)timer.handle);
    assert(is_active_after_start == 1, "Handle should be active after start");

    // Stop the timer
    timer.stop();
    int is_active_after_stop = uv::is_active((uv::Handle*)timer.handle);
    assert(is_active_after_stop == 0, "Handle should not be active after stop");

    // Initially, handle should not be closing
    int is_closing_before = uv::is_closing((uv::Handle*)timer.handle);
    assert(is_closing_before == 0, "Handle should not be closing initially");

    // Close the handle
    timer.close();

    // Note: is_closing may not immediately return true, as close is async
    // We can't easily test this synchronously without callbacks

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}

// Test on different handle types
fn void test_handle_operations_on_idle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create an idle handle
    async::idle::Idle*? idle_opt = async::idle::create(&loop);
    if (catch err = idle_opt)
    {
        assert(false, "Should create idle");
        return;
    }
    async::idle::Idle* idle = idle_opt;

    // Test handle operations on idle
    int has_ref = uv::has_ref((uv::Handle*)idle.handle);
    assert(has_ref == 1, "Idle handle should have reference");

    uv::unref((uv::Handle*)idle.handle);
    has_ref = uv::has_ref((uv::Handle*)idle.handle);
    assert(has_ref == 0, "Idle handle should not have reference after unref");

    uv::ref((uv::Handle*)idle.handle);
    has_ref = uv::has_ref((uv::Handle*)idle.handle);
    assert(has_ref == 1, "Idle handle should have reference after ref");

    // Test data operations
    TestData test_data;
    test_data.value = 123;
    test_data.name = "idle_test";

    uv::handle_set_data((uv::Handle*)idle.handle, &test_data);
    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)idle.handle);
    assert(retrieved != null, "Should retrieve data from idle handle");
    assert(retrieved.value == 123, "Data value should match for idle handle");

    // Restore idle pointer before closing
    uv::handle_set(idle.handle, idle);

    // Close idle and run loop to process close
    idle.close();
    (void)loop.run();
}

fn void test_handle_operations_on_tcp() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create a TCP connection
    async::tcp::TcpConnection*? conn_opt = async::tcp::create(&loop);
    if (catch err = conn_opt)
    {
        assert(false, "Should create TCP connection");
        return;
    }
    async::tcp::TcpConnection* conn = conn_opt;

    // Test handle operations on TCP
    int has_ref = uv::has_ref((uv::Handle*)conn.handle);
    assert(has_ref != 0, "TCP handle should have reference");

    uv::unref((uv::Handle*)conn.handle);
    has_ref = uv::has_ref((uv::Handle*)conn.handle);
    assert(has_ref == 0, "TCP handle should not have reference after unref");

    uv::ref((uv::Handle*)conn.handle);
    has_ref = uv::has_ref((uv::Handle*)conn.handle);
    assert(has_ref != 0, "TCP handle should have reference after ref");

    // Test is_active (should be false for unbound TCP)
    int active = uv::is_active((uv::Handle*)conn.handle);
    assert(active == 0, "TCP handle should not be active initially");

    // Test data operations
    TestData test_data;
    test_data.value = 456;
    test_data.name = "tcp_test";

    uv::handle_set_data((uv::Handle*)conn.handle, &test_data);
    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)conn.handle);
    assert(retrieved != null, "Should retrieve data from TCP handle");
    assert(retrieved.value == 456, "Data value should match for TCP handle");

    // Restore connection pointer before closing
    uv::handle_set(conn.handle, conn);

    // Close connection and run loop to process close
    conn.close();
    (void)loop.run();
}

fn void test_handle_operations_on_udp() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create a UDP handle directly since wrapper doesn't expose it easily
    uv::Udp* udp_handle = uv::alloc_handle(uv::Udp, uv::HandleType.UDP);
    int result = uv::udp_init(loop.loop, udp_handle);
    if (result != 0)
    {
        free(udp_handle);
        assert(false, "Should initialize UDP handle");
        return;
    }

    // Test handle operations on UDP
    int has_ref = uv::has_ref((uv::Handle*)udp_handle);
    assert(has_ref != 0, "UDP handle should have reference");

    uv::unref((uv::Handle*)udp_handle);
    has_ref = uv::has_ref((uv::Handle*)udp_handle);
    assert(has_ref == 0, "UDP handle should not have reference after unref");

    uv::ref((uv::Handle*)udp_handle);
    has_ref = uv::has_ref((uv::Handle*)udp_handle);
    assert(has_ref != 0, "UDP handle should have reference after ref");

    // Test is_active
    int active = uv::is_active((uv::Handle*)udp_handle);
    assert(active == 0, "UDP handle should not be active initially");

    // Test data operations
    TestData test_data;
    test_data.value = 789;
    test_data.name = "udp_test";

    uv::handle_set_data((uv::Handle*)udp_handle, &test_data);
    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)udp_handle);
    assert(retrieved != null, "Should retrieve data from UDP handle");
    assert(retrieved.value == 789, "Data value should match for UDP handle");

    // Close handle
    uv::close((uv::Handle*)udp_handle, &free_handle);
    (void)loop.run(); // Process close

    assert(true, "UDP handle operations test passed");
}

fn void test_handle_operations_on_prepare() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create a prepare handle directly
    uv::Prepare* prepare_handle = uv::alloc_handle(uv::Prepare, uv::HandleType.PREPARE);
    int result = uv::prepare_init(loop.loop, prepare_handle);
    if (result != 0)
    {
        free(prepare_handle);
        assert(false, "Should initialize prepare handle");
        return;
    }

    // Test handle operations on prepare
    int has_ref = uv::has_ref((uv::Handle*)prepare_handle);
    assert(has_ref != 0, "Prepare handle should have reference");

    uv::unref((uv::Handle*)prepare_handle);
    has_ref = uv::has_ref((uv::Handle*)prepare_handle);
    assert(has_ref == 0, "Prepare handle should not have reference after unref");

    uv::ref((uv::Handle*)prepare_handle);
    has_ref = uv::has_ref((uv::Handle*)prepare_handle);
    assert(has_ref != 0, "Prepare handle should have reference after ref");

    // Test is_active
    int active = uv::is_active((uv::Handle*)prepare_handle);
    assert(active == 0, "Prepare handle should not be active initially");

    // Test data operations
    TestData test_data;
    test_data.value = 111;
    test_data.name = "prepare_test";

    uv::handle_set_data((uv::Handle*)prepare_handle, &test_data);
    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)prepare_handle);
    assert(retrieved != null, "Should retrieve data from prepare handle");
    assert(retrieved.value == 111, "Data value should match for prepare handle");

    // Close handle
    uv::close((uv::Handle*)prepare_handle, &free_handle);
    (void)loop.run();

    assert(true, "Prepare handle operations test passed");
}

fn void test_handle_operations_on_check() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create a check handle directly
    uv::Check* check_handle = uv::alloc_handle(uv::Check, uv::HandleType.CHECK);
    int result = uv::check_init(loop.loop, check_handle);
    if (result != 0)
    {
        free(check_handle);
        assert(false, "Should initialize check handle");
        return;
    }

    // Test handle operations on check
    int has_ref = uv::has_ref((uv::Handle*)check_handle);
    assert(has_ref != 0, "Check handle should have reference");

    uv::unref((uv::Handle*)check_handle);
    has_ref = uv::has_ref((uv::Handle*)check_handle);
    assert(has_ref == 0, "Check handle should not have reference after unref");

    uv::ref((uv::Handle*)check_handle);
    has_ref = uv::has_ref((uv::Handle*)check_handle);
    assert(has_ref != 0, "Check handle should have reference after ref");

    // Test is_active
    int active = uv::is_active((uv::Handle*)check_handle);
    assert(active == 0, "Check handle should not be active initially");

    // Test data operations
    TestData test_data;
    test_data.value = 222;
    test_data.name = "check_test";

    uv::handle_set_data((uv::Handle*)check_handle, &test_data);
    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)check_handle);
    assert(retrieved != null, "Should retrieve data from check handle");
    assert(retrieved.value == 222, "Data value should match for check handle");

    // Close handle
    uv::close((uv::Handle*)check_handle, &free_handle);
    (void)loop.run();

    assert(true, "Check handle operations test passed");
}

fn void test_handle_operations_on_async() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create an async handle directly
    uv::Async* async_handle = uv::alloc_handle(uv::Async, uv::HandleType.ASYNC);
    int result = uv::async_init(loop.loop, async_handle, null);
    if (result != 0)
    {
        free(async_handle);
        assert(false, "Should initialize async handle");
        return;
    }

    // Test handle operations on async
    int has_ref = uv::has_ref((uv::Handle*)async_handle);
    assert(has_ref != 0, "Async handle should have reference");

    uv::unref((uv::Handle*)async_handle);
    has_ref = uv::has_ref((uv::Handle*)async_handle);
    assert(has_ref == 0, "Async handle should not have reference after unref");

    uv::ref((uv::Handle*)async_handle);
    has_ref = uv::has_ref((uv::Handle*)async_handle);
    assert(has_ref != 0, "Async handle should have reference after ref");

    // Test is_active - async handle is active immediately after init
    int active = uv::is_active((uv::Handle*)async_handle);
    assert(active != 0, "Async handle is active after init");

    // Test data operations
    TestData test_data;
    test_data.value = 333;
    test_data.name = "async_test";

    uv::handle_set_data((uv::Handle*)async_handle, &test_data);
    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)async_handle);
    assert(retrieved != null, "Should retrieve data from async handle");
    assert(retrieved.value == 333, "Data value should match for async handle");

    // Close handle
    uv::close((uv::Handle*)async_handle, &free_handle);
    (void)loop.run();

    assert(true, "Async handle operations test passed");
}

fn void test_handle_operations_on_poll() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create a poll handle directly (watching stdin)
    uv::Poll* poll_handle = uv::alloc_handle(uv::Poll, uv::HandleType.POLL);
    int result = uv::poll_init(loop.loop, poll_handle, 0); // stdin
    if (result != 0)
    {
        free(poll_handle);
        // Poll on stdin may not be permitted in all environments
        io::printfn("Warning: Could not init poll handle: %s", (ZString)uv::strerror(result));
        assert(true, "Poll handle init skipped gracefully");
        return;
    }

    // Test handle operations on poll
    int has_ref = uv::has_ref((uv::Handle*)poll_handle);
    assert(has_ref != 0, "Poll handle should have reference");

    uv::unref((uv::Handle*)poll_handle);
    has_ref = uv::has_ref((uv::Handle*)poll_handle);
    assert(has_ref == 0, "Poll handle should not have reference after unref");

    uv::ref((uv::Handle*)poll_handle);
    has_ref = uv::has_ref((uv::Handle*)poll_handle);
    assert(has_ref != 0, "Poll handle should have reference after ref");

    // Test is_active
    int active = uv::is_active((uv::Handle*)poll_handle);
    assert(active == 0, "Poll handle should not be active initially");

    // Test data operations
    TestData test_data;
    test_data.value = 444;
    test_data.name = "poll_test";

    uv::handle_set_data((uv::Handle*)poll_handle, &test_data);
    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)poll_handle);
    assert(retrieved != null, "Should retrieve data from poll handle");
    assert(retrieved.value == 444, "Data value should match for poll handle");

    // Close handle
    uv::close((uv::Handle*)poll_handle, &free_handle);
    (void)loop.run();

    assert(true, "Poll handle operations test passed");
}

fn void test_handle_operations_on_signal() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create a signal handle directly
    uv::Signal* signal_handle = uv::alloc_handle(uv::Signal, uv::HandleType.SIGNAL);
    int result = uv::signal_init(loop.loop, signal_handle);
    if (result != 0)
    {
        free(signal_handle);
        assert(false, "Should initialize signal handle");
        return;
    }

    // Test handle operations on signal
    int has_ref = uv::has_ref((uv::Handle*)signal_handle);
    assert(has_ref != 0, "Signal handle should have reference");

    uv::unref((uv::Handle*)signal_handle);
    has_ref = uv::has_ref((uv::Handle*)signal_handle);
    assert(has_ref == 0, "Signal handle should not have reference after unref");

    uv::ref((uv::Handle*)signal_handle);
    has_ref = uv::has_ref((uv::Handle*)signal_handle);
    assert(has_ref != 0, "Signal handle should have reference after ref");

    // Test is_active
    int active = uv::is_active((uv::Handle*)signal_handle);
    assert(active == 0, "Signal handle should not be active initially");

    // Test data operations
    TestData test_data;
    test_data.value = 555;
    test_data.name = "signal_test";

    uv::handle_set_data((uv::Handle*)signal_handle, &test_data);
    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)signal_handle);
    assert(retrieved != null, "Should retrieve data from signal handle");
    assert(retrieved.value == 555, "Data value should match for signal handle");

    // Close handle
    uv::close((uv::Handle*)signal_handle, &free_handle);
    (void)loop.run();

    assert(true, "Signal handle operations test passed");
}

fn void test_handle_operations_on_pipe() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create a pipe handle directly
    uv::Pipe* pipe_handle = uv::alloc_handle(uv::Pipe, uv::HandleType.NAMED_PIPE);
    int result = uv::pipe_init(loop.loop, pipe_handle, 0);
    if (result != 0)
    {
        free(pipe_handle);
        assert(false, "Should initialize pipe handle");
        return;
    }

    // Test handle operations on pipe
    int has_ref = uv::has_ref((uv::Handle*)pipe_handle);
    assert(has_ref != 0, "Pipe handle should have reference");

    uv::unref((uv::Handle*)pipe_handle);
    has_ref = uv::has_ref((uv::Handle*)pipe_handle);
    assert(has_ref == 0, "Pipe handle should not have reference after unref");

    uv::ref((uv::Handle*)pipe_handle);
    has_ref = uv::has_ref((uv::Handle*)pipe_handle);
    assert(has_ref != 0, "Pipe handle should have reference after ref");

    // Test is_active
    int active = uv::is_active((uv::Handle*)pipe_handle);
    assert(active == 0, "Pipe handle should not be active initially");

    // Test data operations
    TestData test_data;
    test_data.value = 666;
    test_data.name = "pipe_test";

    uv::handle_set_data((uv::Handle*)pipe_handle, &test_data);
    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)pipe_handle);
    assert(retrieved != null, "Should retrieve data from pipe handle");
    assert(retrieved.value == 666, "Data value should match for pipe handle");

    // Close handle
    uv::close((uv::Handle*)pipe_handle, &free_handle);
    (void)loop.run();

    assert(true, "Pipe handle operations test passed");
}

fn void test_handle_operations_on_tty() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create a TTY handle for stdout
    uv::Tty* tty_handle = uv::alloc_handle(uv::Tty, uv::HandleType.TTY);
    int result = uv::tty_init(loop.loop, tty_handle, 1, 0); // stdout, writable
    if (result != 0)
    {
        free(tty_handle);
        assert(false, "Should initialize TTY handle");
        return;
    }

    // Test handle operations on tty
    int has_ref = uv::has_ref((uv::Handle*)tty_handle);
    assert(has_ref != 0, "TTY handle should have reference");

    uv::unref((uv::Handle*)tty_handle);
    has_ref = uv::has_ref((uv::Handle*)tty_handle);
    assert(has_ref == 0, "TTY handle should not have reference after unref");

    uv::ref((uv::Handle*)tty_handle);
    has_ref = uv::has_ref((uv::Handle*)tty_handle);
    assert(has_ref != 0, "TTY handle should have reference after ref");

    // Test is_active
    int active = uv::is_active((uv::Handle*)tty_handle);
    assert(active == 0, "TTY handle should not be active initially");

    // Test data operations
    TestData test_data;
    test_data.value = 777;
    test_data.name = "tty_test";

    uv::handle_set_data((uv::Handle*)tty_handle, &test_data);
    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)tty_handle);
    assert(retrieved != null, "Should retrieve data from TTY handle");
    assert(retrieved.value == 777, "Data value should match for TTY handle");

    // Close handle
    uv::close((uv::Handle*)tty_handle, &free_handle);
    (void)loop.run();

    assert(true, "TTY handle operations test passed");
}

fn void test_handle_operations_on_fs_event() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create an FS event handle
    uv::FSEvent* fs_event_handle = uv::alloc_handle(uv::FSEvent, uv::HandleType.FS_EVENT);
    int result = uv::fs_event_init(loop.loop, fs_event_handle);
    if (result != 0)
    {
        free(fs_event_handle);
        assert(false, "Should initialize FS event handle");
        return;
    }

    // Test handle operations on fs_event
    int has_ref = uv::has_ref((uv::Handle*)fs_event_handle);
    assert(has_ref != 0, "FS event handle should have reference");

    uv::unref((uv::Handle*)fs_event_handle);
    has_ref = uv::has_ref((uv::Handle*)fs_event_handle);
    assert(has_ref == 0, "FS event handle should not have reference after unref");

    uv::ref((uv::Handle*)fs_event_handle);
    has_ref = uv::has_ref((uv::Handle*)fs_event_handle);
    assert(has_ref != 0, "FS event handle should have reference after ref");

    // Test is_active
    int active = uv::is_active((uv::Handle*)fs_event_handle);
    assert(active == 0, "FS event handle should not be active initially");

    // Test data operations
    TestData test_data;
    test_data.value = 888;
    test_data.name = "fs_event_test";

    uv::handle_set_data((uv::Handle*)fs_event_handle, &test_data);
    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)fs_event_handle);
    assert(retrieved != null, "Should retrieve data from FS event handle");
    assert(retrieved.value == 888, "Data value should match for FS event handle");

    // Close handle
    uv::close((uv::Handle*)fs_event_handle, &free_handle);
    (void)loop.run();

    assert(true, "FS event handle operations test passed");
}

fn void test_handle_operations_on_fs_poll() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create an FS poll handle
    uv::FSPoll* fs_poll_handle = uv::alloc_handle(uv::FSPoll, uv::HandleType.FS_POLL);
    int result = uv::fs_poll_init(loop.loop, fs_poll_handle);
    if (result != 0)
    {
        free(fs_poll_handle);
        assert(false, "Should initialize FS poll handle");
        return;
    }

    // Test handle operations on fs_poll
    int has_ref = uv::has_ref((uv::Handle*)fs_poll_handle);
    assert(has_ref != 0, "FS poll handle should have reference");

    uv::unref((uv::Handle*)fs_poll_handle);
    has_ref = uv::has_ref((uv::Handle*)fs_poll_handle);
    assert(has_ref == 0, "FS poll handle should not have reference after unref");

    uv::ref((uv::Handle*)fs_poll_handle);
    has_ref = uv::has_ref((uv::Handle*)fs_poll_handle);
    assert(has_ref != 0, "FS poll handle should have reference after ref");

    // Test is_active
    int active = uv::is_active((uv::Handle*)fs_poll_handle);
    assert(active == 0, "FS poll handle should not be active initially");

    // Test data operations
    TestData test_data;
    test_data.value = 999;
    test_data.name = "fs_poll_test";

    uv::handle_set_data((uv::Handle*)fs_poll_handle, &test_data);
    TestData* retrieved = (TestData*)uv::handle_get_data((uv::Handle*)fs_poll_handle);
    assert(retrieved != null, "Should retrieve data from FS poll handle");
    assert(retrieved.value == 999, "Data value should match for FS poll handle");

    // Close handle
    uv::close((uv::Handle*)fs_poll_handle, &free_handle);
    (void)loop.run();

    assert(true, "FS poll handle operations test passed");
}