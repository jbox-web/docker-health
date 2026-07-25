require "spectator"
require "crystal-env/spec"

require "../src/docker-health"

# Drives the HTTP handler in isolation, without binding a socket:
# builds a request/response pair over an in-memory IO and parses back
# what the handler wrote, so specs can assert on status and body.
def probe(path : String, method : String = "GET") : HTTP::Client::Response
  io = IO::Memory.new
  request = HTTP::Request.new(method, path)
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)

  DockerHealth.handle(context)
  response.close

  HTTP::Client::Response.from_io(io.rewind)
end
