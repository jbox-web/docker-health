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
    options = {
      "bind"            => "0.0.0.0",
      "port"            => 8080,
      "tls-server-cert" => nil,
      "tls-server-key"  => nil,
    }
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
      parser.on("-b BIND", "--bind=BIND", "Specify the socket to bind") do |socket|
        options["bind"] = socket
      end
      parser.on("-p PORT", "--port=PORT", "Specify the port to bind") do |port|
        options["port"] = port
      end
      parser.on("-c FILE", "--tls-server-cert=FILE", "Specify the port to bind") do |file|
        options["tls-server-cert"] = file
      end
      parser.on("-k FILE", "--tls-server-key=FILE", "Specify the port to bind") do |file|
        options["tls-server-key"] = file
      end
      parser.invalid_option do |flag|
        STDERR.puts "ERROR: #{flag} is not a valid option."
        STDERR.puts parser
        exit 1
      end
    end
    options
  end

  def self.start(options)
    bind = options["bind"].try(&.to_s).not_nil! # ameba:disable Lint/NotNil
    port = options["port"].try(&.to_i).not_nil! # ameba:disable Lint/NotNil

    tls_server_cert = options["tls-server-cert"].try(&.to_s)
    tls_server_key = options["tls-server-key"].try(&.to_s)

    server = HTTP::Server.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "PONG"
    end

    if !tls_server_cert.nil? && !tls_server_key.nil?
      context = OpenSSL::SSL::Context::Server.new
      context.certificate_chain = tls_server_cert
      context.private_key = tls_server_key

      address = server.bind_tls bind, port, context
      puts "Listening on https://#{address}"
    else
      address = server.bind_tcp bind, port
      puts "Listening on http://#{address}"
    end

    server.listen
  end
end

# Start the CLI
unless Crystal.env.test?
  begin
    options = DockerHealth.parse_args!
    DockerHealth.start(options)
  rescue e : Exception
    STDERR.puts e.message
    exit 1
  end
end
