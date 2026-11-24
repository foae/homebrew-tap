# Rendered from the immutable archive hashes by make snapshot/package-release.
class PlaneCli < Formula
  desc "JSON-first CLI for the Plane public API"
  homepage "https://github.com/foae/plane-cli"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/foae/plane-cli/releases/download/v1.1.1/plane-cli_1.1.1_darwin_arm64.tar.gz"
      sha256 "2586cf2730d395d2b7096de8370657261b3ee1f99f27c9504da9f99200a27740"
    end
    on_intel do
      url "https://github.com/foae/plane-cli/releases/download/v1.1.1/plane-cli_1.1.1_darwin_amd64.tar.gz"
      sha256 "54a04d3c6db6041eee6aafa52f9e461a8ae2bf5c378474d331585caad1c7aa50"
    end
  end
  on_linux do
    on_arm do
      url "https://github.com/foae/plane-cli/releases/download/v1.1.1/plane-cli_1.1.1_linux_arm64.tar.gz"
      sha256 "c4d0385e843836a9b61186d518dd3f20b73a82fbfa2088e8d6fad5d2aaa0f6fb"
    end
    on_intel do
      url "https://github.com/foae/plane-cli/releases/download/v1.1.1/plane-cli_1.1.1_linux_amd64.tar.gz"
      sha256 "656a78e3186b2cb75e0c7582462cfb0a24a31d451017e4fb4465e613b92332f5"
    end
  end

  def install
    bin.install "plane-cli"
  end

  test do
    require "json"
    require "socket"
    require "timeout"
    assert_equal "1", JSON.parse(shell_output("#{bin}/plane-cli version"))["schema_version"].to_s
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    pid = fork do
      Timeout.timeout(10) do
        socket = server.accept
        request = socket.gets
        raise "unexpected route: #{request}" if request != "GET /api/v2/workspaces/test/projects/ HTTP/1.1\r\n"

        headers = []
        while (line = socket.gets) && line != "\r\n"
          headers << line
        end
        raise "unexpected auth" if headers.any? { |line| line.downcase.start_with?("authorization:", "x-api-key:") }

        body = JSON.generate({
          "results" => [{ "id" => "project-fixture", "name" => "Packaged CLI" }],
          "next_cursor" => nil, "next_page_results" => false
        })
        socket.write "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" \
                     "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
        socket.close
      end
      exit! 0
    rescue => e
      warn e.message
      exit! 1
    end
    server.close
    begin
      ENV["PLANE_CLI_CONFIG_DIR"] = (testpath/"config").to_s
      command = "#{bin}/plane-cli project list --api-version v2 --auth-mode external " \
                "--base-url http://127.0.0.1:#{port} --workspace test"
      result = JSON.parse(shell_output(command))
      assert_equal "project-fixture", result.fetch("data").fetch("results").first.fetch("id")
      status = Timeout.timeout(12) { Process.wait2(pid).last }
      pid = nil
      assert_predicate status, :success?
    ensure
      begin
        Process.kill("TERM", pid) if pid
      rescue Errno::ESRCH
        nil
      end
      begin
        Process.wait(pid) if pid
      rescue Errno::ECHILD
        nil
      end
    end
  end
end
