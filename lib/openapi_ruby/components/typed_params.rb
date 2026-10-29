# frozen_string_literal: true

module OpenapiRuby
  module Components
    # Opt-in mixin that derives T::Struct `const` declarations from a
    # component's schema. Requires sorbet-runtime; load via
    # `require "openapi_ruby/sorbet"`.
    #
    #   class Schemas::UserInput < T::Struct
    #     include OpenapiRuby::Components::Base
    #     include OpenapiRuby::Components::TypedParams
    #
    #     schema(type: :object, required: %w[name], properties: {name: {type: :string}})
    #   end
    module TypedParams
      SCALAR_TYPES = {
        "string" => String,
        "integer" => Integer,
        "number" => Float,
        "boolean" => T::Boolean
      }.freeze

      def self.included(base)
        unless base < T::Struct
          raise ArgumentError, "#{base} must inherit from T::Struct to include TypedParams"
        end
        unless base < OpenapiRuby::Components::Base
          raise ArgumentError, "#{base} must include OpenapiRuby::Components::Base before TypedParams"
        end

        base.extend ClassMethods
        base.send(:define_struct_props)
      end

      module ClassMethods
        def schema(definition = nil)
          result = super
          define_struct_props if definition
          result
        end

        private

        def define_struct_props
          definition = _schema_definition
          required = Array(definition["required"])

          (definition["properties"] || {}).each do |name, spec|
            prop_name = name.to_sym
            next if props.key?(prop_name)

            type = struct_type_for(spec)
            if required.include?(name) && !nullable_spec?(spec)
              const prop_name, type
            else
              const prop_name, T.nilable(type), default: nil
            end
          end
        end

        def nullable_spec?(spec)
          spec["nullable"] == true || Array(spec["type"]).include?("null")
        end

        def struct_type_for(spec)
          return struct_class_for_ref(spec["$ref"]) if spec["$ref"]

          type = Array(spec["type"]).reject { |t| t == "null" }.first

          case type
          when *SCALAR_TYPES.keys
            SCALAR_TYPES.fetch(type)
          when "array"
            items = spec["items"]
            T::Array[items ? struct_type_for(items) : T.untyped]
          when "object"
            T::Hash[String, T.untyped]
          else
            T.untyped
          end
        end

        def struct_class_for_ref(ref)
          component = ref.split("/").last
          klass = [module_parent, Object].filter_map { |scope|
            "#{scope}::#{component}".delete_prefix("Object::").safe_constantize
          }.first
          klass ||= Registry.instance.all_registered_classes.find { |c| c.component_name == component }

          unless klass && klass < TypedParams
            raise ArgumentError,
              "#{name}: cannot resolve #{ref} to a class that includes OpenapiRuby::Components::TypedParams"
          end

          klass
        end
      end
    end
  end
end
