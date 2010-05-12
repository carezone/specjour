module Specjour::Cucumber
  ::Term::ANSIColor.coloring = true
  class DistributedFormatter < ::Cucumber::Formatter::Progress

    def initialize(step_mother, io, options)
      @step_mother = step_mother
      @io = io
      @options = options
      @failing_scenarios = []
      @step_summary = []
    end

    def after_features(features)
      print_summary
      step_mother.scenarios.clear
      step_mother.steps.clear
    end

    def prepare_failures
      @failures = step_mother.scenarios(:failed).select { |s| s.is_a?(Cucumber::Ast::Scenario) }

      if !@failures.empty?
        @failures.each do |failure|
          failure_message = ''
          failure_message += format_string("cucumber " + failure.file_colon_line, :failed) +
          failure_message += format_string(" # Scenario: " + failure.name, :comment)
          @failing_scenarios << failure_message
        end
      end
    end

    def prepare_elements(elements, status, kind)
      output = ''
      if elements.any?
        output += format_string("\n(::) #{status} #{kind} (::)\n", status)
        output += "\n"
      end

      elements.each_with_index do |element, i|
        if status == :failed
          output += print_exception(element.exception, status, 0)
        else
          output += format_string(element.backtrace_line, status)
          output += "\n"
        end
        @step_summary << output unless output.blank?
      end
    end

    def prepare_steps(type)
      prepare_elements(step_mother.scenarios(type), type, 'steps')
    end

    def print_exception(e, status, indent)
      format_string("#{e.message} (#{e.class})\n#{e.backtrace.join("\n")}".indent(indent), status)
    end

    def print_summary
      prepare_failures
      prepare_steps(:failed)
      prepare_steps(:undefined)

      @io.send_message(:cucumber_summary=, to_hash)
    end

    OUTCOMES = [:failed, :skipped, :undefined, :pending, :passed]

    def to_hash
      hash = {}
      [:scenarios, :steps].each do |type|
        hash[type] = {}
        OUTCOMES.each do |outcome|
          hash[type][outcome] = step_mother.send(type, outcome).size
        end
      end
      hash.merge!(:failing_scenarios => @failing_scenarios, :step_summary => @step_summary)
      hash
    end

  end
end