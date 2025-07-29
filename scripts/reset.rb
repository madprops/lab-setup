#!/usr/bin/env ruby
require "socket"

sckt = "/tmp/timer_control.sock"
UNIXSocket.open(sckt) do |sock|
    sock.puts("reset_timer")
end

sckt = "/tmp/sockpupper.sock"
UNIXSocket.open(sckt) do |sock|
    sock.puts("---")
end