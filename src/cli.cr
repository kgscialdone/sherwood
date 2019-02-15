require "./sherwood"

def run(args : Array(String))
  file = nil
  case args[0]?.try(&.downcase)
    when "help" then puts <<-HELP
    Usage: #{File.basename(Process.executable_path || "sherwood")} <command> [arguments]
        run <filename> (default)          Execute a file as Sherwood bytecode.
        help                              Show this help.
    HELP

    when "run" then (file = File.open(ARGV[1])) rescue STDERR.puts "Expected filename, got nothing"
    else            (file = File.open(ARGV[0])) rescue run(["help"])
  end

  Sherwood.new.runBytecode(file) if file
end

run(ARGV)
