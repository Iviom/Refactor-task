require 'minitest/autorun'
require 'minitest/stub_any_instance'
include Minitest

require_relative 'mocked_objects'
require_relative '../user_file_import_process'

class TestUserFileImportProcess < Minitest::Test
  TEST_FILE_URL = __dir__ + '/files/test_file.txt'
  TEST_EMAIL = 'user1@test.com'
  TEST_PASSWORD = 'bthpyf'
  PASSWORD_SEED = 8787

  def setup
    @ufip = UserFileImportProcess.new
  end

  def test_perform
    file_mock = Mock.new
    def file_mock.id; 87; end
    def file_mock.registrate?; true; end
    file_mock.expect :file, file_mock
    file_mock.expect :url, nil

    advt_category_mock = Mock.new
    def advt_category_mock.id; 87; end
    advt_category_mock.expect :call, advt_category_mock, ["87\n"]

    validates_email_mock = Mock.new
    validates_email_mock.expect :call, nil, [TEST_EMAIL]

    user_mock = Mock.new
    user_mock.expect :call, user_mock, [TEST_EMAIL]
    user_mock.expect :id, 78
    user_mock.expect :subscriptions, user_mock
    user_mock.expect :where, [], [{category_id: 87}]
    user_mock.expect :call, user_mock,
       [{login: TEST_EMAIL, password: TEST_PASSWORD, email: TEST_EMAIL, is_imported: true}]
    user_mock.expect :valid?, true
    user_mock.expect :present?, false
    user_mock.expect :skip_confirmation!, nil
    user_mock.expect :save, nil
    user_mock.expect :confirm!, nil
    user_mock.expect :update_attribute, nil, [:subscribed_to_sevastopol_news, true]

    subscriptions_mock = Mock.new
    subscriptions_mock.expect :call, subscriptions_mock, [user_id: 78, category_id: 87]
    subscriptions_mock.expect :save, nil

    user_mailer_mock = Mock.new
    user_mailer_mock.expect :call, user_mailer_mock, [user_mock, TEST_PASSWORD]
    user_mailer_mock.expect :deliver, nil

    UserFile.stub :find, file_mock do
      UserFileImportProcess.stub_any_instance :before_perform, nil do
        UserFileImportProcess.stub_any_instance :after_perform, nil do
          UrlFileReader.stub :read, TEST_FILE_URL do
            ValidatesEmailFormatOf.stub :validate_email_format, validates_email_mock do
              User.stub :find_by_email, user_mock do
                User.stub :new, user_mock do
                  AdvtCategory.stub :find_by_id, advt_category_mock do
                    Subscription.stub :new, subscriptions_mock do
                      UserMailer.stub :welcome_email, user_mailer_mock do
                        srand(PASSWORD_SEED)
                        @ufip.perform(1)
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    assert_mock file_mock
    assert_mock validates_email_mock
    assert_mock advt_category_mock
    assert_mock user_mock
    assert_mock subscriptions_mock
    assert_mock user_mailer_mock
  end

  def test_before_perform
    time = Time.now.to_s

    site_log_mock = Mock.new
    site_log_mock.expect :call, nil, [{message: "Импорт пользователей №#{87} начат", created_at: time}]
    file_mock = Mock.new
    def file_mock.id; 87; end
    file_mock.expect :update_attributes, nil, [{parsing_status: 'parsing', started_at: time}]
    Time.stub :now, time do
      SiteLog.stub :create, site_log_mock do
        @ufip.instance_variable_set("@file", file_mock)
        @ufip.before_perform
      end
    end
    assert_mock site_log_mock
    assert_mock file_mock
  end

  def test_after_perform
    time = Time.now.to_s

    sunspot_mock = Mock.new
    sunspot_mock.expect :call, nil
    site_log_mock = Mock.new
    site_log_mock.expect :call, nil,
      [{message: "Импорт пользователей №87 окончен, обработано 10 записей", created_at: time}]
    file_mock = Mock.new
    def file_mock.id; 87; end
    file_mock.expect :update_attributes, nil, [{parsing_status: 'finished', finished_at: time}]
    Sunspot.stub :commit_if_dirty, sunspot_mock  do
      Time.stub :now, time do
        SiteLog.stub :create, site_log_mock do
          @ufip.instance_variable_set("@file", file_mock)
          @ufip.instance_variable_set("@count", 10)
          @ufip.after_perform
        end
      end
    end
    assert_mock sunspot_mock
    assert_mock site_log_mock
    assert_mock file_mock
  end

  def test_perform_error
    time = Time.now.to_s

    site_log_mock = Mock.new
    site_log_mock.expect :call, nil,
      [{message: "Ошибка при импорте пользователей №87, Perform exception", created_at: time}]
    file_mock = Mock.new
    def file_mock.id; 87; end
    file_mock.expect :update_attribute, nil, [:parsing_status, 'error']
    Time.stub :now, time do
      SiteLog.stub :create, site_log_mock do
        @ufip.instance_variable_set("@file", file_mock)
        @ufip.perform_error("Perform exception")
      end
    end
    assert_mock site_log_mock
    assert_mock file_mock
  end

end
