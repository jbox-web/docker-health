# Load std libs
require "option_parser"

# Load external libs
require "crystal-env/core"
require "http/server"

# Set environment
Crystal::Env.default("development")

module DockerHealth
  VERSION = "1.0.0"

  def self.parse_args!
    OptionParser.parse do |parser|
      parser.banner = "Usage: docker-health [arguments]"
      parser.on("-v", "--version", "Show version") do
        STDOUT.puts VERSION
        exit 0
      end
      parser.on("-h", "--help", "Show this help") do
        STDOUT.puts parser
        exit 0
      end
      parser.invalid_option do |flag|
        STDERR.puts "ERROR: #{flag} is not a valid option."
        STDERR.puts parser
        exit 1
      end
    end
  end

  def self.start
    server = HTTP::Server.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "PONG"
    end

    address = server.bind_tcp "0.0.0.0", 8080
    puts "Listening on http://#{address}"
    server.listen
  end
end

# Start the CLI
unless Crystal.env.test?
  begin
    DockerHealth.parse_args!
    DockerHealth.start
  rescue e : Exception
    STDERR.puts e.message
    exit 1
  end
end
