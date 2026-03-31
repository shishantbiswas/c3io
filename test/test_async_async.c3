module async::async::test;

import async::async;
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
// Async Handle Tests
// ============================================================================

fn void on_async_callback(async::async::Async* async, void* user_data)
{
    TestContext* ctx = (TestContext*)user_data;
    ctx.call_count++;
    ctx.success = true;
    ctx.completed = true;
}

fn void test_async_handle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    TestContext ctx;
    ctx.success = false;
    ctx.completed = false;
    ctx.call_count = 0;
    ctx.loop = &loop;

    // Create async handle
    async::async::Async*? async_opt = async::async::create(&loop);
    if (catch err = async_opt)
    {
        assert(false, "Should create async handle");
        return;
    }
    async::async::Async* async = async_opt;

    // Start async handle
    async.start(&on_async_callback, &ctx);

    // Send async signal
    async.send();

    // Run event loop until async fires or timeout
    for (int i = 0; i < 100 && !ctx.completed; i++)
    {
        loop.run_once();
    }

    assert(ctx.success, "Async handle should fire");
    assert(ctx.call_count == 1, "Async should fire exactly once");

    // Clean up
    async.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}