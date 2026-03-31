module async::prepare::test;

import async::prepare;
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
// Prepare Handle Tests
// ============================================================================

fn void on_prepare_callback(async::prepare::Prepare* prepare, void* user_data)
{
    TestContext* ctx = (TestContext*)user_data;
    ctx.call_count++;
    ctx.success = true;

    // Stop after a few calls to avoid infinite loop
    if (ctx.call_count >= 3)
    {
        prepare.stop();
        ctx.completed = true;
    }
}

fn void test_prepare_handle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create prepare handle
    async::prepare::Prepare*? prepare_opt = async::prepare::create(&loop);
    if (catch err = prepare_opt)
    {
        assert(false, "Should create prepare handle");
        return;
    }
    async::prepare::Prepare* prepare = prepare_opt;

    // Basic test - just verify creation and cleanup
    assert(prepare.handle != null, "Prepare handle should be created");

    // Clean up
    prepare.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}

// ============================================================================
// Stop Prepare Tests
// ============================================================================

fn void on_should_not_fire(async::prepare::Prepare* prepare, void* user_data)
{
    TestContext* ctx = (TestContext*)user_data;
    ctx.call_count++;
    ctx.success = false;  // Should not be called
}

fn void test_stop_prepare() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create prepare handle
    async::prepare::Prepare*? prepare_opt = async::prepare::create(&loop);
    if (catch err = prepare_opt)
    {
        assert(false, "Should create prepare handle");
        return;
    }
    async::prepare::Prepare* prepare = prepare_opt;

    // Test stop (should not crash)
    prepare.stop();

    // Clean up
    prepare.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}
// ============================================================================
// Multiple Prepare Handles Tests
// ============================================================================

struct MultiPrepareContext
{
    int prepare1_count;
    int prepare2_count;
    bool completed;
    event_loop::EventLoop* loop;
}

fn void on_multi_prepare1(async::prepare::Prepare* prepare, void* user_data)
{
    MultiPrepareContext* ctx = (MultiPrepareContext*)user_data;
    ctx.prepare1_count++;

    if (ctx.prepare1_count >= 2 && ctx.prepare2_count >= 2)
    {
        ctx.completed = true;
        prepare.stop();
    }
}

fn void on_multi_prepare2(async::prepare::Prepare* prepare, void* user_data)
{
    MultiPrepareContext* ctx = (MultiPrepareContext*)user_data;
    ctx.prepare2_count++;

    if (ctx.prepare1_count >= 2 && ctx.prepare2_count >= 2)
    {
        ctx.completed = true;
        prepare.stop();
    }
}

fn void test_multiple_prepares() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create two prepare handles
    async::prepare::Prepare*? prepare1_opt = async::prepare::create(&loop);
    if (catch err = prepare1_opt)
    {
        assert(false, "Should create prepare1");
        return;
    }
    async::prepare::Prepare* prepare1 = prepare1_opt;

    async::prepare::Prepare*? prepare2_opt = async::prepare::create(&loop);
    if (catch err = prepare2_opt)
    {
        assert(false, "Should create prepare2");
        return;
    }
    async::prepare::Prepare* prepare2 = prepare2_opt;

    // Test that multiple handles can be created and cleaned up
    assert(prepare1.handle != null, "Prepare1 should be created");
    assert(prepare2.handle != null, "Prepare2 should be created");

    // Clean up
    prepare1.close();
    prepare2.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}