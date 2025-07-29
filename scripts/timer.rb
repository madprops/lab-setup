#!/usr/bin/env ruby
require "socket"
require "open3"

def send_msg(msg)
  system("echo '#{msg}' | socat - UNIX-CONNECT:/tmp/sockpupper.sock")
end

def format_time(remaining)
  if remaining < 60
    "#{remaining.round} seconds"
  elsif remaining < 3600
    "#{(remaining/60.0).round(1)} minutes"
  elsif remaining < 86400
    "#{(remaining/3600.0).round(2)} hours"
  else
    "#{(remaining/86400.0).round(2)} days"
  end
end

def get_input(prompt, data)
  cmd = "rofi -dmenu -p '#{prompt}' -i"
  stdin, stdout, stderr, wait_thr = Open3.popen3(cmd)
  stdin.puts(data)
  stdin.close
  return stdout.read.strip
end

def get_data()
  path = File.join(__dir__, "data/timer.data")
  data = ""

  File.open(path, "a+") do |file|
    data = file.read.strip
  end

  if ARGV.length >= 2
    title = ARGV[0]
    time = ARGV[1..-1].join(" ")
  else
    title = get_input("Enter Title", data)

    if title == ""
      exit
    end

    times = "5m\n10m\n15m\n20m\n30m\n1h\n2h"
    time = get_input("Enter Time", times)

    if time == ""
      exit
    end
  end

  n = time.gsub(/[^0-9]/, "").strip.to_i
  u = time.gsub(/[0-9]/, "").strip

  if u == "m" or u.include?("min")
    t = n
  elsif u == "s" or u.include?("sec")
    t = n / 60.0
  elsif u == "h" or u.include?("hour")
    t = n * 60.0
  else
    t = n
  end

  lines = data.split("\n")
  lines.delete_if {|x| x == title}
  lines.unshift(title)
  File.write(path, lines.join("\n"))
  return title, t
end


# Listen for 'reset_timer' or 'quit' on a dedicated control socket and set reset_flag if received
def listen_for_reset(reset_flag)
  Thread.new do
    socket_path = "/tmp/timer_control.sock"
    File.unlink(socket_path) if File.exist?(socket_path)
    server = UNIXServer.new(socket_path)
    File.chmod(0o666, socket_path)
    loop do
      begin
        client = server.accept
        msg = client.gets
        client.close

        if msg && msg.strip == "reset_timer"
          reset_flag[:reset] = true
        elsif msg && msg.strip == "quit"
          reset_flag[:reset] = true
        end
      rescue => e
        warn "[timer.rb] Control socket error: #{e}"
      end
    end
  end
end

def start_timer(title, t)
  total_seconds = (t * 60).to_i
  reset_flag = { reset: false }
  listen_for_reset(reset_flag)
  start_time = Time.now

  while true
    if reset_flag[:reset]
      exit
    end

    elapsed = Time.now - start_time
    remaining = total_seconds - elapsed
    break if remaining <= 0

    rem = format_time(remaining)
    msg = "#{title} #{rem}"
    send_msg(msg)
    sleep 1
  end

  msg = "#{title} Done"
  send_msg(msg)
end

title, t = get_data()
exit if title.empty? || t.nil?
start_timer(title, t)