module async::process;

import uv;
import std::io;
import async::event_loop;

/*
  Async Process Handle Wrapper for libuv
  =======================================
  Provides async process spawning using libuv's process API.

  Process handles allow spawning and managing child processes.
  Useful for running external commands asynchronously.

  Usage:
    Process* process = async::process::create(loop);
    ProcessOptions options = {
        .file = "ls",
        .args = ["ls", "-la"],
        .exit_cb = &on_exit
    };
    process.spawn(&options);
    // Later:
    process.close();
*/

// Faults
faultdef PROCESS_INIT_FAILED;
faultdef PROCESS_SPAWN_FAILED;

// Process exit callback
alias ProcessExitCallback = fn void(Process* process, long exit_status, int term_signal, void* user_data);

// Process options structure (simplified)
struct ProcessOptions
{
    char* file;           // Executable path
    char** args;          // Arguments array (null-terminated)
    char** env;           // Environment variables (null-terminated)
    char* cwd;            // Working directory
    int flags;            // Spawn flags
    int stdio_count;      // Number of stdio handles
    StdioContainer* stdio; // Stdio handles
    ProcessExitCallback exit_cb; // Exit callback
    void* user_data;      // User data for callbacks
}

// Stdio container (simplified)
struct StdioContainer
{
    int flags;
    uv::Handle* handle;   // For stream handles
}

/*
  Process handle.
  Wraps a libuv process handle for managing child processes.
*/
struct Process
{
    uv::Process* handle;
    event_loop::EventLoop* loop;
    ProcessExitCallback exit_cb;
    void* user_data;
}

// Internal libuv callback wrappers
fn void on_exit_internal(uv::Process* handle, long exit_status, int term_signal)
{
    Process* process = uv::handle_get(Process, handle);

    if (process.exit_cb)
    {
        process.exit_cb(process, exit_status, term_signal, process.user_data);
    }
}

fn void on_close_internal(uv::Handle* handle)
{
    // Get process from handle and free both
    Process* process = uv::handle_get(Process, handle);
    free(handle);
    if (process != null)
    {
        free(process);
    }
}

/*
  Create a new process handle.

  @param loop : "Event loop to attach to"
*/
fn Process*? create(event_loop::EventLoop* loop)
{
    // Allocate process handle
    uv::Process* handle = uv::alloc_handle(uv::Process, uv::HandleType.PROCESS);

    Process* process = mem::new(Process);
    process.handle = handle;
    process.loop = loop;
    process.exit_cb = null;
    process.user_data = null;

    // Store process pointer in handle's data field
    uv::handle_set(handle, process);

    return process;
}

/*
  Spawn a child process.

  @param options : "Process spawn options"
  @return "PID of spawned process on success, negative error code on failure"
*/
fn int Process.spawn(&self, ProcessOptions* options)
{
    // Set up uv_process_options_t (this is a simplification)
    // In reality, this structure is complex and would need proper mapping

    self.exit_cb = options.exit_cb;
    self.user_data = options.user_data;

    // For now, return an error as proper implementation requires
    // mapping the ProcessOptions to uv_process_options_t
    io::printfn("Process spawning not fully implemented - requires uv_process_options_t mapping");
    return -1;
}

/*
  Send a signal to the process.

  @param signum : "Signal number to send"
  @return "0 on success, negative error code on failure"
*/
fn int Process.kill(&self, int signum)
{
    return uv::process_kill(self.handle, signum);
}

/*
  Get the process ID.

  @return "Process ID"
*/
fn int Process.get_pid(&self)
{
    return uv::process_get_pid(self.handle);
}

/*
  Close the process handle and free resources.
  Note: This is async - the process handle and wrapper will be freed when the close completes.
*/
fn void Process.close(&self)
{
    // For unspawned processes, just free the memory directly
    // For spawned processes, use uv_close
    int pid = uv::process_get_pid(self.handle);
    if (pid == 0)
    {
        // Process was never spawned, just free memory
        free(self.handle);
        free(self);
    }
    else
    {
        // Process was spawned, use proper uv_close
        uv::close((uv::Handle*)self.handle, &on_close_internal);
        // Note: Both handle and process will be freed by the callback
    }
}