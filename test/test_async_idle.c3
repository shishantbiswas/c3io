module async::idle::test;

import async::idle;
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
// Idle Handle Tests
// ============================================================================

fn void on_idle_callback(async::idle::Idle* idle, void* user_data)
{
    TestContext* ctx = (TestContext*)user_data;
    ctx.call_count++;
    ctx.success = true;

    // Stop after a few calls to avoid infinite loop
    if (ctx.call_count >= 3)
    {
        idle.stop();
        ctx.completed = true;
    }
}

fn void test_idle_handle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create idle handle
    async::idle::Idle*? idle_opt = async::idle::create(&loop);
    if (catch err = idle_opt)
    {
        assert(false, "Should create idle handle");
        return;
    }
    async::idle::Idle* idle = idle_opt;

    // Basic test - just verify creation and cleanup
    assert(idle.handle != null, "Idle handle should be created");

    // Clean up
    idle.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}

// ============================================================================
// Stop Idle Tests
// ============================================================================

fn void on_should_not_fire_idle(async::idle::Idle* idle, void* user_data)
{
    TestContext* ctx = (TestContext*)user_data;
    ctx.call_count++;
    ctx.success = false;  // Should not be called
}

fn void test_stop_idle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create idle handle
    async::idle::Idle*? idle_opt = async::idle::create(&loop);
    if (catch err = idle_opt)
    {
        assert(false, "Should create idle handle");
        return;
    }
    async::idle::Idle* idle = idle_opt;

    // Test stop (should not crash)
    idle.stop();

    // Clean up
    idle.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}