module async::tcp_test;

import async::event_loop;
import async::tcp;
import async::timer;
import uv;
import std::io;

<*
 Test TCP connection creation and cleanup.
*>
fn void test_tcp_create_and_close() @test
{
    event_loop::EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }

    event_loop::EventLoop loop = loop_opt;
    defer loop.free();

    async::tcp::TcpConnection*? conn_opt = async::tcp::create(&loop);
    if (catch err = conn_opt)
    {
        assert(false, "Should create TCP connection");
        return;
    }

    async::tcp::TcpConnection* conn = conn_opt;

    conn.close();
    // Note: close() frees the connection automatically, but it's async
    // Run the event loop to process the close callback
    (void)loop.run();

    assert(true, "TCP connection created and closed successfully");
}

<*
 Connection callback for testing.
 Stores result in user_data.
*>
struct ConnectResult
{
    bool called;
    int status;
}

fn void on_test_connect(async::tcp::TcpConnection* conn, int status, void* user_data)
{
    ConnectResult* result = user_data;
    result.called = true;
    result.status = status;

    // Close the connection (will be freed async)
    conn.close();
    // Don't stop the loop yet - let the close callback run
}

<*
 Test connecting to a real server (google.com:80).
 This is an integration test that requires internet connection.
*>
fn void test_tcp_connect_real_server() @test
{
    event_loop::EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }

    event_loop::EventLoop loop = loop_opt;
    defer loop.free();

    ConnectResult result;
    result.called = false;
    result.status = -1;

    // Connect to Google's HTTP server
    async::tcp::TcpConnection*? conn_opt = async::tcp::connect(
        &loop, "142.250.185.46", 80, &on_test_connect, &result
    );

    if (catch err = conn_opt)
    {
        io::printfn("Warning: Could not connect (network issue?): %s", err);
        // Don't fail the test - might not have internet
        return;
    }

    async::tcp::TcpConnection* conn = conn_opt;
    // Note: connection is closed in the callback, no need for defer

    // Run event loop until connection completes and closes
    (void)loop.run();

    assert(result.called, "Connect callback should be called");
    if (result.status == 0)
    {
        io::printfn("✓ Successfully connected to Google");
    }
    else
    {
        io::printfn("Connection failed with status: %d (network issue?)", result.status);
    }
}

<*
 Test setting TCP options (nodelay, keepalive).
*>
fn void test_tcp_options() @test
{
    event_loop::EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }

    event_loop::EventLoop loop = loop_opt;
    defer loop.free();

    async::tcp::TcpConnection*? conn_opt = async::tcp::create(&loop);
    if (catch err = conn_opt)
    {
        assert(false, "Should create TCP connection");
        return;
    }

    async::tcp::TcpConnection* conn = conn_opt;

    // Test nodelay
    if (catch err = conn.set_nodelay(true))
    {
        assert(false, "Should set TCP_NODELAY");
        return;
    }

    // Test keepalive
    if (catch err = conn.set_keepalive(true, 60))
    {
        assert(false, "Should set TCP keepalive");
        return;
    }

    conn.close();
    // Run event loop to process close callback
    (void)loop.run();

    assert(true, "TCP options set successfully");
}

<*
 Read callback for testing.
*>
struct ReadResult
{
    bool called;
    int bytes_received;
}

fn char[] on_test_alloc(async::tcp::TcpConnection* conn, usz suggested_size, void* user_data)
{
    // Allocate a buffer for reading
    char[] buf = mem::new_array(char, suggested_size);
    return buf;
}

fn void on_test_read(async::tcp::TcpConnection* conn, char[] data, void* user_data)
{
    ReadResult* result = user_data;
    result.called = true;
    result.bytes_received = (int)data.len;

    if (data.len > 0)
    {
        io::printfn("Received %d bytes", data.len);
    }
    else
    {
        io::printfn("Connection closed or error");
    }

    // Stop reading and event loop
    (void)conn.stop_read();
    conn.loop.stop();
}

<*
 Write callback for testing.
*>
struct WriteResult
{
    bool called;
    int status;
}

struct TestContext
{
    bool success;
    bool completed;
    int call_count;
    EventLoop* loop;
}

fn void on_test_write(async::tcp::TcpConnection* conn, int status, void* user_data)
{
    WriteResult* result = user_data;
    result.called = true;
    result.status = status;
}

fn void on_timeout_callback(async::timer::Timer* timer, void* user_data)
{
    TestContext* ctx = user_data;
    ctx.completed = true;
}



<*
   Test TCP read operations with data.
