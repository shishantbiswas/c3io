module async::fs_event;

import uv;
import std::io;
import async::event_loop;

/*
  Async FS Event Handle Wrapper for libuv
  ========================================
  Provides async filesystem watching using libuv's fs_event API.

  FS Event handles monitor files or directories for changes.
  Useful for file watching in development tools, etc.

  Usage:
    FsEvent* fs_event = async::fs_event::create(loop);
    fs_event.start("/path/to/watch", &on_fs_event, user_data);
    // Later:
    fs_event.stop();
    fs_event.close();
*/

// Faults
faultdef FS_EVENT_INIT_FAILED;
faultdef FS_EVENT_START_FAILED;

// Callback type (matches uv.c3i FsEventCb but with user_data)
alias FsEventCallback = fn void(FsEvent* fs_event, char* filename, int events, int status, void* user_data);

/*
  FS Event handle.
  Wraps a libuv fs_event handle for monitoring filesystem changes.
*/
struct FsEvent
{
    uv::FSEvent* handle;
    event_loop::EventLoop* loop;
    FsEventCallback callback;
    void* user_data;
}

// Internal libuv callback wrappers
fn void on_fs_event_internal(uv::FSEvent* handle, char* filename, int events, int status)
{
    FsEvent* fs_event = uv::handle_get(FsEvent, handle);

    if (fs_event.callback)
    {
        fs_event.callback(fs_event, filename, events, status, fs_event.user_data);
    }
}

fn void on_close_internal(uv::Handle* handle)
{
    // Get fs_event from handle and free both
    FsEvent* fs_event = uv::handle_get(FsEvent, handle);
    free(handle);
    if (fs_event != null)
    {
        free(fs_event);
    }
}

/*
  Create a new FS event handle.

  @param loop : "Event loop to attach to"
*/
fn FsEvent*? create(event_loop::EventLoop* loop)
{
    // Allocate FS event handle
    uv::FSEvent* handle = uv::alloc_handle(uv::FSEvent, uv::HandleType.FS_EVENT);

    // Initialize FS event handle
    int result = uv::fs_event_init(loop.loop, handle);
    if (result != 0)
    {
        free(handle);
        io::printfn("Failed to initialize FS event handle: %s", (ZString)uv::strerror(result));
        return FS_EVENT_INIT_FAILED~;
    }

    FsEvent* fs_event = mem::new(FsEvent);
    fs_event.handle = handle;
    fs_event.loop = loop;
    fs_event.callback = null;
    fs_event.user_data = null;

    // Store fs_event pointer in handle's data field
    uv::handle_set(handle, fs_event);

    return fs_event;
}

/*
  Start watching a filesystem path.

  @param path : "Path to watch"
  @param callback : "Callback to invoke when changes occur"
  @param user_data : "User data passed to callback"
  @param flags : "Watch flags (0 for default)"
*/
fn void FsEvent.start(&self, char* path, FsEventCallback callback, void* user_data, uint flags)
{
    self.callback = callback;
    self.user_data = user_data;

    int result = uv::fs_event_start(self.handle, &on_fs_event_internal, path, flags);
    if (result != 0)
    {
        io::printfn("Failed to start FS event handle: %s", (ZString)uv::strerror(result));
    }
}

/*
  Stop watching.
*/
fn void FsEvent.stop(&self)
{
    uv::fs_event_stop(self.handle);
}

/*
  Close the FS event handle and free resources.
  Note: This is async - the FS event handle and wrapper will be freed when the close completes.
*/
fn void FsEvent.close(&self)
{
    // Stop FS event first
    uv::fs_event_stop(self.handle);

    // Close handle (async operation that will free both handle and fs_event via callback)
    uv::close((uv::Handle*)self.handle, &on_close_internal);
    // Note: Both handle and fs_event will be freed by the callback
}