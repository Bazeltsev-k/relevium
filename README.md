# ApplicationUtilities 

## Service object
Interface for running services - a place to move our business logic.

Example:
```ruby
class TestService < ApplicationUtilities::Service
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
@loan = nil

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

## Background service

Simple interface for running background jobs as services.
Meant to be inherited like this:
```ruby
class SidekiqService < ApplicationUtilities::BackgroundService
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

## Form object
Form object is used to move validations from models. Usually used when similar model needs different validations on
different forms. Can be used to build attributes for model to save.

Example:
```ruby
class UserForm < ApplicationUtilities::Form

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
```