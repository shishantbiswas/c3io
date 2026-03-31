module async::signal::test;

import async::signal;
import async::event_loop;
import std::io;

// Test result tracking
struct TestContext
{
    bool success;
    bool completed;
    int call_count;
    int received_signum;
    event_loop::EventLoop* loop;
}

// ============================================================================
// Signal Handle Tests
// ============================================================================

fn void test_signal_handle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create signal handle
    async::signal::Signal*? signal_opt = async::signal::create(&loop);
    if (catch err = signal_opt)
    {
        assert(false, "Should create signal handle");
        return;
    }
    async::signal::Signal* signal = signal_opt;

    // Basic test - just verify creation and cleanup
    assert(signal.handle != null, "Signal handle should be created");

    // Clean up
    signal.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}