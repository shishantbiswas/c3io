module async::tty;

import uv;
import std::io;
import async::event_loop;

/*
  Async TTY Handle Wrapper for libuv
  ===================================
  Provides async terminal I/O using libuv's TTY API.

  TTY handles allow reading from and writing to terminals.
  Useful for console applications.

  Usage:
    Tty* tty = async::tty::create(loop, STDIN_FILENO, true);
    tty.set_mode(TTY_MODE_NORMAL);
    // Use as stream for read/write operations
    // Later:
    tty.close();
*/

// Faults
faultdef TTY_INIT_FAILED;

// TTY modes
const int TTY_MODE_NORMAL = 0;  // Normal mode
const int TTY_MODE_RAW = 1;     // Raw mode

/*
  TTY handle.
  Wraps a libuv TTY handle for terminal I/O.
*/
struct Tty
{
    uv::Tty* handle;
    event_loop::EventLoop* loop;
}

/*
  Create a new TTY handle.

  @param loop : "Event loop to attach to"
  @param fd : "File descriptor (usually STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO)"
  @param readable : "Whether the TTY should be readable"
*/
fn Tty*? create(event_loop::EventLoop* loop, int fd, bool readable)
{
    // Allocate TTY handle
    uv::Tty* handle = uv::alloc_handle(uv::Tty, uv::HandleType.TTY);

    // Initialize TTY handle
    int result = uv::tty_init(loop.loop, handle, fd, readable ? 1 : 0);
    if (result != 0)
    {
        free(handle);
        io::printfn("Failed to initialize TTY handle: %s", (ZString)uv::strerror(result));
        return TTY_INIT_FAILED~;
    }

    Tty* tty = mem::new(Tty);
    tty.handle = handle;
    tty.loop = loop;

    // Store tty pointer in handle's data field
    uv::handle_set(handle, tty);

    return tty;
}

/*
  Set TTY mode.

  @param mode : "TTY mode (TTY_MODE_NORMAL or TTY_MODE_RAW)"
*/
fn void Tty.set_mode(&self, int mode)
{
    uv::tty_set_mode(self.handle, mode);
}

/*
  Reset TTY mode to normal.
  Should be called before program exit.
*/
fn void reset_mode()
{
    uv::tty_reset_mode();
}

/*
  Get terminal window size.

  @param width : "Output parameter for width"
  @param height : "Output parameter for height"
  @return "0 on success, negative error code on failure"
*/
fn int Tty.get_winsize(&self, int* width, int* height)
{
    return uv::tty_get_winsize(self.handle, width, height);
}

/*
  Close the TTY handle and free resources.
  Note: This is async - the TTY handle and wrapper will be freed when the close completes.
*/
fn void Tty.close(&self)
{
    // Close handle (async operation that will free both handle and tty via callback)
    uv::close((uv::Handle*)self.handle, &on_close_internal);
}

// Internal close callback
fn void on_close_internal(uv::Handle* handle)
{
    // Get tty from handle and free both
    Tty* tty = uv::handle_get(Tty, handle);
    free(handle);
    if (tty != null)
    {
        free(tty);
    }
}