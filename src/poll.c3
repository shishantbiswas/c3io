module async::poll;

import uv;
import std::io;
import async::event_loop;

/*
  Async Poll Handle Wrapper for libuv
  ====================================
  Provides async polling of file descriptors using libuv's poll API.

  Poll handles monitor file descriptors for readability/writability.
  Useful for integrating with existing file descriptors.

  Usage:
    Poll* poll = async::poll::create(loop, fd);
    poll.start(UV_READABLE, &on_poll, user_data);
    // Later:
    poll.stop();
    poll.close();
*/

// Faults
faultdef POLL_INIT_FAILED;
faultdef POLL_START_FAILED;

// Callback type (matches uv.c3i PollCb but with user_data)
alias PollCallback = fn void(Poll* poll, int status, int events, void* user_data);

/*
  Poll handle.
  Wraps a libuv poll handle for monitoring file descriptors.
*/
struct Poll
{
    uv::Poll* handle;
    event_loop::EventLoop* loop;
    PollCallback callback;
    void* user_data;
}

// Internal libuv callback wrappers
fn void on_poll_internal(uv::Poll* handle, int status, int events)
{
    Poll* poll = uv::handle_get(Poll, handle);

    if (poll.callback)
    {
        poll.callback(poll, status, events, poll.user_data);
    }
}

fn void on_close_internal(uv::Handle* handle)
{
    // Get poll from handle and free both
    Poll* poll = uv::handle_get(Poll, handle);
    free(handle);
    if (poll != null)
    {
        free(poll);
    }
}

/*
  Create a new poll handle.

  @param loop : "Event loop to attach to"
  @param fd : "File descriptor to poll"
*/
fn Poll*? create(event_loop::EventLoop* loop, int fd)
{
    // Allocate poll handle
    uv::Poll* handle = uv::alloc_handle(uv::Poll, uv::HandleType.POLL);

    // Initialize poll handle
    int result = uv::poll_init(loop.loop, handle, fd);
    if (result != 0)
    {
        free(handle);
        io::printfn("Failed to initialize poll handle: %s", (ZString)uv::strerror(result));
        return POLL_INIT_FAILED~;
    }

    Poll* poll = mem::new(Poll);
    poll.handle = handle;
    poll.loop = loop;
    poll.callback = null;
    poll.user_data = null;

    // Store poll pointer in handle's data field
    uv::handle_set(handle, poll);

    return poll;
}

/*
  Start polling the file descriptor.

  @param events : "Events to poll for (UV_READABLE, UV_WRITABLE)"
  @param callback : "Callback to invoke when events occur"
  @param user_data : "User data passed to callback"
*/
fn void Poll.start(&self, int events, PollCallback callback, void* user_data)
{
    self.callback = callback;
    self.user_data = user_data;

    int result = uv::poll_start(self.handle, events, &on_poll_internal);
    if (result != 0)
    {
        io::printfn("Failed to start poll handle: %s", (ZString)uv::strerror(result));
    }
}

/*
  Stop polling.
*/
fn void Poll.stop(&self)
{
    uv::poll_stop(self.handle);
}

/*
  Close the poll handle and free resources.
  Note: This is async - the poll handle and wrapper will be freed when the close completes.
*/
fn void Poll.close(&self)
{
    // Stop poll first
    uv::poll_stop(self.handle);

    // Close handle (async operation that will free both handle and poll via callback)
    uv::close((uv::Handle*)self.handle, &on_close_internal);
    // Note: Both handle and poll will be freed by the callback
}