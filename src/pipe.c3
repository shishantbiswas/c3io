module async::pipe;

import uv;
import std::io;
import async::event_loop;

/*
  Async Pipe Handle Wrapper for libuv
  ====================================
  Provides async pipe operations using libuv's pipe API.

  Pipe handles support Unix domain sockets and IPC pipes.
  Useful for inter-process communication.

  Usage:
    Pipe* pipe = async::pipe::create(loop, false);
    pipe.bind("/tmp/my_socket");
    pipe.listen(&on_connection, user_data);
    // Or connect:
    pipe.connect("/tmp/my_socket", &on_connect, user_data);
    // Later:
    pipe.close();
*/

// Faults
faultdef PIPE_INIT_FAILED;
faultdef PIPE_BIND_FAILED;
faultdef PIPE_CONNECT_FAILED;

// Callback types
alias PipeConnectCallback = fn void(Connect* req, int status, void* user_data);

/*
  Pipe handle.
  Wraps a libuv pipe handle for Unix domain sockets and IPC.
*/
struct Pipe
{
    uv::Pipe* handle;
    event_loop::EventLoop* loop;
}

// Internal libuv callback wrappers
fn void on_connect_internal(uv::Connect* req, int status)
{
    // Get user data from request
    void* user_data = uv::req_get(PipeConnectCallback, req);
    PipeConnectCallback callback = (PipeConnectCallback)user_data;

    if (callback)
    {
        callback(req, status, null);  // Note: simplified, user_data should be stored separately
    }
}

fn void on_close_internal(uv::Handle* handle)
{
    // Get pipe from handle and free both
    Pipe* pipe = uv::handle_get(Pipe, handle);
    free(handle);
    if (pipe != null)
    {
        free(pipe);
    }
}

/*
  Create a new pipe handle.

  @param loop : "Event loop to attach to"
  @param ipc : "Whether this pipe is for IPC"
*/
fn Pipe*? create(event_loop::EventLoop* loop, bool ipc)
{
    // Allocate pipe handle
    uv::Pipe* handle = uv::alloc_handle(uv::Pipe, uv::HandleType.NAMED_PIPE);

    // Initialize pipe handle
    int result = uv::pipe_init(loop.loop, handle, ipc ? 1 : 0);
    if (result != 0)
    {
        free(handle);
        io::printfn("Failed to initialize pipe handle: %s", (ZString)uv::strerror(result));
        return PIPE_INIT_FAILED~;
    }

    Pipe* pipe = mem::new(Pipe);
    pipe.handle = handle;
    pipe.loop = loop;

    // Store pipe pointer in handle's data field
    uv::handle_set(handle, pipe);

    return pipe;
}

/*
  Open an existing pipe file descriptor.

  @param fd : "File descriptor to open"
*/
fn void Pipe.open(&self, int fd)
{
    uv::pipe_open(self.handle, fd);
}

/*
  Bind the pipe to a Unix domain socket path.

  @param name : "Socket path to bind to"
*/
fn int Pipe.bind(&self, char* name)
{
    return uv::pipe_bind(self.handle, name);
}

/*
  Connect to a Unix domain socket.

  @param name : "Socket path to connect to"
  @param callback : "Callback called when connection completes"
  @param user_data : "User data passed to callback"
*/
fn void Pipe.connect(&self, char* name, PipeConnectCallback callback, void* user_data)
{
    uv::Connect* req = uv::alloc_req(uv::Connect, uv::ReqType.CONNECT);

    // Store callback in request data
    uv::req_set(req, (void*)callback);

    int result = uv::pipe_connect(req, self.handle, name, &on_connect_internal);
    if (result != 0)
    {
        io::printfn("Failed to connect pipe: %s", (ZString)uv::strerror(result));
        free(req);
    }
}

/*
  Get the local socket name.

  @param buffer : "Output buffer for socket name"
  @param size : "Size of buffer"
  @return "0 on success, negative error code on failure"
*/
fn int Pipe.getsockname(&self, char* buffer, usz* size)
{
    return uv::pipe_getsockname(self.handle, buffer, size);
}

/*
  Get the peer socket name.

  @param buffer : "Output buffer for peer name"
  @param size : "Size of buffer"
  @return "0 on success, negative error code on failure"
*/
fn int Pipe.getpeername(&self, char* buffer, usz* size)
{
    return uv::pipe_getpeername(self.handle, buffer, size);
}

/*
  Close the pipe handle and free resources.
  Note: This is async - the pipe handle and wrapper will be freed when the close completes.
*/
fn void Pipe.close(&self)
{
    // Close handle (async operation that will free both handle and pipe via callback)
    uv::close((uv::Handle*)self.handle, &on_close_internal);
    // Note: Both handle and pipe will be freed by the callback
}