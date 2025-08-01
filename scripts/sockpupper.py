#!/usr/bin/env python

import os
import socket
import threading
import subprocess
import sys


SOCKET_PATH = "/tmp/sockpupper.sock"

# List to keep track of persistent connections (e.g., the bar)
persistent_conns = []
conns_lock = threading.Lock()


def send_msg(conn, msg):
    try:
        bmsg = msg.encode("utf-8")
        conn.sendall(bmsg)
        return True
    except BrokenPipeError:
        return False
    except Exception:
        return False


# Broadcast message to all persistent connections
def broadcast(msg):
    with conns_lock:
        for c in persistent_conns[:]:
            try:
                c.sendall(msg.encode("utf-8"))
            except Exception:
                persistent_conns.remove(c)


def handle_client(conn):
    try:
        data = conn.recv(1024)
        if data:
            broadcast(data.decode("utf-8"))
    except Exception:
        pass
    finally:
        conn.close()


def socket_server():
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    os.chmod(SOCKET_PATH, 0o777)
    server.listen(5)
    print(f"Socket server started at {SOCKET_PATH}")

    while True:
        conn, _ = server.accept()
        threading.Thread(target=handle_client, args=(conn,), daemon=True).start()


def stdin_listener(conn):
    with conns_lock:
        persistent_conns.append(conn)
    try:
        for line in sys.stdin:
            # Broadcast stdin input to all persistent connections
            broadcast(line)
    finally:
        with conns_lock:
            if conn in persistent_conns:
                persistent_conns.remove(conn)
        conn.close()


if __name__ == "__main__":
    # Launch reset.rb at the start (background)
    try:
        reset_proc = subprocess.Popen(["ruby", "reset.rb"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("Launched reset.rb in background")
    except Exception as e:
        print(f"Failed to launch reset.rb: {e}")

    # Start the server and accept one connection for stdin_listener (assumed to be the bar)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)

    # Remove old socket if exists (e`xtra safety)
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)

    server.bind(SOCKET_PATH)
    os.chmod(SOCKET_PATH, 0o777)
    server.listen(5)
    print(f"Socket server started at {SOCKET_PATH}")

    # Launch sfwbar after the socket server is ready (background)
    try:
        with open("sfw_error.log", "a") as error_log:
            sfwbar_proc = subprocess.Popen(["sfwbar"], stdout=subprocess.DEVNULL, stderr=error_log)

        print("Launched sfwbar in background")
    except Exception as e:
        print(f"Failed to launch sfwbar: {e}")

    # Accept a connection for stdin_listener (the bar's persistent connection)
    conn, _ = server.accept()
    t = threading.Thread(target=stdin_listener, args=(conn,), daemon=True)
    t.start()

    # Continue accepting other clients as before
    while True:
        client_conn, _ = server.accept()
        # If this is not the bar, handle as a one-off (e.g., echo)
        threading.Thread(target=handle_client, args=(client_conn,), daemon=True).start()
