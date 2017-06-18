class SiteLog; def self.create(options); end; end
def Time.zone; Time; end
class Sunspot; def self.commit_if_dirty; end; end
module Sidekiq
  module Worker
    def self.included(base)
      def base.sidekiq_options(options); end
    end
  end
end
class UserFile; def self.find; end; end
class UrlFileReader; def self.read; end; end
class ValidatesEmailFormatOf; def self.validate_email_format; end; end
class User
  def initialize(options); end
  def self.find_by_email(email); end
  def valid?; end
  def subscriptions; end
  def self.where; end
end
class AdvtCategory; def self.find_by_id; end; end
class Subscription; def self.new; end; end
class UserMailer; def self.welcome_email; end; end
