module async::tty::test;

import async::tty;
import async::event_loop;
import std::io;

// ============================================================================
// TTY Handle Tests
// ============================================================================

fn void test_tty_handle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create TTY handle for stdout
    async::tty::Tty*? tty_opt = async::tty::create(&loop, 1, false);
    if (catch err = tty_opt)
    {
        assert(false, "Should create TTY handle");
        return;
    }
    async::tty::Tty* tty = tty_opt;

    // Test getting window size
    int width, height;
    int result = tty.get_winsize(&width, &height);

    if (result == 0)
    {
        assert(width > 0, "Width should be positive");
        assert(height > 0, "Height should be positive");
    }
    else
    {
        // Window size might not be available in all environments
        io::printfn("TTY window size not available (expected in some environments)");
    }

    // Test setting mode (this might fail in some environments)
    tty.set_mode(async::tty::TTY_MODE_RAW);
    tty.set_mode(async::tty::TTY_MODE_NORMAL);

    // Reset mode before closing
    async::tty::reset_mode();

    // Clean up
    tty.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}