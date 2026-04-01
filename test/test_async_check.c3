module async::check::test;

import async::check;
import async::timer;
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
// Check Handle Tests
// ============================================================================

fn void test_check_handle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create check handle
    async::check::Check*? check_opt = async::check::create(&loop);
    if (catch err = check_opt)
    {
        assert(false, "Should create check handle");
        return;
    }
    async::check::Check* check = check_opt;

    // Basic test - just verify creation and cleanup
    assert(check.handle != null, "Check handle should be created");

    // Clean up
    check.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}

// ============================================================================
// Stop Check Tests
// ============================================================================

fn void on_should_not_fire_check(async::check::Check* check, void* user_data)
{
    TestContext* ctx = (TestContext*)user_data;
    ctx.call_count++;
    ctx.success = false;  // Should not be called
}

fn void test_stop_check() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create check handle
    async::check::Check*? check_opt = async::check::create(&loop);
    if (catch err = check_opt)
    {
        assert(false, "Should create check handle");
        return;
    }
    async::check::Check* check = check_opt;

    // Test stop (should not crash)
    check.stop();

    // Clean up
    check.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}

// ============================================================================
// Start Check Tests - Test that check callback actually fires
// ============================================================================

fn void on_check_callback(async::check::Check* check, void* user_data)
{
    TestContext* ctx = (TestContext*)user_data;
    ctx.call_count++;
    ctx.success = true;

    // Stop after a few calls to avoid infinite loop
    if (ctx.call_count >= 3)
    {
        check.stop();
        ctx.completed = true;
    }
}

fn void on_timer_for_check(async::timer::Timer* timer, void* user_data)
{
    // Timer callback - just keep the loop running
    // This will cause I/O polling to happen, allowing check callbacks to fire
}

fn void test_start_check() @test
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

    // Create check handle
    async::check::Check*? check_opt = async::check::create(&loop);
    if (catch err = check_opt)
    {
        assert(false, "Should create check handle");
        return;
    }
    async::check::Check* check = check_opt;

    // Create a timer to generate I/O polling activity
    async::timer::Timer*? timer_opt = async::timer::create(&loop);
    if (catch err = timer_opt)
    {
        assert(false, "Should create timer");
        check.close();
        return;
    }
    async::timer::Timer* timer = timer_opt;

    // Start the check handle
    check.start(&on_check_callback, &ctx);

    // Start a repeating timer to keep the loop active and generate polling
    timer.start(10, 10, &on_timer_for_check, null);

    // Run event loop until check callback fires enough times
    while (!ctx.completed)
    {
        loop.run_once();
    }

    assert(ctx.success, "Check callback should fire");
    assert(ctx.call_count >= 3, "Check callback should fire at least 3 times");

    // Stop and clean up
    check.stop();
    timer.stop();
    check.close();
    timer.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}

// ============================================================================
// Multiple Check Handles Tests
// ============================================================================

struct MultiCheckContext
{
    int check1_count;
    int check2_count;
    bool completed;
    event_loop::EventLoop* loop;
}

fn void on_multi_check1(async::check::Check* check, void* user_data)
{
    MultiCheckContext* ctx = (MultiCheckContext*)user_data;
    ctx.check1_count++;

    if (ctx.check1_count >= 2 && ctx.check2_count >= 2)
    {
        ctx.completed = true;
        check.stop();
    }
}

fn void on_multi_check2(async::check::Check* check, void* user_data)
{
    MultiCheckContext* ctx = (MultiCheckContext*)user_data;
    ctx.check2_count++;

    if (ctx.check1_count >= 2 && ctx.check2_count >= 2)
    {
        ctx.completed = true;
        check.stop();
    }
}

fn void test_multiple_checks() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create two check handles
    async::check::Check*? check1_opt = async::check::create(&loop);
    if (catch err = check1_opt)
    {
        assert(false, "Should create check1");
        return;
    }
    async::check::Check* check1 = check1_opt;

    async::check::Check*? check2_opt = async::check::create(&loop);
    if (catch err = check2_opt)
    {
        assert(false, "Should create check2");
        return;
    }
    async::check::Check* check2 = check2_opt;

    // Test that multiple handles can be created and cleaned up
    assert(check1.handle != null, "Check1 should be created");
    assert(check2.handle != null, "Check2 should be created");

    // Clean up
    check1.close();
    check2.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}