require 'bundler'
Bundler.require
Dotenv.load

def ask(message)
  print "#{message} (y/n):"
  gets.strip == 'y'
end

# http://docs.aws.amazon.com/sdkforruby/api/Aws/SNS/Client.html

access_key_id = if ENV['ACCESS_KEY_ID']
                  ENV['ACCESS_KEY_ID']
                else
                  ask('AWS Access Key ID')
                end

secret_access_key = if ENV['SECRET_ACCESS_KEY']
                      ENV['SECRET_ACCESS_KEY']
                    else
                      ask('AWS Secrect Access Key')
                    end

client = Aws::SNS::Client.new(
  access_key_id: access_key_id,
  secret_access_key: secret_access_key,
  region: 'ap-northeast-1'
)

# ==============================================================================
puts '= Get first topic'
res = client.list_topics
topic_arn = if res.topics.empty?
              puts '## Create topic'
              client.create_topic(name: 'SNSTestTopic').topic_arn
            else
              res.topics.first.topic_arn
            end
puts "Topic arn: #{topic_arn}"

# ==============================================================================
puts
puts '= Target subscriptions'
targets = [
  { endpoint: 'i.yuuya@gmail.com', protocol: 'email' },
]
pp targets

# ==============================================================================
puts
puts '= Not found targets'
res = client.list_subscriptions_by_topic(topic_arn: topic_arn)
not_found_targets = targets.reject do |target|
  res.subscriptions.map(&:endpoint).include?(target[:endpoint])
end
pp not_found_targets

unless not_found_targets.empty?
  puts '== Add targets to subscriptions'

  not_found_targets.each do |target|
    puts target
    pp client.subscribe(
      topic_arn: topic_arn,
      protocol: target[:protocol],
      endpoint: target[:endpoint]
    )
  end
end

# ==============================================================================
puts
puts '= Target subscriptions'
# Since there is a possibility that it is newly added, it is re-acquired
res = client.list_subscriptions_by_topic(topic_arn: topic_arn)
subscriptions = res.subscriptions
subscriptions.each do |subscription|
  pp subscription
end

# ==============================================================================
puts
puts '= Publish topic'
if ask('Publish just now')
  data = {
    topic_arn: topic_arn,
    subject: 'test subject',
    message: 'test message'
    # message_structure: 'json',
  }
  pp data
  pp client.publish(data)
end

# ==============================================================================
puts
puts '= Unsubscribe'
if ask('Unsubscribe all')
  subscriptions.each do |subscription|
    puts "== Unsubscribe: #{subscription.endpoint}"
    if subscription.subscription_arn == 'PendingConfirmation'
      puts '=== Skip: status is pending confirmation'
    else
      res = client.unsubscribe(subscription_arn: subscription.subscription_arn)
      pp res
    end
  end
end

# ==============================================================================
puts
puts '= Delete topic'
if ask("Delete topic: [#{topic_arn}]")
  res = client.delete_topic(topic_arn: topic_arn)
  pp res
end
