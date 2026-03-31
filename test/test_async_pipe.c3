module async::pipe::test;

import async::pipe;
import async::event_loop;
import uv;
import std::io;

// ============================================================================
// Pipe Handle Tests
// ============================================================================

fn void test_pipe_handle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create pipe handle
    async::pipe::Pipe*? pipe_opt = async::pipe::create(&loop, false);
    if (catch err = pipe_opt)
    {
        assert(false, "Should create pipe handle");
        return;
    }
    async::pipe::Pipe* pipe = pipe_opt;

    // Test binding to a socket path (might fail if path exists)
    int result = pipe.bind("/tmp/test_pipe.socket");
    if (result != 0)
    {
        io::printfn("Pipe bind failed (expected if socket exists): %s", (ZString)uv::strerror(result));
    }

    // Clean up
    pipe.close();

    // Run loop until close completes
    while (loop.is_alive())
    {
        loop.run_once();
    }
}