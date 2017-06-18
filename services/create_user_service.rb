class CreateUserService

  def from_email(email, registrate = false)
    user = User.find_by_email(email)
    unless user.present?
      password = generate_password
      user = User.new(login: email, password: password, email: email, is_imported: true)
      if user.valid?
        user.skip_confirmation!
        user.save
        user.confirm!
        begin
          UserMailer.welcome_email(user, password).deliver if registrate
        rescue Exception => e
          Airbrake.notify(e)
        end
      end
    end
    user
  end

  protected

  def generate_password
    Array.new(6) { (rand(122-97) + 97).chr }.join
  end

end
