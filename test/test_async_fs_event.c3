module async::fs_event::test;

import async::fs_event;
import async::event_loop;
import std::io;

// ============================================================================
// FS Event Handle Tests
// ============================================================================

fn void on_fs_event_callback(async::fs_event::FsEvent* fs_event, char* filename, int events, int status, void* user_data)
{
    if (status == 0 && filename != null)
    {
        io::printfn("FS event: %s", filename);
    }
}

fn void test_fs_event_handle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create FS event handle
    async::fs_event::FsEvent*? fs_event_opt = async::fs_event::create(&loop);
    if (catch err = fs_event_opt)
    {
        assert(false, "Should create FS event handle");
        return;
    }
    async::fs_event::FsEvent* fs_event = fs_event_opt;

    // Basic test - just verify creation and cleanup
    assert(fs_event.handle != null, "FS event handle should be created");

    // Clean up
    fs_event.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}