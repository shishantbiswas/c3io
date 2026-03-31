module async::fs_poll::test;

import async::fs_poll;
import async::event_loop;
import uv;
import std::io;

// ============================================================================
// FS Poll Handle Tests
// ============================================================================

fn void on_fs_poll_callback(async::fs_poll::FsPoll* fs_poll, int status, uv::FileStat* prev, uv::FileStat* curr, void* user_data)
{
    if (status == 0)
    {
        io::printfn("FS poll detected change");
    }
}

fn void test_fs_poll_handle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create FS poll handle
    async::fs_poll::FsPoll*? fs_poll_opt = async::fs_poll::create(&loop);
    if (catch err = fs_poll_opt)
    {
        assert(false, "Should create FS poll handle");
        return;
    }
    async::fs_poll::FsPoll* fs_poll = fs_poll_opt;

    // Basic test - just verify creation and cleanup
    assert(fs_poll.handle != null, "FS poll handle should be created");

    // Clean up
    fs_poll.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}