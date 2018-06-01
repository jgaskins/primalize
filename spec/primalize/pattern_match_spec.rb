require 'primalize/single'
require 'securerandom'
require 'ostruct'

module Primalize
  matched = true

  serializer_class = Class.new(Primalize::Single) do
    self.type_mismatch_handler = proc { matched = false }

    attributes(
      id: match(/\w{8}(-\w{4}){3}-\w{12}/), # UUID
      price: match(0..10) { |price| price.to_f },
      variant: object(
        name: match(/HI/) { |name| name.upcase },
      ),
    )
  end

  RSpec.describe 'pattern matching' do
    let(:model) do
      OpenStruct.new(
        id: SecureRandom.uuid,
        price: 10,
        variant: {
          name: 'hi',
        },
      )
    end

    before { matched = true }

    {
      id: 'nope',
      price: 11,
    }.each do |attribute, incorrect_value|
      it "invokes the type mismatch when #{attribute} is #{incorrect_value}" do
        model.send "#{attribute}=", incorrect_value

        serializer_class.new(model).call

        expect(matched).to eq false
      end
    end

    it 'serializes the value when the pattern does match' do
      expect(serializer_class.new(model).call)
        .to match(
          id: model.id,
          price: model.price,
          variant: {
            name: 'HI', # gets upcased by coercion
          },
        )
      expect(matched).to eq true # Assert that the mismatch handler was not called
    end
  end
end
