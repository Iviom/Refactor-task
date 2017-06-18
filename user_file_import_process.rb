class UserFileImportProcess

  include Sidekiq::Worker
  sidekiq_options :queue => :critical, :retry => false

  def perform(file_id)
    @file = UserFile.find(file_id)
    before_perform
    begin
      file_url = @file.file.url
      file = File.open(UrlFileReader.read(file_url), 'r:windows-1251')
      @count = 0
      file.each_line do |line|
        data = line.split(';')
        email = data[0].strip.downcase
        if ValidatesEmailFormatOf::validate_email_format(email).nil?
          category = AdvtCategory.find_by_id(data[1])
          user = User.find_by_email(email)
          unless user.present?
            password = Array.new(6) { (rand(122-97) + 97).chr }.join
            user = User.new(login: email, password: password, email: email, is_imported: true)
            if user.valid?
              user.skip_confirmation!
              user.save
              user.confirm!
              begin
                UserMailer.welcome_email(user, password).deliver if @file.registrate?
              rescue Exception => e
                Airbrake.notify(e)
              end
            end
          end
          if @file.registrate? && category && user.subscriptions.where(category_id: category.id).empty?
              subscription = Subscription.new(user_id: user.id, category_id: category.id)
              subscription.save
          end
          user.update_attribute(:subscribed_to_sevastopol_news, true) if @file.registrate?
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

end

