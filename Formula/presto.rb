class Presto < Formula
  desc "Distributed SQL query engine for big data"
  homepage "https://prestodb.io"
  url "https://search.maven.org/remotecontent?filepath=com/facebook/presto/presto-server/0.215/presto-server-0.215.tar.gz"
  sha256 "c58138a84b15a04759e93bc73525d186a31926119fb1569553909ee11379ef57"

  bottle :unneeded

  depends_on :java => "1.8+"

  resource "presto-cli" do
    url "https://search.maven.org/remotecontent?filepath=com/facebook/presto/presto-cli/0.215/presto-cli-0.215-executable.jar"
    sha256 "6ca3f4909ba9055dc2bb872855bbf2b9480aaab633f80bcf2b0741c66b48f84a"
  end

  def install
    libexec.install Dir["*"]

    (libexec/"etc/node.properties").write <<~EOS
      node.environment=production
      node.id=ffffffff-ffff-ffff-ffff-ffffffffffff
      node.data-dir=#{var}/presto/data
    EOS

    (libexec/"etc/jvm.config").write <<~EOS
      -server
      -Xmx16G
      -XX:+UseG1GC
      -XX:G1HeapRegionSize=32M
      -XX:+UseGCOverheadLimit
      -XX:+ExplicitGCInvokesConcurrent
      -XX:+HeapDumpOnOutOfMemoryError
      -XX:+ExitOnOutOfMemoryError
    EOS

    (libexec/"etc/config.properties").write <<~EOS
      coordinator=true
      node-scheduler.include-coordinator=true
      http-server.http.port=8080
      query.max-memory=5GB
      query.max-memory-per-node=1GB
      discovery-server.enabled=true
      discovery.uri=http://localhost:8080
    EOS

    (libexec/"etc/log.properties").write "com.facebook.presto=INFO"

    (libexec/"etc/catalog/jmx.properties").write "connector.name=jmx"

    (bin/"presto-server").write <<~EOS
      #!/bin/bash
      exec "#{libexec}/bin/launcher" "$@"
    EOS

    resource("presto-cli").stage do
      bin.install "presto-cli-#{version}-executable.jar" => "presto"
    end
  end

  def post_install
    (var/"presto/data").mkpath
  end

  def caveats; <<~EOS
    Add connectors to #{libexec}/etc/catalog/. See:
    https://prestodb.io/docs/current/connector.html
  EOS
  end

  plist_options :manual => "presto-server run"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>RunAtLoad</key>
        <true/>
        <key>AbandonProcessGroup</key>
        <true/>
        <key>WorkingDirectory</key>
        <string>#{opt_libexec}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/presto-server</string>
          <string>run</string>
        </array>
      </dict>
    </plist>
  EOS
  end

  test do
    system bin/"presto-server", "run", "--help"
    assert_equal "Presto CLI #{version}", shell_output("#{bin}/presto --version").chomp
  end
end
