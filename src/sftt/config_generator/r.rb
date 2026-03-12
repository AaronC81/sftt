module Sftt
  module ConfigGenerator
    module R
      class ExecutionError < StandardError
      end

      def self.execute_script(*statements)
        system("Rscript", *statements.flat_map { ["-e", it] })
        unless $?.success?
          raise ExecutionError, 'R execution failed'
        end
        nil
      end
    end
  end
end
