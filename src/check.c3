module async::check;

import uv;
import std::io;
import async::event_loop;

/*
  Async Check Handle Wrapper for libuv
  ====================================
  Provides async check operations using libuv's check API.

  Check handles run right after the event loop polls for I/O.
  Useful for performing tasks that need to happen after I/O polling.

  Usage:
    Check* check = async::check::create(loop);
    check.start(&on_check, user_data);  // Called after I/O polling
    // Later:
    check.stop();
    check.close();
*/

// Faults
faultdef CHECK_INIT_FAILED;
faultdef CHECK_START_FAILED;

// Callback type (matches uv.c3i CheckCb but with user_data)
alias CheckCallback = fn void(Check* check, void* user_data);

/*
  Check handle.
  Wraps a libuv check handle and provides async check operations.
*/
struct Check
{
    uv::Check* handle;
    event_loop::EventLoop* loop;
    CheckCallback callback;
    void* user_data;
}

// Internal libuv callback wrappers
fn void on_check_internal(uv::Check* handle)
{
    Check* check = uv::handle_get(Check, handle);

    if (check.callback)
    {
        check.callback(check, check.user_data);
    }
}

fn void on_close_internal(uv::Handle* handle)
{
    // Get check from handle and free both
    Check* check = uv::handle_get(Check, handle);
    free(handle);
    if (check != null)
    {
        free(check);
    }
}

/*
  Create a new check handle.

  @param loop : "Event loop to attach to"
*/
fn Check*? create(event_loop::EventLoop* loop)
{
    // Allocate check handle
    uv::Check* handle = uv::alloc_handle(uv::Check, uv::HandleType.CHECK);

    // Initialize check handle
    int result = uv::check_init(loop.loop, handle);
    if (result != 0)
    {
        free(handle);
        io::printfn("Failed to initialize check handle: %s", (ZString)uv::strerror(result));
        return CHECK_INIT_FAILED~;
    }

    Check* check = mem::new(Check);
    check.handle = handle;
    check.loop = loop;
    check.callback = null;
    check.user_data = null;

    // Store check pointer in handle's data field
    uv::handle_set(handle, check);

    return check;
}

/*
  Start the check handle.

  @param callback : "Callback to invoke after I/O polling"
  @param user_data : "User data passed to callback"
*/
fn void Check.start(&self, CheckCallback callback, void* user_data)
{
    self.callback = callback;
    self.user_data = user_data;

    int result = uv::check_start(self.handle, &on_check_internal);
    if (result != 0)
    {
        io::printfn("Failed to start check handle: %s", (ZString)uv::strerror(result));
    }
}

/*
  Stop the check handle.
*/
fn void Check.stop(&self)
{
    uv::check_stop(self.handle);
}

/*
  Close the check handle and free resources.
  Note: This is async - the check handle and wrapper will be freed when the close completes.
*/
fn void Check.close(&self)
{
    // Stop check first
    uv::check_stop(self.handle);

    // Close handle (async operation that will free both handle and check via callback)
    uv::close((uv::Handle*)self.handle, &on_close_internal);
    // Note: Both handle and check will be freed by the callback
}