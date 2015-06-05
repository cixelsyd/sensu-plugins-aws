#! /usr/bin/env ruby
#
# aws_billing_metrics
#
# DESCRIPTION:
#   This plugin retrives AWS estimated billing metrics
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk-v1
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2015, Steve Craig, chef@innovasolutions-usa.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'aws-sdk-v1'

class EC2Metrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric (defaults to aws.cost_estimate)',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'aws.cost_estimate'

 option :fetch_age,
        description: 'How long ago to fetch metrics for (4hrs / 14400 seconds default)',
        short: '-f AGE',
        long: '--fetch_age',
        default: 14400,
        proc: proc(&:to_i)

  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option"

  option :aws_secret_access_key,
         short: '-k AWS_SECRET_ACCESS_KEY',
         long: '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option"

  option :aws_region,
         short: '-r AWS_REGION',
         long: '--aws-region REGION',
         description: 'AWS Region (defaults to us-east-1 for billing information)',
         default: 'us-east-1'

  def aws_config
    hash = {}
    hash.update access_key_id: config[:aws_access_key], secret_access_key: config[:aws_secret_access_key] if config[:aws_access_key] && config[:aws_secret_access_key]
    hash.update region: config[:aws_region]
    hash
  end

  def run
    begin

      client = AWS::CloudWatch::Client.new aws_config

      def metrics_by_service_name(client)
        begin

          et = Time.now - 60
          st = et - config[:fetch_age]

          servicename = %w(AWSSupportDeveloper AmazonGlacier AmazonCloudFront AmazonSimpleDB AmazonSNS AmazonSES AmazonS3 ElasticMapReduce AmazonRDS AmazonDynamoDB AWSDataTransfer AmazonEC2 AWSQueueService)

          data = {}
          servicename.each do |sn|
            result = client.get_metric_statistics({namespace: 'AWS/Billing', metric_name: 'EstimatedCharges', start_time: st.iso8601, end_time: et.iso8601, period: 60, statistics: ['Maximum'], dimensions: [{name: 'Currency', value: 'USD'}, {name: 'ServiceName', value: "#{sn}"}]})
            data = result[:datapoints][0]
            unless data.nil?
              # We only return data when we have some to return
              graphitepath = config[:scheme] + ".#{sn}"
              output graphitepath, data['Maximum'.downcase.to_sym], data[:timestamp].to_i
            end
          end
        rescue => e
          critical "Error: exception: #{e}"
        end
        ok
      end
      
      metrics_by_service_name(client)
    end
  end

end