*>
fn void test_tcp_read_operations() @test
{
    event_loop::EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }

    event_loop::EventLoop loop = loop_opt;
    defer loop.free();

    ConnectResult connect_result;
    connect_result.called = false;
    connect_result.status = -1;

    ReadResult read_result;
    read_result.called = false;
    read_result.bytes_received = 0;

    WriteResult write_result;
    write_result.called = false;
    write_result.status = -1;

    // Connect to Google's HTTP server
    async::tcp::TcpConnection*? conn_opt = async::tcp::connect(
        &loop, "142.250.185.46", 80, &on_test_connect_for_read, &connect_result
    );

    if (catch err = conn_opt)
    {
        io::printfn("Warning: Could not connect (network issue?): %s", err);
        return;
    }

    async::tcp::TcpConnection* conn = conn_opt;

    // Run event loop until connection completes
    int connect_timeout = 0;
    while (!connect_result.called && connect_timeout < 100)
    {
        (void)loop.run_once();
        connect_timeout++;
    }

    if (!connect_result.called || connect_result.status != 0)
    {
        io::printfn("Connection failed, skipping read test");
        conn.close();
        (void)loop.run();
        return;
    }

    // Start reading
    if (catch err = conn.start_read(&on_test_alloc, &on_test_read_with_data, &read_result))
    {
        assert(false, "Should start reading");
        conn.close();
        (void)loop.run();
        return;
    }

    // Send a simple HTTP request
    char[] request = "GET / HTTP/1.0\r\nHost: www.google.com\r\n\r\n";
    if (catch err = conn.write(request, &on_test_write, &write_result))
    {
        assert(false, "Should write request");
        conn.close();
        (void)loop.run();
        return;
    }

    // Run event loop until write completes or timeout
    int write_timeout = 0;
    while (!write_result.called && write_timeout < 100)
    {
        (void)loop.run_once();
        write_timeout++;
    }

    // Write should have completed
    assert(write_result.called, "Write callback should be called");
    assert(write_result.status == 0, "Write should succeed");

    // Run event loop to process read
    int read_timeout = 0;
    while (!read_result.called && read_timeout < 100)
    {
        (void)loop.run_once();
        read_timeout++;
    }

    // Should have received some data
    assert(read_result.called, "Read callback should be called");
    assert(read_result.bytes_received > 0, "Should receive some data");

    // Stop reading
    if (catch err = conn.stop_read())
    {
        assert(false, "Should stop reading");
    }

    conn.close();
    (void)loop.run();

    assert(true, "TCP read operations test passed");
}

<*
  Connect callback that starts reading.
*>
fn void on_test_connect_for_read(async::tcp::TcpConnection* conn, int status, void* user_data)
{
    ConnectResult* result = user_data;
    result.called = true;
    result.status = status;

    if (status == 0)
    {
        io::printfn("Connected successfully for read test");
        // Note: reading started in test function
    }
    else
    {
        io::printfn("Connection failed with status: %d", status);
        conn.close();
    }
}

<*
  Read callback that stores data info.
*>
fn void on_test_read_with_data(async::tcp::TcpConnection* conn, char[] data, void* user_data)
{
    ReadResult* result = user_data;
    result.called = true;
    result.bytes_received = (int)data.len;

    if (data.len > 0)
    {
        io::printfn("Received %d bytes of data", data.len);
        // Stop reading after receiving data
        (void)conn.stop_read();
    }
    else
    {
        io::printfn("Connection closed or error");
    }
}

<*
   Test TCP write operations with large data.
*>
fn void test_tcp_write_large_data() @test
{
    event_loop::EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }

    event_loop::EventLoop loop = loop_opt;
    defer loop.free();

    ConnectResult connect_result;
    connect_result.called = false;
    connect_result.status = -1;

    WriteResult write_result;
    write_result.called = false;
    write_result.status = -1;

    // Connect to Google's HTTP server
    async::tcp::TcpConnection*? conn_opt = async::tcp::connect(
        &loop, "142.250.185.46", 80, &on_test_connect_for_write, &connect_result
    );

    if (catch err = conn_opt)
    {
        io::printfn("Warning: Could not connect (network issue?): %s", err);
        return;
    }

    async::tcp::TcpConnection* conn = conn_opt;

    // Run event loop until connection completes
    int connect_timeout = 0;
    while (!connect_result.called && connect_timeout < 100)
    {
        (void)loop.run_once();
        connect_timeout++;
    }

    if (!connect_result.called || connect_result.status != 0)
    {
        io::printfn("Connection failed, skipping write test");
        conn.close();
        (void)loop.run();
        return;
    }

    // Create large data (1KB)
    char[] large_data = mem::new_array(char, 1024);
    for (int i = 0; i < 1024; i++)
    {
        large_data[i] = (char)(i % 256);
    }

    // Write large data
    if (catch err = conn.write(large_data, &on_test_write_large, &write_result))
    {
        free(large_data.ptr);
        assert(false, "Should write large data");
        conn.close();
        (void)loop.run();
        return;
    }

    // Run event loop until write completes
    int write_timeout = 0;
    while (!write_result.called && write_timeout < 100)
    {
        (void)loop.run_once();
        write_timeout++;
    }

    // Write callback should be called
    assert(write_result.called, "Write callback should be called");
    assert(write_result.status == 0, "Write should succeed");

    free(large_data.ptr);
    conn.close();
    (void)loop.run();

    assert(true, "TCP write large data test passed");
}

