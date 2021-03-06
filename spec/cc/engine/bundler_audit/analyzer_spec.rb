require "spec_helper"

module CC::Engine::BundlerAudit
  describe Analyzer do
    describe "#run" do
      it "raises an error when no Gemfile.lock exists" do
        directory = fixture_directory("no_gemfile_lock")

        expect { Analyzer.new(directory: directory).run }.
          to raise_error(Analyzer::GemfileLockNotFound)
      end

      it "does nothing if Gemfile.lock is not in include_paths" do
        with_written_config(include_paths: %w[Gemfile src/]) do |path|
          directory = fixture_directory("unpatched_versions")
          issues = analyze_directory(directory, engine_config_path: path)
          expect(issues).to eq([])
        end
      end

      it "emits issues for unpatched gems in Gemfile.lock" do
        with_default_written_config do |path|
          directory = fixture_directory("unpatched_versions")

          issues = analyze_directory(directory, engine_config_path: path)

          expect(expected_issues("unpatched_versions")).to be_present_in(issues)
        end
      end

      it "emits issues for insecure sources in Gemfile.lock" do
        with_default_written_config do |path|
          directory = fixture_directory("insecure_sources")

          issues = analyze_directory(directory, engine_config_path: path)

          expect(expected_issues("insecure_sources")).to be_present_in(issues)
        end
      end

      it "Supports alphanumeric gem versions like 3.0.0.rc.2 or 2.2.2.backport2" do
        with_default_written_config do |path|
          directory = fixture_directory("alphanumeric_versions")

          issues = analyze_directory(directory, engine_config_path: path)

          expect(expected_issues("alphanumeric_versions")).to be_present_in(issues)
        end
      end

      it "logs to stderr when we encounter an unsupported vulnerability" do
        with_default_written_config do |path|
          directory = fixture_directory("unpatched_versions")
          stderr = StringIO.new

          stub_vulnerability("UnhandledVulnerability")

          analyze_directory(directory, stderr: stderr, engine_config_path: path)

          expect(stderr.string).to eq("Unsupported vulnerability: UnhandledVulnerability")
        end
      end

      it "supports an alternate path to Gemfile.lock" do
        with_written_config(config: { path: "sub/Gemfile.lock" }) do |path|
          directory = fixture_directory("alternate_path")

          issues = analyze_directory(directory, engine_config_path: path)

          expect(issues.first["location"]["path"]).to eq "sub/Gemfile.lock"
        end
      end

      def with_default_written_config
        with_written_config(include_paths: %w[Gemfile Gemfile.lock]) do |path|
          yield(path)
        end
      end

      def with_written_config(config: {}, include_paths: ["./"])
        config = { config: config, include_paths: include_paths }

        Tempfile.open("engine_config") do |fh|
          fh.write(config.to_json)
          fh.flush
          fh.rewind

          yield fh.path
        end
      end

      def analyze_directory(directory, engine_config_path: Analyzer::DEFAULT_CONFIG_PATH, stdout: StringIO.new, stderr: StringIO.new)
        audit = Analyzer.new(directory: directory, engine_config_path: engine_config_path, stdout: stdout, stderr: stderr)
        audit.run

        stdout.string.split("\0").map { |issue| JSON.load(issue) }
      end

      def stub_vulnerability(name)
        scanner = double(:scanner)
        vulnerability = double(:vulnerability, class: double(name: name))

        allow(Bundler::Audit::Scanner).to receive(:new).and_return(scanner)
        allow(scanner).to receive(:scan).and_yield(vulnerability)
      end

      def expected_issues(fixture)
        path = File.join(fixture_directory(fixture), "issues.json")
        body = File.read(path)
        JSON.load(body)
      end

      def fixture_directory(fixture)
        File.join(Dir.pwd, "spec", "fixtures", fixture)
      end
    end
  end
end
