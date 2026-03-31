module async::prepare;

import uv;
import std::io;
import async::event_loop;

/*
  Async Prepare Handle Wrapper for libuv
  ======================================
  Provides async prepare operations using libuv's prepare API.

  Prepare handles run right before the event loop polls for I/O.
  Useful for performing tasks that need to happen before I/O polling.

  Usage:
    Prepare* prepare = async::prepare::create(loop);
    prepare.start(&on_prepare, user_data);  // Called before I/O polling
    // Later:
    prepare.stop();
    prepare.close();
*/

// Faults
faultdef PREPARE_INIT_FAILED;
faultdef PREPARE_START_FAILED;

// Callback type (matches uv.c3i PrepareCb but with user_data)
alias PrepareCallback = fn void(Prepare* prepare, void* user_data);

/*
  Prepare handle.
  Wraps a libuv prepare handle and provides async prepare operations.
*/
struct Prepare
{
    uv::Prepare* handle;
    event_loop::EventLoop* loop;
    PrepareCallback callback;
    void* user_data;
}

// Internal libuv callback wrappers
fn void on_prepare_internal(uv::Prepare* handle)
{
    Prepare* prepare = uv::handle_get(Prepare, handle);

    if (prepare.callback)
    {
        prepare.callback(prepare, prepare.user_data);
    }
}

fn void on_close_internal(uv::Handle* handle)
{
    // Get prepare from handle and free both
    Prepare* prepare = uv::handle_get(Prepare, handle);
    free(handle);
    if (prepare != null)
    {
        free(prepare);
    }
}

/*
  Create a new prepare handle.

  @param loop : "Event loop to attach to"
*/
fn Prepare*? create(event_loop::EventLoop* loop)
{
    // Allocate prepare handle
    uv::Prepare* handle = uv::alloc_handle(uv::Prepare, uv::HandleType.PREPARE);

    // Initialize prepare handle
    int result = uv::prepare_init(loop.loop, handle);
    if (result != 0)
    {
        free(handle);
        io::printfn("Failed to initialize prepare handle: %s", (ZString)uv::strerror(result));
        return PREPARE_INIT_FAILED~;
    }

    Prepare* prepare = mem::new(Prepare);
    prepare.handle = handle;
    prepare.loop = loop;
    prepare.callback = null;
    prepare.user_data = null;

    // Store prepare pointer in handle's data field
    uv::handle_set(handle, prepare);

    return prepare;
}

/*
  Start the prepare handle.

  @param callback : "Callback to invoke before I/O polling"
  @param user_data : "User data passed to callback"
*/
fn void Prepare.start(&self, PrepareCallback callback, void* user_data)
{
    self.callback = callback;
    self.user_data = user_data;

    int result = uv::prepare_start(self.handle, &on_prepare_internal);
    if (result != 0)
    {
        io::printfn("Failed to start prepare handle: %s", (ZString)uv::strerror(result));
    }
}

/*
  Stop the prepare handle.
*/
fn void Prepare.stop(&self)
{
    uv::prepare_stop(self.handle);
}

/*
  Close the prepare handle and free resources.
  Note: This is async - the prepare handle and wrapper will be freed when the close completes.
*/
fn void Prepare.close(&self)
{
    // Stop prepare first
    uv::prepare_stop(self.handle);

    // Close handle (async operation that will free both handle and prepare via callback)
    uv::close((uv::Handle*)self.handle, &on_close_internal);
    // Note: Both handle and prepare will be freed by the callback
}