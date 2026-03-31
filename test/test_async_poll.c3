module async::poll::test;

import async::poll;
import async::event_loop;
import std::io;

// Test result tracking
struct TestContext
{
    bool success;
    bool completed;
    int call_count;
    event_loop::EventLoop* loop;
}

// ============================================================================
// Poll Handle Tests
// ============================================================================

fn void test_poll_handle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create poll handle for stdin (fd 0)
    async::poll::Poll*? poll_opt = async::poll::create(&loop, 0);
    if (catch err = poll_opt)
    {
        assert(false, "Should create poll handle");
        return;
    }
    async::poll::Poll* poll = poll_opt;

    // Basic test - just verify creation and cleanup
    assert(poll.handle != null, "Poll handle should be created");

    // Clean up
    poll.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}