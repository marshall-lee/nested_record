# NestedRecord

This gem is for mapping of json fields on `ActiveModel` objects!

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nested_record'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nested_record

## Usage

Use `nested_record` to define nested associations on `ActiveRecord` models via JSON attributes.

First add `json` column into your database:

```ruby
change_table :users do |t|
  t.json :profile
end
```

Then define association using `has_one_nested` macro:

```ruby
class User < ActiveRecord::Base
  include NestedRecord::Macro

  has_one_nested :profile
end
```

Or you can include the `Macro` globally:

```ruby
class ApplicationRecord < ActiveRecord::Base
  include NestedRecord::Macro
end

class User < ApplicationRecord
  has_one_nested :profile
end
```

Define nested record attributes using `ActiveModel::Attributes` API (since Rails 5.2):

```ruby
class Profile < NestedRecord::Base
  attribute :age,    :integer
  attribute :active, :boolean
  has_one_nested :contacts
end
```

You can go deeper and define models on the next nesting level:

```ruby
class Profile::Contacts < NestedRecord::Base
  attribute :email, :string
  attribute :phone, :string
end
```

You can store **a collection** of objects with `has_many_nested`:

```ruby
class Profile::Contacts < NestedRecord::Base
  attribute :email, :string
  attribute :phone, :string
  has_many_nested :socials
end

class Profile::Social < NestedRecord::Base
  attribute :name
  attribute :url
end

user.profile.age = 39
user.profile.contacts.email = 'john@doe.com'
user.profile.contacts.socials[0].name # => 'facebook'
```

You can assign attributes in the way like `accepts_nested_attributes_for` macros provides for AR models:

```ruby
user.profile_attributes = {
  age: 39,
  contacts_attributes: {
    email: 'john@doe.com',
    socials_attributes: [
      { name: 'facebook', url: 'facebook.example.com/johndoe' },
      { name: 'twitter', url: 'twitter.example.com/johndoe' }
    ]
  }
}
```

## Advanced usage

`nested_record` can do many different things for you!

### Validations

Every `NestedRecord::Base` descendant in fact is an `ActiveModel::Model` so standard validations are also supported.

```ruby
class Profile < NestedRecord::Base
  attribute :age,    :integer
  attribute :active, :boolean

  validates :age, presence: true
end
```

### Don't bother with defining record micro-classes

If you want so, you can rewrite the above example this way:

```ruby
class User < ApplicationRecord
  has_one_nested :profile do
    attribute :age, :integer
    attribute :active, :boolean
    has_one_nested :contacts do
      attribute :email, :string
      attribute :phone, :string
      has_many_nested :socials do
        attribute :name
        attribute :url
      end
    end
  end
end
```

Record classes then available under _local types_ namespace module e.g. `User::LocalTypes::Profile`.

### Concerns

Common attributes, validations and other settings can be DRY-ed to modules called _concerns_.

```ruby
module TitleAndDescription
  extend NestedRecord::Concern
  
  attribute :title
  attribute :description
  
  validates :title, presence: true
end

class Article < NestedRecord::Base
  has_one_nested :foo do
    include TitleAndDescription
  end
end
```

### `:class_name` option

By default, class name of nested record is automatically inferred from the association name but of course it's all customizable. There's a `:class_name` option for this!

Depending on what form do you use — `has_* :foo` or `has_* :foo do ... end`, the `:class_name` option means different things.

#### `:class_name` option when referring an external model

In a non-`&block` form, the `:class_name` behaves similar to the option with same name in ActiveRecord's `has_one`/`has_many` associations.

```ruby
class User < ApplicationRecord
  has_one_nested :profile, class_name: 'SomeNamespace::Profile'
end

class SomeNamespace::Profile < NestedRecord::Base
  attribute :age, :integer
  attribute :active, :boolean
end
```

#### `:class_name` option when using with an embedded _local types_

When record definition is embedded, `:class_name` option denotes the name of the class in _local types_ namespace module under which it's defined.

```ruby
class User < ApplicationRecord
  has_one_nested :profile, class_name: 'ProfileRecord' do
    attribute :age, :integer
    attribute :active, :boolean
  end
end
```

Then the profile model is available under `User::LocalTypes::ProfileRecord` name.

You can also disable the const naming at all, passing `class_name: false`. In this case, the _local type_ is anonymous so no constant in _local types_ namespace is set.

`class_name: true` (the default) means infer the class name from association name e.g. `User::LocalTypes::Profile` constant is set by default.

### `nested_accessors`

This is the `store_accessor` on steroids! Unlike `store_accessor` it's support nesting, type coercions and all other things this library can do. Think of it as a `has_one_nested` association with accessors lifted up one level.

```ruby
class User < ApplicationRecord
  nested_accessors from: :profile do
    attribute :age, :integer
    attribute :active, :integer
  end
end

user = User.new
user.age = 33
user.active = true
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marshall-lee/nested_record.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
