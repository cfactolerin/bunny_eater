require 'json'

RSpec.describe BunnyEater do

  let(:message) { { test: "This is a test header" } }
  let(:s3_message) { { acl: "bucket-owner-full-control",
                       body: "{\"test\":\"This is a test header\"}\n{\"test\":\"This is a test header\"}",
                       bucket: "test_bucket",
                       key: "test_key/year=2018/month=02/day=22/hour=02/messages_1519265349.txt"
  }}
  let(:opt) {
    {
      rabbitmq_host: 'localhost',
      rabbitmq_username: 'guest',
      rabbitmq_queue_name: 'test_queue',
      s3_bucket: 'test_bucket',
      s3_path: 'test_key',
      aws_region: 'us-east-1',
      max_messages_per_file: 2,
      push_message_back_to_mq_on_fail: true,
      minimum_msg_to_execute: 0
    }
  }

  let(:setup_queue) {
    conn = BunnyMock.new
    allow(BunnyEater).to receive(:create_connection) { conn }
    channel = conn.start.channel
    channel.queue 'test_queue'
  }

  before(:each) do
    @queue = setup_queue
    @s3_client = double("s3_client")
    allow_any_instance_of(BunnyEater).to receive(:s3_client) { @s3_client }
  end

  context 'normal case' do

    it 'should be able to retrieve data from rabbit mq and push to s3' do
      send_message(2)
      expect_s3_to_receive(1)
      expect{ BunnyEater.consume(opt) }.not_to raise_exception
    end

  end

  context 'when config limits are hit' do
    it 'should push the data when it reached the max_messages_per_file limit' do
      send_message(7)
      expect_s3_to_receive(4)
      expect{ BunnyEater.consume(opt) }.not_to raise_exception
    end

    it 'should not push data when minimum_msg_to_execute is not enough' do
      opt[:minimum_msg_to_execute] = 5
      send_message(3)
      expect_any_instance_of(BunnyEater).to receive(:print_error_and_exit).with(any_args)
      expect{ BunnyEater.consume(opt) }.not_to raise_exception
    end
  end

  context 'when something goes wrong when writing to s3' do
    it 'push the message back to mq if push_message_back_to_mq is true' do
      send_message(10)
      allow_any_instance_of(BunnyEater).to receive(:s3_client) { Aws::S3::Client.new(access_key_id: "",
                                                                                     secret_access_key: "") }
      expect_s3_to_receive(0)
      expect_any_instance_of(BunnyEater).to receive(:push_message_back_to_mq).with(any_args)
      expect_any_instance_of(BunnyEater).to receive(:print_error_and_exit).with(any_args)
      BunnyEater.consume(opt)
    end

    it 'should do nothing if push_message_back_to_mq is false' do
      send_message(1)
      allow_any_instance_of(BunnyEater).to receive(:s3_client) { Aws::S3::Client.new(access_key_id: "",
                                                                                     secret_access_key: "") }
      expect_s3_to_receive(0)
      expect_any_instance_of(BunnyEater).not_to receive(:push_message_back_to_mq).with(any_args)
      expect_any_instance_of(BunnyEater).to receive(:print_error_and_exit).with(any_args)
      opt[:push_message_back_to_mq_on_fail] = false
      BunnyEater.consume(opt)
    end
  end

  private

  def send_message(count)
    count.times do
      @queue.publish(message.to_json.to_s)
    end
  end

  def expect_s3_to_receive(count)
    expect(@s3_client).to receive(:put_object).exactly(count).times.with(any_args)
  end



end
