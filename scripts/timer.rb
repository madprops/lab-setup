#!/usr/bin/env ruby

# PID file logic to stop existing timer.rb process
pidfile = "/tmp/timer.rb.pid"

if File.exist?(pidfile)
  old_pid = File.read(pidfile).strip.to_i
  alive = false

  if old_pid > 0
    begin
      Process.kill(0, old_pid)
      alive = true
    rescue Errno::ESRCH
      alive = false
    rescue => e
      warn "[timer.rb] Error checking old process: #{e}"
    end

    if alive
      begin
        Process.kill('TERM', old_pid)
        sleep 0.5
      rescue => e
        warn "[timer.rb] Could not kill old process: #{e}"
      end
    end
  end
end

File.write(pidfile, Process.pid)
require "socket"
require "open3"

def send_msg(msg)
  system("echo '#{msg}' | socat - UNIX-CONNECT:/tmp/sockpupper.sock")
end

def smart_label(n, singular, plural)
  (n == 1) || (n == 1.0) ? singular : plural
end

def format_time(remaining)
  if remaining < 60
    n = remaining.to_i
    label = smart_label(n, "second", "seconds")
    "#{n} #{label}"
  elsif remaining < 3600
    n = (remaining/60).to_i
    label = smart_label(n, "minute", "minutes")
    "#{n} #{label}"
  elsif remaining < 86400
    n = (remaining/3600.0).round(2)
    label = smart_label(n, "hour", "hours")
    "#{n} #{label}"
  else
    n = (remaining/86400.0).round(2)
    label = smart_label(n, "day", "days")
    "#{n} #{label}"
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

  if (u == "m") or u.include?("min")
    t = n
  elsif (u == "s") or u.include?("sec")
    t = n / 60.0
  elsif (u == "h") or u.include?("hour")
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

def listen_for_flags(flags)
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

        if msg
          cmsg = msg.strip

          case cmsg
          when "reset_timer", "quit"
            flags[:reset] = true
          when "inc_timer"
            flags[:inc] = true
          when "dec_timer"
            flags[:dec] = true
          end
        end
      rescue => e
        warn "[timer.rb] Control socket error: #{e}"
      end
    end
  end
end

def start_timer(title, t)
  remaining = (t * 60).to_i
  flags = { reset: false, inc: false, dec: false }
  listen_for_flags(flags)

  while true
    if flags[:reset]
      exit
    end

    # Handle inc/dec flags
    if flags[:inc]
      remaining += 5 * 60
      flags[:inc] = false
    elsif flags[:dec]
      remaining -= 5 * 60
      remaining = 5 if remaining < 5
      flags[:dec] = false
    end

    break if remaining <= 0

    rem = format_time(remaining)
    msg = "#{title}  🚂  #{rem}"
    send_msg(msg)
    sleep 1
    remaining -= 1
  end

  msg = "#{title} Done"
  send_msg(msg)
end

title, t = get_data()
exit if title.empty? || t.nil?
start_timer(title, t)

# Cleanup PID file on exit
at_exit do
  File.delete(pidfile) if File.exist?(pidfile)
end