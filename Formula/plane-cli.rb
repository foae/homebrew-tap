# Rendered from the immutable archive hashes by make snapshot/package-release.
class PlaneCli < Formula
  desc "JSON-first CLI for the Plane public API"
  homepage "https://github.com/foae/plane-cli"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/foae/plane-cli/releases/download/v1.0.3/plane-cli_1.0.3_darwin_arm64.tar.gz"
      sha256 "cf4c62fbb4a833d2abaab96c87729513115e12363a4ba1a43ed7fd3f9619efab"
    end
    on_intel do
      url "https://github.com/foae/plane-cli/releases/download/v1.0.3/plane-cli_1.0.3_darwin_amd64.tar.gz"
      sha256 "66cf5e8cebcbfdebd0e7acf1d72bb5531fde47d04d5a919cd6f3f178135dc98b"
    end
  end
  on_linux do
    on_arm do
      url "https://github.com/foae/plane-cli/releases/download/v1.0.3/plane-cli_1.0.3_linux_arm64.tar.gz"
      sha256 "0d388a4827f6f1e38f375e6f8e242bd4bb84c9b002af671db1a712c7b2773bef"
    end
    on_intel do
      url "https://github.com/foae/plane-cli/releases/download/v1.0.3/plane-cli_1.0.3_linux_amd64.tar.gz"
      sha256 "4af0688ba65efba8416cb8a5fcfe7bf6d30ba7bd86d0b205ef32453d36f63b2b"
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
