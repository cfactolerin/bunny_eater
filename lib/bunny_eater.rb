require "bunny_eater/version"
require 'logger'
require 'bunny'
require 'aws-sdk-s3'

module BunnyEater
  extend self

  DEFAULT_MAX_MESSAGES_PER_FILE = 100_000.freeze
  DEFAULT_MIN_MSG_TO_EXECUTE    = 0.freeze
  DEFAULT_LOG_LEVEL             = Logger::INFO

  attr_accessor :logger, :queue, :config, :s3

  def consume(opt = {})
    setup_config(opt)

    conn = create_connection
    begin
      logger.info "Connecting to RabbitMQ: #{config[:rabbitmq_host]} :: Queue Name #{config[:rabbitmq_queue_name]}"

      conn.start
      channel = conn.create_channel
      @queue = channel.queue(config[:rabbitmq_queue_name])

      process_messages
    rescue Exception => bunny_exception
      print_error_and_exit(bunny_exception)
    ensure
      conn.close
      logger.info "RabbitMQ Connection closed"
    end
  end

  private

  def setup_config(opt)
    required_config = [:rabbitmq_host,
                       :rabbitmq_username,
                       :rabbitmq_queue_name,
                       :s3_bucket,
                       :s3_path,
                       :aws_region]

    @config = {}
    @config[:rabbitmq_host]           = opt[:rabbitmq_host]                     || ENV['RABBITMQ_HOST']
    @config[:rabbitmq_username]       = opt[:rabbitmq_username]                 || ENV['RABBITMQ_USERNAME']
    @config[:rabbitmq_password]       = opt[:rabbitmq_password]                 || ENV['RABBITMQ_PASSWORD']
    @config[:rabbitmq_queue_name]     = opt[:rabbitmq_queue_name]               || ENV['RABBITMQ_QUEUE_NAME']
    @config[:s3_bucket]               = opt[:s3_bucket]                         || ENV['S3_BUCKET']
    @config[:s3_path]                 = opt[:s3_path]                           || ENV['S3_PATH']
    @config[:minimum_msg_to_execute]  = opt[:minimum_msg_to_execute]            || ENV['MINIMUM_MESSAGE_TO_EXECUTE']
    @config[:max_messages_per_file]   = opt[:max_messages_per_file]             || ENV['MAX_MESSAGES_PER_FILE']
    @config[:access_key_id]           = opt[:access_key_id]                     || ENV['AWS_ACCESS_KEY_ID']
    @config[:secret_access_key]       = opt[:secret_access_key]                 || ENV['AWS_SECRET_ACCESS_KEY']
    @config[:push_message_back_to_mq] = opt[:push_message_back_to_mq_on_fail]   || ENV['PUSH_MESSAGE_BACK_TO_MQ_ON_FAIL'] == 'true'
    @config[:aws_region]              = opt[:aws_region]                        || ENV['AWS_REGION']

    if opt[:logger]
      @logger = opt[:logger]
    else
      @logger = Logger.new(STDOUT)
      @logger.level = DEFAULT_LOG_LEVEL
    end

    logger.debug "Current Config"
    logger.debug config

    missing_config = []
    required_config.each do |conf|
      missing_config << conf if config[conf].nil?
    end

    print_error_and_exit("Missing config: [#{missing_config.join(", ")}]") if missing_config.any?
  end

  def create_connection
    Bunny.new(host: config[:rabbitmq_host],
              user: config[:rabbitmq_username],
              pass: config[:rabbitmq_password])
  end

  def print_error_and_exit(err_message)
    logger.error err_message
    logger.error "Exiting with Status 1"
    exit!(1)
  end

  def process_messages
    print_error_and_exit("Not enough messages in the queue.") unless has_enough_messages?
    messages_to_pop = queue.message_count
    max_messages = config[:max_messages_per_file] || DEFAULT_MAX_MESSAGES_PER_FILE

    total_msg_counter = 0
    total_files_uploaded = 0
    counter = 0
    messages = []

    messages_to_pop.times do

      delivery_info, properties, payload = queue.pop
      break if payload.nil?
      messages << payload.strip
      counter += 1

      if counter == max_messages
        send_to_s3(messages)
        total_files_uploaded += 1

        # Reset the counter and clear the memory
        messages = []
        total_msg_counter += counter
        counter = 0

        # Force freeing memory just in case max_messages_per_file is too high
        GC.start(immediate_sweep: true)
      end

    end

    if messages.any?
      send_to_s3(messages)  # Send the remaining messages if less than the max_messages_per_file
      total_files_uploaded += 1
      total_msg_counter += messages.size
    end

    if total_files_uploaded > 0
      logger.info("Uploaded #{total_files_uploaded} files containing #{total_msg_counter} messages to #{partition_by_datetime(Time.now.utc)}")
    end

  end

  def print_messages(messages)
    logger.info "Current Messages: #{messages.size}"
    logger.info "---------------------------"
    messages.each do |msg|
      logger.info msg
    end
    logger.info "---------------------------"
  end

  def push_message_back_to_mq(messages)
    messages.each do |msg|
      queue.publish(msg)
    end
  end

  def has_enough_messages?
    available_msgs = queue.message_count
    logger.info("Available Queue Message: #{available_msgs}")
    minimum = config[:minimum_msg_to_execute].nil? ? DEFAULT_MIN_MSG_TO_EXECUTE : config[:minimum_msg_to_execute]
    logger.debug("Minimum Msg to Execute: #{minimum}")
    available_msgs >= minimum
  end

  def send_to_s3(messages)
    if messages.any?
      current_datetime = Time.now.utc
      key = "#{config[:s3_path]}/#{partition_by_datetime(current_datetime)}/#{file_name(current_datetime)}"

      logger.debug "Uploading #{messages.size} messages to S3: s3://#{config[:s3_bucket]}/#{key}"

      begin
        s3_client.put_object({ acl: "bucket-owner-full-control",
                        body: messages.join("\n"),
                        bucket: config[:s3_bucket],
                        key: key
                      })

      rescue Exception => aws_error
        logger.error("Failed to write to S3!")

        if config[:push_message_back_to_mq]
          logger.info "Pushing #{messages.size} messages back to rabbit mq"
          push_message_back_to_mq(messages)
        else
          logger.info "config[:push_message_back_to_mq] is currently off. The following messages will be lost"
          print_messages(messages)
        end

        # Raise the exception so that the RabbitMQ Connection can be closed
        # and gem will exit with status 1 (Important so that it can be caught by Linux)
        raise
      end

      logger.debug "Done uploading to S3\n"
    else
      logger.info "Queue was empty as of #{Time.now.utc}"
    end
  end

  def s3_client
    @s3 ||= Aws::S3::Client.new(access_key_id: config[:access_key_id],
                                secret_access_key: config[:secret_access_key],
                                region: config[:aws_region])
  end

  def partition_by_datetime(current_datetime)
    current_datetime.strftime("year=%Y/month=%m/day=%d/hour=%H")
  end

  def file_name(current_datetime)
    "messages_#{current_datetime.to_f.to_s.gsub(".","-")}.txt"
  end
end
