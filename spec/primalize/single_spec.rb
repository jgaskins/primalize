require 'primalize/single'

module Primalize
  RSpec.describe Single do
    serializer_class = Class.new(Single) do
      attributes(
        id: integer,
        name: string,
        nicknames: array(string),
        active: boolean,
        options: object(
          color: string,
          count: integer,
        ),
        rating: float,
        address: optional(string),
        state: enum(1, 2, 3, 4),
      )
    end
    let(:default_attrs) do
      {
        id: 123,
        name: 'Foo',
        nicknames: %w(Bar Baz),
        active: true,
        options: {
          color: 'red',
          count: 12,
        },
        rating: 3.5,
        address: '123 Main St',
        state: 1,
      }
    end

    it 'serializes to a hash' do
      serializer = serializer_class.new(double(default_attrs))

      expect(serializer.call).to eq(default_attrs)
    end

    it 'allows nils for optional types' do
      serializer = serializer_class.new(double(default_attrs.merge(address: nil)))

      expect(serializer.call.fetch(:address)).to be_nil
    end

    [
      { id: 'abc' },
      { id: nil },
      { name: 123 },
      { name: nil },
      { nicknames: 'single string instead of an array' },
      { nicknames: nil },
      { active: nil },
      { active: 1 },
      { active: 'true' },
      { options: {} }, # The right type, but without required keys
      { options: [] },
      { options: 12 },
      { rating: nil },
      { rating: 'abc' },
      { address: 123 },
    ].each do |attrs|
      attr, value = attrs.first
      type = serializer_class.attributes[attr].inspect

      it "raises an error if an expected #{type} is actually a #{value.class}" do
        serializer = serializer_class.new(double(default_attrs.merge(attr => value)))

        expect { serializer.call }.to raise_error TypeError
      end
    end

    it 'allows a handler to be set on a type mismatch' do
      serializer_class.type_mismatch_handler = proc do |attr, type, value|
        expect(attr).to eq :name
        expect(value).to eq 12
        expect(type).to be_a Single::String
      end

      serializer = serializer_class.new(double(default_attrs.merge(name: 12)))

      serializer.call
    end

    it 'allows overriding the method from the object to coerce values' do
      serializer_class = Class.new(Single) do
        attributes(
          name: string,
        )

        def name
          object.name.capitalize
        end
      end
      object = double(name: 'jamie')

      serializer = serializer_class.new(object)

      expect(serializer.call).to eq(name: 'Jamie')
    end

    it 'allows blocks to coerce values' do
      serializer_class = Class.new(Single) do
        attributes(
          id: integer { |value| value.abs },
          name: string { |value| value.to_s.capitalize },
          nicknames: array(string) { |value| value.map(&:downcase) },
          active: boolean { |value| value == 'true' },
          options: object(
            color: string,
            count: integer,
          ) { |value|
            {
              color: 'black',
              count: 0,
            }.merge(value.to_h)
          },
          rating: float { |value| value.to_f.abs },
          address: optional(string) { |value| 'omg' },
          state: enum(1, 2, 3, 4) { |value, allowed_values|
            if allowed_values.include?(value)
              value
            else
              allowed_values.first
            end
          },
        )
      end

      object = double(
        id: -123,
        name: 'jamie',
        nicknames: %w(Foo Bar Baz),
        active: 'true',
        options: {},
        rating: -5.0,
        address: 'this string is ignored',
        state: 12,
      )

      expect(serializer_class.new(object).call).to eq(
        id: 123,
        name: 'Jamie',
        nicknames: ['foo', 'bar', 'baz'],
        active: true,
        options: {
          color: 'black',
          count: 0,
        },
        rating: 5.0,
        address: 'omg',
        state: 1,
      )
    end

    it 'outputs a pretty inspect' do
      def serializer_class.name
        'StuffSerializer'
      end

      # Wacky transformations to make the expected output easier to read
      expected = <<~EOF.strip.gsub(/\s+/, ' ').gsub(/(\() | (\))/) { |match| match.strip }
        StuffSerializer(
          id: integer,
          name: string,
          nicknames: array(string),
          active: enum(true, false),
          options: object(
            color: string,
            count: integer
          ),
          rating: float,
          address: optional(string),
          state: enum(1, 2, 3, 4)
        )
      EOF

      expect(serializer_class.inspect).to eq expected
    end
  end
end
