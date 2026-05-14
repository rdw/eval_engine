require "concurrent"

module EvalEngine
  class Runner
    class ExamplesInvalid < StandardError
      attr_reader :failures

      def initialize(failures)
        @failures = failures
        super(failures.map { |f| "#{f[:label]}:\n#{f[:message]}" }.join("\n\n"))
      end
    end

    def initialize(eval_class:, only: nil, eval_root: nil, parallelism: nil)
      @eval_class = eval_class
      @only = only
      @eval_root = eval_root || EvalEngine.configuration.eval_root
      @parallelism = parallelism || EvalEngine.configuration.parallelism
      @callback_mutex = Mutex.new
    end

    def run!(&on_example_finished)
      raise ArgumentError, "#{@eval_class.name} must declare an output_type" unless @eval_class.output_type

      @on_example_finished = on_example_finished

      examples = load_examples
      examples = examples.select { |ex| @only.include?(ex.key) } if @only

      validate_examples!(examples)

      run =
        Run.create!(
          eval_name: @eval_class.eval_name,
          status: :running,
          started_at: Time.current,
          example_count: examples.length
        )

      execute_examples(run, examples)
      run.update!(status: :completed, finished_at: Time.current)
      run
    end

    private

    def load_examples
      dir = Example.examples_dir_for(@eval_root, @eval_class.eval_name)
      Example.load_all(dir)
    end

    def validate_examples!(examples)
      input_type = @eval_class.input_type
      output_type = @eval_class.output_type
      failures = []

      examples.each do |example|
        label = example.path || example.key

        if input_type
          tree = input_type.validate(example.input)
          failures << { label: "#{label} (input)", message: Types::ValidationError.format_tree(tree) } if tree
        end

        tree = output_type.validate(example.expected)
        failures << { label: "#{label} (expected)", message: Types::ValidationError.format_tree(tree) } if tree
      end

      raise ExamplesInvalid, failures if failures.any?
    end

    def execute_examples(run, examples)
      if @parallelism > 1 && examples.length > 1
        execute_parallel(run, examples)
      else
        examples.each { |example| execute_one(run, example) }
      end
    end

    def execute_parallel(run, examples)
      pool = Concurrent::FixedThreadPool.new(@parallelism)
      futures =
        examples.map do |example|
          Concurrent::Promises.future_on(pool) do
            ActiveRecord::Base.connection_pool.with_connection { execute_one(run, example) }
          end
        end
      futures.each(&:wait!)
    ensure
      pool&.shutdown
      pool&.wait_for_termination
    end

    def execute_one(run, example)
      instance = @eval_class.new(eval_root: @eval_root)
      output_type = @eval_class.output_type
      started_at = Time.current

      begin
        output = instance.generate(example.input)
        output_type.validate!(output)
        score_tree = output_type.match(output, example.expected)
        save_example_result(
          run,
          example,
          started_at,
          status: :completed,
          output: output,
          score_tree: score_tree,
          score: score_tree["score"]
        )
      rescue StandardError => e
        save_example_result(
          run,
          example,
          started_at,
          status: :errored,
          score: 0.0,
          error: "#{e.class}: #{e.message}\n#{Array(e.backtrace).join("\n")}"
        )
      end
    end

    def save_example_result(run, example, started_at, **attrs)
      saved =
        RunExample.create!(
          run: run,
          example_key: example.key,
          input: example.input,
          expected: example.expected,
          started_at: started_at,
          finished_at: Time.current,
          **attrs
        )
      notify_finished(saved)
      saved
    end

    def notify_finished(example_row)
      return unless @on_example_finished

      @callback_mutex.synchronize { @on_example_finished.call(example_row) }
    end
  end
end
