require_relative 'services/create_user_service'
require_relative 'services/subscription_service'

class UserFileImportProcess

  include Sidekiq::Worker
  sidekiq_options :queue => :critical, :retry => false

  def perform(file_id)
    @file = UserFile.find(file_id)
    before_perform
    begin
      @count = 0
      parse_user_file(@file.file.url) do |email, category_id|
        if ValidatesEmailFormatOf::validate_email_format(email).nil?
          user = CreateUserService.new.from_email(email, @file.registrate?)
          SubscriptionService.new(user).subscribe(category_id) if @file.registrate?
          @count += 1
        end
      end
      after_perform
    rescue => exception
      perform_error(exception)
    end
  end

  def before_perform
    SiteLog.create(message: "Импорт пользователей №#{@file.id} начат", created_at: Time.now)
    @file.update_attributes({parsing_status: 'parsing', started_at: Time.zone.now})
  end

  def after_perform
    Sunspot.commit_if_dirty
    @file.update_attributes({parsing_status: 'finished', finished_at: Time.zone.now})
    SiteLog.create(message: "Импорт пользователей №#{@file.id} окончен, обработано #{@count} записей", created_at: Time.now)
  end

  def perform_error(exception)
    SiteLog.create(message: "Ошибка при импорте пользователей №#{@file.id}, #{exception}", created_at: Time.now)
    @file.update_attribute(:parsing_status, 'error')
  end

  protected

  def parse_user_file(file_url)
    file = File.open(UrlFileReader.read(file_url), 'r:windows-1251')
    file.each_line do |line|
      data = line.split(';')
      email = data[0].strip.downcase
      category_id = data[1]
      yield(email, category_id)
    end
  end

end
