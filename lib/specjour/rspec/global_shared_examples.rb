# Specjour needs to track shared examples defined outside of contexts, RSpec tracks
# them in the _world_ but that is reset for each spec run.
module GlobalSharedExamples
  def shared_examples(*args, &block)
    GlobalRegistry.add_group(*args, &block)
  end

  def share_as(name, &block)
    RSpec.deprecate("Rspec::Core::SharedExampleGroup#share_as",
                    "RSpec::SharedContext or shared_examples")
    GlobalRegistry.add_const(name, &block)
  end

  alias_method :shared_context, :shared_examples
  alias_method :share_examples_for, :shared_examples
  alias_method :shared_examples_for, :shared_examples

  module GlobalRegistry
    include RSpec::Core::SharedExampleGroup::Registry

    extend self

    def add_group(*args, &block)
      ensure_block_has_source_location(block, caller[1])

      if key? args.first
        key = args.shift
        warn_if_key_taken key, block
        shared_example_groups[key] = block
      end

      unless args.empty?
        mod = Module.new
        (class << mod; self; end).send(define_method, :extended) do |host|
          host.class_eval(&block)
        end
        RSpec.configuration.extend mod, *args
      end
    end

    def add_const(name, &block)
      if Object.const_defined?(name)
        mod = Object.const_get(name)
        raise_name_error unless mod.created_from_caller(caller)
      end

      mod = Module.new do
        @shared_block = block
        @caller_line = caller.last

        def self.created_from_caller(other_caller)
          @caller_line == other_caller.last
        end

        def self.included(kls)
          kls.describe(&@shared_block)
          kls.children.first.metadata[:shared_group_name] = name
        end
      end

      shared_const = Object.const_set(name, mod)
      shared_example_groups[shared_const] = block
    end

    def shared_example_groups
      @shared_example_groups ||= {}
    end

    private

    def example_block_for(key)
      shared_example_groups[key]
    end
  end
end

module RSpec
  module Core
    class ExampleGroup
      def self.find_and_eval_shared(label, name, *args, &customization_block)
        shared_block = world.shared_example_groups[name] ||
          GlobalSharedExamples::GlobalRegistry.shared_example_groups[name]

        raise ArgumentError,
          "Could not find shared #{label} #{name.inspect}" unless shared_block

        module_eval_with_args(*args, &shared_block)
        module_eval(&customization_block) if customization_block
      end
    end
  end
end

extend GlobalSharedExamples
