module CC
  module Engine
    module BundlerAudit
      class Analyzer
        GemfileLockNotFound = Class.new(StandardError)

        def initialize(directory:, io: STDOUT)
          @directory = directory
          @io = io
        end

        def run
          if gemfile_lock_exists?
            Dir.chdir(directory) do
              Bundler::Audit::Scanner.new.scan do |vulnerability|
                issue = Issue.new(vulnerability, gemfile_lock_lines)

                io.print("#{issue.to_json}\0")
              end
            end
          else
            raise GemfileLockNotFound, "No Gemfile.lock found."
          end
        end

        private

        attr_reader :directory, :io

        def gemfile_lock_lines
          @gemfile_lock_lines ||= File.open(gemfile_lock_path).lines.to_a
        end

        def gemfile_lock_exists?
          File.exist?(gemfile_lock_path)
        end

        def gemfile_lock_path
          File.join(directory, "Gemfile.lock")
        end
      end
    end
  end
end