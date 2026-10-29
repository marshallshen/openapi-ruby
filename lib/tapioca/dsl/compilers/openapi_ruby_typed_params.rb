# typed: strict
# frozen_string_literal: true

require "openapi_ruby/sorbet"

module Tapioca
  module Dsl
    module Compilers
      # Emits RBI `const` readers for T::Struct components that include
      # OpenapiRuby::Components::TypedParams.
      #
      #   bin/tapioca dsl Schemas::UserInput
      class OpenapiRubyTypedParams < Compiler
        extend T::Sig

        ConstantType = type_member { {fixed: T.class_of(T::Struct)} }

        sig { override.returns(T::Enumerable[Module]) }
        def self.gather_constants
          all_classes.select { |klass| klass < OpenapiRuby::Components::TypedParams }
        end

        sig { override.void }
        def decorate
          root.create_path(constant) do |klass|
            constant.props.each do |name, rules|
              klass.create_method(name.to_s, return_type: rules.fetch(:type_object).to_s)
            end
          end
        end
      end
    end
  end
end
