module async::idle;

import uv;
import std::io;
import async::event_loop;

/*
  Async Idle Handle Wrapper for libuv
  ===================================
  Provides async idle operations using libuv's idle API.

  Idle handles run when the event loop has no other pending operations.
  Useful for performing background tasks when the loop is idle.

  Usage:
    Idle* idle = async::idle::create(loop);
    idle.start(&on_idle, user_data);  // Called when loop is idle
    // Later:
    idle.stop();
    idle.close();
*/

// Faults
faultdef IDLE_INIT_FAILED;
faultdef IDLE_START_FAILED;

// Callback type (matches uv.c3i IdleCb but with user_data)
alias IdleCallback = fn void(Idle* idle, void* user_data);

/*
  Idle handle.
  Wraps a libuv idle handle and provides async idle operations.
*/
struct Idle
{
    uv::Idle* handle;
    event_loop::EventLoop* loop;
    IdleCallback callback;
    void* user_data;
}

// Internal libuv callback wrappers
fn void on_idle_internal(uv::Idle* handle)
{
    Idle* idle = uv::handle_get(Idle, handle);

    if (idle.callback)
    {
        idle.callback(idle, idle.user_data);
    }
}

fn void on_close_internal(uv::Handle* handle)
{
    // Get idle from handle and free both
    Idle* idle = uv::handle_get(Idle, handle);
    free(handle);
    if (idle != null)
    {
        free(idle);
    }
}

/*
  Create a new idle handle.

  @param loop : "Event loop to attach to"
*/
fn Idle*? create(event_loop::EventLoop* loop)
{
    // Allocate idle handle
    uv::Idle* handle = uv::alloc_handle(uv::Idle, uv::HandleType.IDLE);

    // Initialize idle handle
    int result = uv::idle_init(loop.loop, handle);
    if (result != 0)
    {
        free(handle);
        io::printfn("Failed to initialize idle handle: %s", (ZString)uv::strerror(result));
        return IDLE_INIT_FAILED~;
    }

    Idle* idle = mem::new(Idle);
    idle.handle = handle;
    idle.loop = loop;
    idle.callback = null;
    idle.user_data = null;

    // Store idle pointer in handle's data field
    uv::handle_set(handle, idle);

    return idle;
}

/*
  Start the idle handle.

  @param callback : "Callback to invoke when loop is idle"
  @param user_data : "User data passed to callback"
*/
fn void Idle.start(&self, IdleCallback callback, void* user_data)
{
    self.callback = callback;
    self.user_data = user_data;

    int result = uv::idle_start(self.handle, &on_idle_internal);
    if (result != 0)
    {
        io::printfn("Failed to start idle handle: %s", (ZString)uv::strerror(result));
    }
}

/*
  Stop the idle handle.
*/
fn void Idle.stop(&self)
{
    uv::idle_stop(self.handle);
}

/*
  Close the idle handle and free resources.
  Note: This is async - the idle handle and wrapper will be freed when the close completes.
*/
fn void Idle.close(&self)
{
    // Stop idle first
    uv::idle_stop(self.handle);

    // Close handle (async operation that will free both handle and idle via callback)
    uv::close((uv::Handle*)self.handle, &on_close_internal);
    // Note: Both handle and idle will be freed by the callback
}