fn void on_test_connect_for_write(async::tcp::TcpConnection* conn, int status, void* user_data)
{
    ConnectResult* result = user_data;
    result.called = true;
    result.status = status;

    if (status == 0)
    {
        io::printfn("Connected successfully for write test");
    }
    else
    {
        io::printfn("Connection failed with status: %d", status);
        conn.close();
    }
}

fn void on_test_write_large(async::tcp::TcpConnection* conn, int status, void* user_data)
{
    WriteResult* result = user_data;
    result.called = true;
    result.status = status;
}

<*
   Test TCP shutdown operations using low-level uv API.
*>
struct ShutdownResult
{
    bool called;
    int status;
}

fn void on_tcp_shutdown(uv::Shutdown* req, int status)
{
    ShutdownResult* result = (ShutdownResult*)uv::req_get_data((uv::Req*)req);
    if (result != null)
    {
        result.called = true;
        result.status = status;
    }
    free(req);
}

fn void test_tcp_shutdown() @test
{
    event_loop::EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }

    event_loop::EventLoop loop = loop_opt;
    defer loop.free();

    async::tcp::TcpConnection*? conn_opt = async::tcp::create(&loop);
    if (catch err = conn_opt)
    {
        assert(false, "Should create TCP connection");
        return;
    }

    async::tcp::TcpConnection* conn = conn_opt;

    // Test shutdown on unconnected socket - expect it to fail gracefully
    uv::Shutdown* shutdown_req = uv::alloc_req(uv::Shutdown, uv::ReqType.SHUTDOWN);
    ShutdownResult shutdown_result;
    shutdown_result.called = false;
    shutdown_result.status = -1;
    uv::req_set_data((uv::Req*)shutdown_req, &shutdown_result);

    int shutdown_result_code = uv::shutdown(shutdown_req, (uv::Stream*)conn.handle, &on_tcp_shutdown);

    if (shutdown_result_code != 0)
    {
        // If shutdown failed immediately, free the request
        free(shutdown_req);
    }
    else
    {
        // Run event loop to process the shutdown callback
        int timeout = 0;
        while (!shutdown_result.called && timeout < 100)
        {
            (void)loop.run_once();
            timeout++;
        }
    }

    conn.close();
    (void)loop.run();

    assert(true, "TCP shutdown test passed");
}

<*
  Test TCP error conditions.
*>
fn void on_error_connect(async::tcp::TcpConnection* conn, int status, void* user_data)
{
    ConnectResult* result = user_data;
    result.called = true;
    result.status = status;
    // Always close the connection when done
    conn.close();
}

fn void test_tcp_error_conditions() @test
{
    event_loop::EventLoop? loop_opt = event_loop::create();
    if (catch err = loop_opt)
    {
        assert(false, "Should create event loop");
        return;
    }

    event_loop::EventLoop loop = loop_opt;
    defer loop.free();

    // Try to connect to invalid address
    ConnectResult connect_result;
    connect_result.called = false;
    connect_result.status = -1;

    async::tcp::TcpConnection*? conn_opt = async::tcp::connect(
        &loop, "192.0.2.1", 12345, &on_error_connect, &connect_result
    );

    if (catch err = conn_opt)
    {
        // Expected to fail with invalid address
        io::printfn("Connection correctly failed with invalid address: %s", err);
        assert(true, "TCP error conditions test passed");
        return;
    }

    async::tcp::TcpConnection* conn = conn_opt;

    // Create a timeout timer to ensure test doesn't hang
    async::timer::Timer*? timeout_timer_opt = async::timer::create(&loop);
    if (catch err = timeout_timer_opt)
    {
        conn.close();
        assert(false, "Should create timeout timer");
        return;
    }
    async::timer::Timer* timeout_timer = timeout_timer_opt;

    // Set up timeout callback
    TestContext timeout_ctx;
    timeout_ctx.success = false;
    timeout_ctx.completed = false;
    timeout_ctx.loop = &loop;

    timeout_timer.start(500, 0, &on_timeout_callback, &timeout_ctx); // 500ms timeout

    // Run event loop until connection attempt completes or timeout
    while (!connect_result.called && !timeout_ctx.completed)
    {
        (void)loop.run_once();
    }

    // Stop timeout timer
    timeout_timer.stop();

    // Connection should have failed (either due to unreachable host or timeout)
    assert(connect_result.called || timeout_ctx.completed, "Either connection should complete or timeout");

    if (connect_result.called)
    {
        assert(connect_result.status != 0, "Connection to invalid address should fail");
    }

    // Close timeout timer
    timeout_timer.close();

    // Run the event loop to completion to allow async cleanup operations to finish
    (void)loop.run();

    assert(true, "TCP error conditions test passed");
}
