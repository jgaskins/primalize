require 'json'
require 'date'

module Primalize
  class Single
    @type_mismatch_handler = proc do |attr, type, value|
      raise TypeError, "#{self}##{attr} is specified as #{type.inspect}, but is #{value.inspect}"
    end

    class << self

      def attributes attrs={}
        @attributes ||= {}

        add_attributes attrs

        @attributes
      end

      def add_attributes attrs
        return if attrs.none?

        @attributes.merge! attrs

        attrs.each do |attr, type|
          define_method attr do
            value = type.coerce(object.public_send(attr))
            if type === value
              value
            else
              self.class.type_mismatch_handler.call attr, type, value
            end
          end
        end
      end

      def integer &coerce
        Integer.new(&coerce)
      end

      def string &coerce
        String.new(&coerce)
      end

      def boolean &coerce
        enum(true, false, &coerce)
      end

      def array *types, &coerce
        Array.new(types, &coerce)
      end

      def object **types, &coerce
        Object.new(types, &coerce)
      end

      def float &coerce
        Float.new(&coerce)
      end

      def optional *types, &coerce
        Optional.new(types, &coerce)
      end

      def enum *values, &coerce
        Enum.new(values, &coerce)
      end

      def timestamp &coerce
        Timestamp.new(&coerce)
      end

      def type_mismatch_handler= handler
        @type_mismatch_handler = handler
      end

      def type_mismatch_handler
        if @type_mismatch_handler
          @type_mismatch_handler
        else
          superclass.type_mismatch_handler
        end
      end

      def inspect
        "#{name}(#{attributes.map { |attr, type| "#{attr}: #{type.inspect}" }.join(', ') })"
      end
    end

    attr_reader :object

    def initialize object
      @object = object
    end

    def call
      self.class.attributes.each_with_object({}) do |(attr, _), hash|
        hash[attr] = public_send(attr)
      end
    end

    # TYPES

    DEFAULT_COERCION = proc { |arg| arg } # Don't coerce by default

    module Type
      def coerce *args
        (@coercion || DEFAULT_COERCION).call(*args)
      end
    end

    class Integer
      include Type

      def initialize &coercion
        @coercion = coercion
      end

      def === value
        ::Integer === value
      end

      def inspect
        'integer'
      end
    end

    class Float
      include Type

      def initialize &coercion
        @coercion = coercion
      end

      def === value
        ::Float === value
      end

      def inspect
        'float'
      end
    end

    class String
      include Type

      def initialize &coercion
        @coercion = coercion
      end

      def === value
        ::String === value
      end

      def inspect
        'string'
      end
    end

    class Array
      include Type

      def initialize types, &coercion
        @types = types
        @coercion = coercion
      end

      def === value
        return false unless ::Array === value
        value.all? do |item|
          @types.any? { |type| type === item }
        end
      end

      def inspect
        "array(#{@types.map(&:inspect).join(', ')})"
      end
    end

    class Enum
      include Type

      def initialize values, &coercion
        @values = values
        @coercion = coercion
      end

      def === value
        @values.include? value
      end

      def coerce value
        super value, @values
      end

      def inspect
        "enum(#{@values.map(&:inspect).join(', ')})"
      end
    end

    class Object
      include Type

      def initialize types, &coercion
        @types = types
        @coercion = coercion || DEFAULT_COERCION
      end

      def === value
        return false unless ::Hash === value

        @types.all? do |attr, type|
          type === value[attr]
        end
      end

      def inspect
        "object(#{@types.map { |attr, type| "#{attr}: #{type.inspect}" }.join(', ')})"
      end
    end

    class Timestamp
      include Type

      TYPES = [Time, Date, DateTime].freeze

      def === value
        TYPES.any? { |type| type === value }
      end

      def inspect
        'timestamp'
      end
    end

    class Optional
      include Type

      def initialize types, &coercion
        @types = types
        @coercion = coercion
      end

      def === value
        value.nil? || @types.any? { |type| type === value }
      end

      def inspect
        "optional(#{@types.map(&:inspect).join(', ')})"
      end
    end
  end
end
