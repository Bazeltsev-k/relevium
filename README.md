# Relevium
![Gem](https://img.shields.io/gem/v/relevium) ![Code Climate maintainability](https://img.shields.io/codeclimate/maintainability/Bazeltsev-k/relevium) ![GitHub Workflow Status (branch)](https://img.shields.io/github/workflow/status/Bazeltsev-k/relevium/Ruby/master)

#### Simple ruby gem for rails projects with some useful patterns that would help you build more scalable apps

## Table of contents <a name='table-of-contents'></a>
1. [Service object](#service-object)
   1. [Listeners](#listeners)
2. [Background service](#background-service)
3. [Form object](#form)
    1. [Serialization with forms](#form)


## Service object <a name='service-object'></a>
[To the start](#table-of-contents)

Interface for running services - a place to move your business logic.

Example:
```ruby
class TestService < Relevium::Service
  attr_reader :user_id
  
  def initialize(user_id)
    @user_id = user_id
  end

  def call
    return broadcast(:fail) unless user_valid?

    do_some_stuff
    book = user.books.last
    user.delete
    broadcast(:ok, book)
  end

  private

  def user_valid?
    user.name == 'Kyle'
  end

  def do_some_stuff
    #..more_code_here..
  end

  def user
    @user ||= User.find_by(id: user_id)
  end
end
```

Results:

```ruby
@user = User.last # Name is 'Kyle'

TestService.call(@user.id)
# Will delete user and broadcast method won't take affect

TestService.call(@user.id) do |obj|
  obj.on(:fail) { raise 'Some error' } # Listener for fail broadcast
  obj.on(:ok) { |book|  @book = book } # Listener for ok broadcast
end
# User will be deleted and @book variable will be assigned

@user.update(name: 'Stan')
TestService.call(@user.id) do |obj|
  obj.on(:fail) { raise 'Some error' }
  obj.on(:ok) { |book|  @book = book }
end
# User won't be deleted and Some error' will be raised
```

### Adding listeners <a name='listeners'></a>
[To the start](#table-of-contents)

Example:
```ruby
class TestListener < Relevium::Service
  attr_reader :email

  def initialize(email)
    @email = email
  end

  def call
    unsubscribe_from_sendgrid
  end

  private

  def unsubscribe_from_sendgrid
    # your code
  end
end
```

```ruby
class TestService < Relevium::Service
  set_listener TestListener, :ok
  attr_reader :user_id
  
  def initialize(user_id)
    @user_id = user_id
  end

  def call
    do_some_stuff
    user.delete
    user.persisted? ? broadcast(:ok, user.email) : broadcast(:fail)
  end

  private

  def do_some_stuff
    #..more_code_here..
  end

  def user
    @user ||= User.find_by(id: user_id)
  end
end
```

Results:

```ruby
@user = User.last

TestService.call(@user.id)
# Will delete user and broadcast method won't take affect.
# However listener's `call` function will be called 
# with `email` passed as the argument to initialize function.
```
---
Specify which function from listener to call:

```ruby
class TestListener < Relevium::Service
  def initialize(arg)
    @arg = arg
  end

  def on_ok
    # ok code
  end

  def on_fail
    # fail code
  end
end

set_listener TestListener, :ok, function: :on_ok
set_listener TestListener, :fail, function: :on_fail
```
---
Specify arguments that should be passed to the listener:
```ruby
class TestListener < Relevium::Service
  attr_reader :arg

  def initialize(arg)
    @arg = arg
  end

  def call
    puts arg
  end
end

class TestService < Relevium::Service
  set_listener TestListener, :ok, args: :user_id

  def initialize(user_id)
    @user_id = user_id
  end

  def call
    # some code
    broadcast(:ok, 'test')
  end
end
```

Result:
```ruby
TestService.call(1) do |service|
  service.on(:ok) { |argument| puts argument }
end

# Output:
# test
# 1
```
---
Set up condition to call listener:
```ruby
class TestService < Relevium::Service
  set_listener TestListener, :ok, if: Proc.new { |service| !service.user.persisted? }

  def initialize(user_id)
    @user = User.find(user_id)
  end

  def call
    @user.delete
    broadcast(:ok)
  end
end
```

Results:
```ruby
TestService.call(User.last.id)
# Listener would be trigger only if user was deleted.
```

## Background service <a name='background-service'></a>
[To the start](#table-of-contents)

Simple interface for running background jobs as services.
Meant to be inherited like this:
```ruby
class SidekiqService < Relevium::BackgroundService
  def initialize(options)
    super(options, ServiceObjectWorker)
  end
end
```
Needs a sidekiq worker in order to work, that should look like this:
```ruby
class ServiceObjectWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: true

  def perform(klass, *args)
    klass.constantize.call(args)
  end
end

```

Now you can create a service like this:
```ruby
class SimpleService < SidekiqService
attr_reader :foo

  def initialize(foo, options = {})
    super(options)
    @foo = foo
  end

  private

  def perform
    puts foo
  end
end

```

And invoke it like this:
```ruby
SimpleService.call('foo', background: true, perform_in: 15.minutes)
# Will set sidekiq worker to be performd in 15 minutes,
# that will print 'foo' in sidekiq console
```
Note that listeners won't work when service is being called as background job.

## Form object <a name='form'></a>
[To the start](#table-of-contents)

Form object is used to move validations from models. Usually used when similar model needs different validations on
different forms. Can be used to build attributes for model to save.

Example:
```ruby
class UserForm < Relevium::Form

  attribute :user_id, Integer
  attribute :user_name, String
  attribute :sibling_name, String, remove_from_hash: true

  include_in_hash :sibling_id

  validates :user_id, :user_name, presence: true
  validate :is_kyle

  private

  def is_kyle
    return true if user_name == 'Kyle'

    errors.add(:user_name, 'should be Kyle')
  end

  def sibling_id
    @sibling_id ||= User.find_by(name: sibling_name)
  end
end
```
Results:
```ruby
user_params = {user_id: 1, user_name: 'Kyle', sibling_name: 'John'}
form = UserForm.new(user_params)
form.valid? # true
form = UserForm.new(user_params.merge(user_name: 'Steve'))
form.valid? # false
form.errors.full_messages # ["User name should be Kyle"]
form = UserForm.new(user_params.merge(user_id: 'test'))
form.valid? # false
form.errors.full_messages # ["User can't be blank"]
form = UserForm.new(user_params.merge(user_id: '1')) # Will convert user_id into Integer
form.to_h # { user_id: 1, user_name: 'Kyle', sibling_id: 12 }

form.set(user_name, 'Stan')
form.set_attributes(user_id: 2, sibling_name: 'Ken')
form.to_h # { user_id: 2, user_name: 'Stan', sibling_name: 'Ken' }
```
---
### Serialization with forms <a name='serialization'></a>
[To the start](#table-of-contents)

```ruby
class UserForm < Relevium::Form
  attribute :available_cash, Float

  serialize_attributes :user_id, :sibling_id, :available_cash, :user_full_name

  def user_full_name
    first_name + ' ' + last_name
  end
end
```

Now you can use this form to serialize active records to hash:
```ruby
ap User
# User < ActiveRecord::Base {
#  :user_id => :integer,
#  :available_cash => :string,
#  :sibling_id => :integer,
#  :first_name => :string,
#  :last_name => :string
# }
UserForm.from_model(User.last).serialize
# Output: 
# { user_id: 1, sibling_id: 2, available_cash: 123.45, user_full_name: 'Ken Stevenson' }
```
Also you can serialize active record collection or array of active records:
```ruby
UserForm.serialize_relation(User.where(id: (1..15)))
UserForm.serialize_relation(User.last(3).to_a)
```

