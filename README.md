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
  has_many_nested :socials
end
```

`has_many_nested` is also available (note that class namespace for association can be the same level).


```ruby
class Profile::Socials < NestedRecord::Base
  attribute :name
  attribute :url
end
```

Then accessors are enabled!

```ruby
user.profile.age = 39
user.profile.contacts.email = 'john@doe.com'
user.profile.contacts.socials[0].name # => 'facebook'
```

Also you can assign attributes in the way like `accepts_nested_attributes_for` macros provides for AR models:

```ruby
user.profile_attributes = {
  age: 39,
  contacts_attributes: {
    email: 'john@doe.com'
  }
}

```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marshall-lee/nested_record.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
