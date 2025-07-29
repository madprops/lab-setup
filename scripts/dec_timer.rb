#!/usr/bin/env ruby
require "socket"

sckt = "/tmp/timer_control.sock"
begin
  UNIXSocket.open(sckt) do |sock|
    sock.puts("dec_timer")
  end
rescue => e
  warn "Failed to send to timer_control: #{e}"
end