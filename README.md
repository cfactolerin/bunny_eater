# BunnyEater

This Gem will retrieve data from a RabbitMQ Server and store the messages in Amazon S3

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bunny_eater',  :git => 'git@github.com:cfactolerin/bunny_eater.git', :branch => 'master'
```

And then execute:

    $ bundle
    
Note: If we want to gem install it directly using command line, we need to host it on a private gem repo like Gem Fury
      then we can do `gem install bunny_eater -s <private repo url>`
      
Another way is to clone the repo, build the gem then install it.

## Usage

#### Using ENV Variables to configure BunnyEater or create a `.env` file

You can set the following System Environment Variables and bunny_eater will detect it during execution.

##### RabbitMq Settings
- RABBITMQ_HOST = Hostname of the RabbitMQ Server 
- RABBITMQ_USERNAME = Username that has access to the RabbitMQ Server
- RABBITMQ_PASSWORD = Password
- RABBITMQ_QUEUE_NAME = Name of the Queue where bunny_eater will pull the messages from.
- MINIMUM_MESSAGE_TO_CONSUME = The minimum messages the queue needs to have before bunny_eater will pull the data. By default it is configured to 0.
- MAX_MESSAGES_PER_FILE = Limits the amount of messages it will store per file. This also prevents from storing to many messages in memory before pushing to S3.
- PUSH_MESSAGE_BACK_TO_MQ_ON_FAIL = Set "true" to push back the messages back to the queue if something went wrong during pushing to S3.
  
##### AWS Settings
- S3_BUCKET = AWS S3 bucket where the data will be uploaded
- S3_PATH = AWS S3 Path where the data will be uploaded. Eg bi-data-pipeline/development
- AWS_REGION = AWS Region where the configured S3 Bucket is found. Eg us-east-1 or ap-southeast-1
- AWS_ACCESS_KEY_ID = AWS Access Key
- AWS_SECRET_ACCESS_KEY = AWS Secret Access Key

Important Note: Please make sure you have access to AWS S3.
https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html

##### Logger Settings
- logger (Can only be done by passing it as options) `opt[:logger] = Logger.new # Can also be your Rails Logger` 

Note: By default, all logs are directed to STDOUT with LOG_LEVEL `Logger::INFO`
      Pass a new logger if you want to set the log level

You can then call `BunnyEater.consume`


#### OR you can pass the configuration during execution
 
```
opt[:rabbitmq_host]                     = 'localhost
opt[:rabbitmq_username]                 = 'guest'
opt[:rabbitmq_password]                 = 'guest'
opt[:rabbitmq_queue_name]               = 'my_queue'
opt[:s3_bucket]                         = 'my_s3_bucket'
opt[:s3_path]                           = 'my_s3_path'
opt[:minimum_msg_to_execute]            = 0
opt[:max_messages_per_file]             = 100000
opt[:push_message_back_to_mq_on_fail]   = true
opt[:access_key_id]                     = xxxxxxxxxxxxxxx
opt[:secret_access_key]                 = xxxxxxxxxxxxxxx
opt[:logger]                            = Logger.new (can also use your Rails Logger)

# Pass opt when calling consume
BunnyEater.consume(opt)
```

## Development

1. Install bundler via `gem install bundler`
2. Install dependencies by running `bundle install`
3. Copy the .env_sample and rename it to .env
4. Configure the .env file correctly by supplying the configuration


##### To Build:
1. Run `rake build`. This should build the gem and store it under `pkg` folder.
2. Test install by running `gem install pkg/bunny_eater-<version>.gem`
   
   Example: `gem install pkg/bunny_eater-0.1.0.gem`
   
##### To Run:
1. bunny_eater gem will install an executable called `bunny_eater` during gem installation.
   
   Run by executing `bunny_eater`
   
##### To Uninstall:
1. Run `gem uninstall bunny_eater`

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the BunnyEater project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/bunny_eater/blob/master/CODE_OF_CONDUCT.md).
