module async::async;

import uv;
import std::io;
import async::event_loop;

/*
  Async Handle Wrapper for libuv
  ===============================
  Provides cross-thread communication using libuv's async API.

  Async handles allow one thread to signal another thread running an event loop.
  The uv_async_send() function is thread-safe and can be called from any thread.

  Usage:
    Async* async = async::async::create(loop);
    async.start(&on_async, user_data);
    // From another thread:
    async.send();  // Wake up the event loop
    // Later:
    async.close();
*/

// Faults
faultdef ASYNC_INIT_FAILED;
faultdef ASYNC_START_FAILED;

// Callback type (matches uv.c3i AsyncCb but with user_data)
alias AsyncCallback = fn void(Async* async, void* user_data);

/*
  Async handle.
  Wraps a libuv async handle for cross-thread communication.
*/
struct Async
{
    uv::Async* handle;
    event_loop::EventLoop* loop;
    AsyncCallback callback;
    void* user_data;
}

// Internal libuv callback wrappers
fn void on_async_internal(uv::Async* handle)
{
    Async* async = uv::handle_get(Async, handle);

    if (async.callback)
    {
        async.callback(async, async.user_data);
    }
}

fn void on_close_internal(uv::Handle* handle)
{
    // Get async from handle and free both
    Async* async = uv::handle_get(Async, handle);
    free(handle);
    if (async != null)
    {
        free(async);
    }
}

/*
  Create a new async handle.

  @param loop : "Event loop to attach to"
*/
fn Async*? create(event_loop::EventLoop* loop)
{
    // Allocate async handle
    uv::Async* handle = uv::alloc_handle(uv::Async, uv::HandleType.ASYNC);

    // Initialize async handle
    int result = uv::async_init(loop.loop, handle, &on_async_internal);
    if (result != 0)
    {
        free(handle);
        io::printfn("Failed to initialize async handle: %s", (ZString)uv::strerror(result));
        return ASYNC_INIT_FAILED~;
    }

    Async* async = mem::new(Async);
    async.handle = handle;
    async.loop = loop;
    async.callback = null;
    async.user_data = null;

    // Store async pointer in handle's data field
    uv::handle_set(handle, async);

    return async;
}

/*
  Start the async handle.

  @param callback : "Callback to invoke when async is sent"
  @param user_data : "User data passed to callback"
*/
fn void Async.start(&self, AsyncCallback callback, void* user_data)
{
    self.callback = callback;
    self.user_data = user_data;
    // Note: async handles are started automatically when initialized
}

/*
  Send a signal to the async handle.
  This is thread-safe and can be called from any thread.
*/
fn void Async.send(&self)
{
    uv::async_send(self.handle);
}

/*
  Close the async handle and free resources.
  Note: This is async - the async handle and wrapper will be freed when the close completes.
*/
fn void Async.close(&self)
{
    // Close handle (async operation that will free both handle and async via callback)
    uv::close((uv::Handle*)self.handle, &on_close_internal);
    // Note: Both handle and async will be freed by the callback
}