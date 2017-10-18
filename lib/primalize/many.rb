module Primalize
  class Many
    def self.attributes attrs={}
      @attributes ||= {}
      add_attributes attrs

      @attributes
    end

    def self.add_attributes attrs
      return if attrs.none?

      attrs.each do |attr, serializer_class|
        if serializer_class.nil?
          raise TypeError, "Serializer for #{self}##{attr} cannot be nil"
        end
      end

      @attributes.merge! attrs
    end

    def self.enumerable serializer_class
      Class.new(Enumerable) do
        define_method :call do
          @enumerable.map { |item| serializer_class.new(item).call }
        end

        define_singleton_method :inspect do
          "enumerable(#{serializer_class.inspect})"
        end

        define_singleton_method :attributes do
          serializer_class.attributes
        end
      end
    end

    def self.optional serializer_class
      Class.new(Optional) do
        define_method :initialize do |object|
          return if object.nil?

          @object = object
          @serializer = serializer_class.new(object)
        end
      end
    end

    class Optional
      def call
        return nil if @object.nil?

        @serializer.call
      end
    end

    class Enumerable
      def initialize enumerable
        validate! enumerable

        @enumerable = enumerable
      end

      def validate! enumerable
        unless %w(each map).all? { |msg| enumerable.respond_to? msg }
          raise ArgumentError, "#{self.class.inspect} must receive an Enumerable object, received #{enumerable.inspect}"
        end
      end

      def call
        raise RuntimeError,
          "Called #{inspect}#call. Please use Primalize::Many.enumerable to create primalizers for this."
      end
    end

    def self.inspect
      attrs = attributes
        .map { |attr, serializer| "#{attr}: #{serializer.inspect}" }
        .join(', ')

      "#{name}(#{attrs})"
    end

    def initialize attributes
      validate_attributes! attributes

      @attributes = attributes
    end

    def validate_attributes! attributes
      attr_map = self.class.attributes
      all_required_attributes_provided = attr_map
        .each_key
        .all? do |key|
          attributes[key] || (attr_map[key].superclass == Optional)
        end

      unless all_required_attributes_provided
        non_nil_keys = attributes
          .select { |_attr, value| value }
          .map { |attr, _value| attr }

        missing_keys = self.class.attributes.keys - non_nil_keys

        raise ArgumentError,
          "#{self.class} is missing the following keys: #{missing_keys.map(&:inspect).join(', ')}"
      end
    end

    def call
      self.class.attributes.each_with_object({}) do |(attr, serializer_class), hash|
        hash[attr] = serializer_class.new(@attributes.fetch(attr)).call
      end
    end

    def to_json
      call.to_json
    end

    def to_csv attr
      CSV.generate do |csv|
        result = call[attr]

        csv << self.class.attributes[attr].attributes.keys

        case result
        when Hash
          csv << result.values
        when Array
          result.each do |hash|
            csv << hash.values
          end
        end
      end
    end
  end
end
