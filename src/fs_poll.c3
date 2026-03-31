module async::fs_poll;

import uv;
import std::io;
import async::event_loop;

/*
  Async FS Poll Handle Wrapper for libuv
  =======================================
  Provides async filesystem polling using libuv's fs_poll API.

  FS Poll handles periodically check files for changes using stat.
  Useful when inotify/fsevents are not available.

  Usage:
    FsPoll* fs_poll = async::fs_poll::create(loop);
    fs_poll.start("/path/to/check", 1000, &on_fs_poll, user_data);
    // Later:
    fs_poll.stop();
    fs_poll.close();
*/

// Faults
faultdef FS_POLL_INIT_FAILED;
faultdef FS_POLL_START_FAILED;

// Callback type (matches uv.c3i FsPollCb but with user_data)
alias FsPollCallback = fn void(FsPoll* fs_poll, int status, FileStat* prev, FileStat* curr, void* user_data);

/*
  FS Poll handle.
  Wraps a libuv fs_poll handle for periodic filesystem checking.
*/
struct FsPoll
{
    uv::FSPoll* handle;
    event_loop::EventLoop* loop;
    FsPollCallback callback;
    void* user_data;
}

// Internal libuv callback wrappers
fn void on_fs_poll_internal(uv::FSPoll* handle, int status, uv::FileStat* prev, uv::FileStat* curr)
{
    FsPoll* fs_poll = uv::handle_get(FsPoll, handle);

    if (fs_poll.callback)
    {
        fs_poll.callback(fs_poll, status, (uv::FileStat*)prev, (uv::FileStat*)curr, fs_poll.user_data);
    }
}

fn void on_close_internal(uv::Handle* handle)
{
    // Get fs_poll from handle and free both
    FsPoll* fs_poll = uv::handle_get(FsPoll, handle);
    free(handle);
    if (fs_poll != null)
    {
        free(fs_poll);
    }
}

/*
  Create a new FS poll handle.

  @param loop : "Event loop to attach to"
*/
fn FsPoll*? create(event_loop::EventLoop* loop)
{
    // Allocate FS poll handle
    uv::FSPoll* handle = uv::alloc_handle(uv::FSPoll, uv::HandleType.FS_POLL);

    // Initialize FS poll handle
    int result = uv::fs_poll_init(loop.loop, handle);
    if (result != 0)
    {
        free(handle);
        io::printfn("Failed to initialize FS poll handle: %s", (ZString)uv::strerror(result));
        return FS_POLL_INIT_FAILED~;
    }

    FsPoll* fs_poll = mem::new(FsPoll);
    fs_poll.handle = handle;
    fs_poll.loop = loop;
    fs_poll.callback = null;
    fs_poll.user_data = null;

    // Store fs_poll pointer in handle's data field
    uv::handle_set(handle, fs_poll);

    return fs_poll;
}

/*
  Start polling a filesystem path.

  @param path : "Path to poll"
  @param interval : "Polling interval in milliseconds"
  @param callback : "Callback to invoke when changes are detected"
  @param user_data : "User data passed to callback"
*/
fn void FsPoll.start(&self, char* path, uint interval, FsPollCallback callback, void* user_data)
{
    self.callback = callback;
    self.user_data = user_data;

    int result = uv::fs_poll_start(self.handle, &on_fs_poll_internal, path, interval);
    if (result != 0)
    {
        io::printfn("Failed to start FS poll handle: %s", (ZString)uv::strerror(result));
    }
}

/*
  Stop polling.
*/
fn void FsPoll.stop(&self)
{
    uv::fs_poll_stop(self.handle);
}

/*
  Close the FS poll handle and free resources.
  Note: This is async - the FS poll handle and wrapper will be freed when the close completes.
*/
fn void FsPoll.close(&self)
{
    // Stop FS poll first
    uv::fs_poll_stop(self.handle);

    // Close handle (async operation that will free both handle and fs_poll via callback)
    uv::close((uv::Handle*)self.handle, &on_close_internal);
    // Note: Both handle and fs_poll will be freed by the callback
}