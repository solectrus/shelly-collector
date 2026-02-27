class StdoutLogger
  def initialize
    # Flush output immediately
    $stdout.sync = true
  end

  def info(message, newline: true)
    if newline
      puts message
    else
      print message
    end
  end

  def success(message)
    # Green text by using ANSI escape code
    puts "\e[32m#{message}\e[0m"
  end

  def warn(message)
    # Yellow text by using ANSI escape code
    puts "\e[33m#{message}\e[0m"
  end

  def error(message)
    # Red text by using ANSI escape code
    puts "\e[31m#{message}\e[0m"
  end
end
