# Primalize

Primalize lets you de-evolve your objects into primitive values for serialization. The primary use case is to serialize them into JSON, but once it's in its primitive state, it can be converted into other formats such as XML or CSV.

Primalizers support type checking by letting you specify the types of the resulting properties:

```ruby
class OrderSerializer < Primalize::Single
  attributes(
    id: integer,
    customer_id: integer,
    product_ids: array(integer),
    status: enum(
      'requested',
      'payment_processed',
      'awaiting_shipment',
      'shipped',
      'delivered',
    ),
    signature_required: boolean,
    shipping_address: object(
      address1: string,
      address2: optional(string),
      city: string,
      state: string,
      zip: string,
    ),
    created_at: timestamp,
  )
end

OrderSerializer.new(order).call
# { id: ... }
```

You can also primalize a nested structure of response objects with `Primalize::Many`, replacing the type annotations with the classes of their respective serializers:

```ruby
class PostResponseSerializer < Primalize::Many
  attributes(
    post: PostSerializer,
    author: UserSerializer,
    comments: enumerable(CommentSerializer), # Not just one comment, but *many*
  )
end

# Instantiate it by passing in the pertinent values
serializer = PostResponseSerializer.new(
  post: @post,
  author: @post.author,
  comments: @post.comments,
)

serializer.call
# {
#   post: { ... },
#   author: { ... },
#   comments: [
#     { ... },
#   ],
# }
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'primalize'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install primalize

## Usage

If you need to primalize a single object, you subclass `Primalize::Single` and specify the attributes and types of the result as in the example above.

### Supported types

The complete list of supported types are:

- `integer`: whole numbers
- `float`: floating-point numbers
- `number`: any numeric value
- `string`: text
- `boolean`: explicitly `true` or `false` (not "truthy" or "falsy" values)
- `array(*types)`: an array containing values of the specified types
  - Example: `array(string, integer)`
- `optional(*types)`: any of the specified types or `nil`
  - Example: `optional(string)`, both `"foo"` and `nil` are acceptable values
- `enum(*values)`: must be one of the specified values
  - Example: `enum('requested', 'shipped', 'delivered')`
- `timestamp`: a `Date`, `Time`, or `DateTime` value
- `any(*types)`: any value of the given types
  - Example: `any(string, integer)` will only match on strings and integers
  - If no types are specified, any value will match
- `primalize(YourPrimalizerClass)`: primalizes the specified attribute with the given `Primalize::Single` subclass
  - Example: `primalize(OrderSerializer)`
- `object(**types)`: a hash of the specified structure
  - Example: `object(id: integer, name: string)`
  - Only the required keys need to be specified. The rest of the hash will pass.
  - If no keys are specified, all of them are optional and it will match any hash.

### Attribute coercion

Reducing the object's attributes to a hash isn't all you do in most apps. You may also need to do some coercion. For example, if you have an object whose `city` isn't stored as a string but you need to translate it to one:

```ruby
class ShipmentSerializer < Primalize::Single
  attributes(
    city: string { |city| city.name },
    # ...
  )
end
```

### Virtual attributes

You can also generate attributes that don't exist on the object being primalized by defining methods on the primalizer:

```ruby
class ShipmentSerializer < Primalize::Single
  attributes(
    payment_method: string,
  )

  def payment_method
    if object.paid_with_card?
      'credit_card'
    elsif object.purchase_order?
      'purchase_order'
    elsif object.bill_later?
      'invoice'
    else
      'unknown'
    end
  end
end
```

### Type Checking

By default, subclasses of `Primalize::Single` will raise an `ArgumentError` if there is a mismatch between the types declared in its `attributes` call and what is passed in to be primalized. In production, you might not want that to happen, so you can change that in your production config:

```ruby
Primalize::Single.type_mismatch_handler = proc do |primalizer, attr, type, value|
  msg = "Type mismatch: #{primalizer.name}##{attr} is expected to be #{type.inspect}, but is a #{value.inspect}\n"
  msg << caller.grep(Regexp.new(Rails.root)).join("\n") # Include application stack trace

  Slack.notify '#bugs', msg
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jgaskins/primalize. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Primalize project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/jgaskins/primalize/blob/master/CODE_OF_CONDUCT.md).
