module async::signal;

import uv;
import std::io;
import async::event_loop;

/*
  Async Signal Handle Wrapper for libuv
  ======================================
  Provides async signal handling using libuv's signal API.

  Signal handles allow the event loop to handle OS signals asynchronously.
  Useful for graceful shutdown on SIGINT, SIGTERM, etc.

  Usage:
    Signal* signal = async::signal::create(loop);
    signal.start(SIGINT, &on_signal, user_data);
    // Later:
    signal.stop();
    signal.close();
*/

// Faults
faultdef SIGNAL_INIT_FAILED;
faultdef SIGNAL_START_FAILED;

// Callback type (matches uv.c3i SignalCb but with user_data)
alias SignalCallback = fn void(Signal* signal, int signum, void* user_data);

/*
  Signal handle.
  Wraps a libuv signal handle for handling OS signals.
*/
struct Signal
{
    uv::Signal* handle;
    event_loop::EventLoop* loop;
    SignalCallback callback;
    void* user_data;
}

// Internal libuv callback wrappers
fn void on_signal_internal(uv::Signal* handle, int signum)
{
    Signal* signal = uv::handle_get(Signal, handle);

    if (signal.callback)
    {
        signal.callback(signal, signum, signal.user_data);
    }
}

fn void on_close_internal(uv::Handle* handle)
{
    // Get signal from handle and free both
    Signal* signal = uv::handle_get(Signal, handle);
    free(handle);
    if (signal != null)
    {
        free(signal);
    }
}

/*
  Create a new signal handle.

  @param loop : "Event loop to attach to"
*/
fn Signal*? create(event_loop::EventLoop* loop)
{
    // Allocate signal handle
    uv::Signal* handle = uv::alloc_handle(uv::Signal, uv::HandleType.SIGNAL);

    // Initialize signal handle
    int result = uv::signal_init(loop.loop, handle);
    if (result != 0)
    {
        free(handle);
        io::printfn("Failed to initialize signal handle: %s", (ZString)uv::strerror(result));
        return SIGNAL_INIT_FAILED~;
    }

    Signal* signal = mem::new(Signal);
    signal.handle = handle;
    signal.loop = loop;
    signal.callback = null;
    signal.user_data = null;

    // Store signal pointer in handle's data field
    uv::handle_set(handle, signal);

    return signal;
}

/*
  Start listening for a signal.

  @param signum : "Signal number (e.g., SIGINT, SIGTERM)"
  @param callback : "Callback to invoke when signal is received"
  @param user_data : "User data passed to callback"
*/
fn void Signal.start(&self, int signum, SignalCallback callback, void* user_data)
{
    self.callback = callback;
    self.user_data = user_data;

    int result = uv::signal_start(self.handle, &on_signal_internal, signum);
    if (result != 0)
    {
        io::printfn("Failed to start signal handle: %s", (ZString)uv::strerror(result));
    }
}

/*
  Stop listening for the signal.
*/
fn void Signal.stop(&self)
{
    uv::signal_stop(self.handle);
}

/*
  Close the signal handle and free resources.
  Note: This is async - the signal handle and wrapper will be freed when the close completes.
*/
fn void Signal.close(&self)
{
    // Stop signal first
    uv::signal_stop(self.handle);

    // Close handle (async operation that will free both handle and signal via callback)
    uv::close((uv::Handle*)self.handle, &on_close_internal);
    // Note: Both handle and signal will be freed by the callback
}