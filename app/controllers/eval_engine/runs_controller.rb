module EvalEngine
  class RunsController < ApplicationController
    def create
      eval_name = params[:name]
      only = parse_only(params[:only])

      eval_class = Loader.load_eval(eval_name)
      run = Runner.new(eval_class: eval_class, only: only).start!
      RunJob.perform_later(run.id, only: only)
      redirect_to eval_path(eval_name), notice: run_notice(eval_name, only)
    rescue Loader::NotFoundError => e
      redirect_to root_path, alert: e.message
    rescue Runner::ExamplesInvalid => e
      redirect_to eval_path(eval_name), alert: "Invalid examples:\n#{e.message}"
    end

    def destroy
      run = Run.where(eval_name: params[:name]).find(params[:id])
      run.destroy!
      redirect_to eval_path(params[:name]), notice: "Run ##{run.id} deleted."
    end

    private

    def parse_only(value)
      return nil if value.blank?

      Array(value).flat_map { |v| v.to_s.split(",") }.map(&:strip).reject(&:empty?)
    end

    def run_notice(eval_name, only)
      return "Started run of #{eval_name} (#{only.join(", ")})." if only

      "Started run of #{eval_name}."
    end
  end
end
