#!/usr/bin/env ruby
require "socket"

sckt = "/tmp/timer_control.sock"
begin
  UNIXSocket.open(sckt) do |sock|
    sock.puts("reset_timer")
  end
rescue => e
  warn "Failed to reset timer: #{e}"
end

sckt = "/tmp/sockpupper.sock"
begin
  UNIXSocket.open(sckt) do |sock|
    sock.puts("---")
  end
rescue => e
  warn "Failed to send to sockpupper: #{e}"
end