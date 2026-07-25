require "./spec_helper"

Spectator.describe DockerHealth do
  describe ".handle" do
    it "answers PONG on /ping" do
      response = probe("/ping")
      expect(response.status_code).to eq(200)
      expect(response.body).to eq("PONG")
      expect(response.headers["Content-Type"]).to eq("text/plain")
    end

    # The root path stays alive for healthchecks written before /ping existed.
    it "answers PONG on the root path" do
      response = probe("/")
      expect(response.status_code).to eq(200)
      expect(response.body).to eq("PONG")
    end

    it "answers PONG on /health" do
      response = probe("/health")
      expect(response.status_code).to eq(200)
      expect(response.body).to eq("PONG")
    end

    it "returns 404 on any other path" do
      response = probe("/whatever")
      expect(response.status_code).to eq(404)
    end

    it "ignores the query string when routing" do
      response = probe("/ping?foo=bar")
      expect(response.status_code).to eq(200)
      expect(response.body).to eq("PONG")
    end

    it "answers PONG on a HEAD request to /ping" do
      response = probe("/ping", "HEAD")
      expect(response.status_code).to eq(200)
    end
  end
end
