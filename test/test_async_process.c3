module async::process::test;

import async::process;
import async::event_loop;
import std::io;

// ============================================================================
// Process Handle Tests
// ============================================================================

fn void on_process_exit(async::process::Process* process, long exit_status, int term_signal, void* user_data)
{
    io::printfn("Process exited with status: %d, signal: %d", (int)exit_status, term_signal);
}

fn void test_process_handle() @test
{
    EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }
    EventLoop loop = loop_opt;
    defer loop.free();

    // Create process handle
    async::process::Process*? process_opt = async::process::create(&loop);
    if (catch err = process_opt)
    {
        assert(false, "Should create process handle");
        return;
    }
    async::process::Process* process = process_opt;

    // Note: Full process spawning is complex and not implemented in this basic test
    // In a real implementation, you would set up ProcessOptions with file, args, etc.

    // Test getting PID (should be 0 for unspawned process)
    int pid = process.get_pid();
    assert(pid == 0, "Unspawned process should have PID 0");

    // Clean up (for unspawned process, this just frees memory)
    process.close();
}