ENV["RACK_ENV"] = "test" #code being tested, don't start server

require "minitest/autorun" # load minitest, configured to automatically run and defined tests
require "rack/test" # load helper methods, must add to gem list
require "minitest/reporters"
require "fileutils"
Minitest::Reporters.use!

require_relative "../cms" # loading the sinatra application

class CmsTest < Minitest::Test # tests defined in a class that inherits from minitest
  include Rack::Test::Methods # including helper methods in class

  def app # rack helper methods expecte a method #app that returns an instance of a rack application
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_sign_in
    get "/"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Sign In"

    get "/users/signin"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Username"
    assert_includes last_response.body, "Password"

    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Welcome"
  end

  def test_sign_in_bad_credentials
    post "/users/signin", username: "admin", password: "secret1"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid credentials"
    assert_includes last_response.body, "admin"
  end

  def test_sign_out
    post "/users/signin", username: "admin", password: "secret"
    get last_response["Location"]
    post "/users/signout"
    get last_response["Location"]
    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "Sign In"
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"
    create_document "history.txt"

    post "/users/signin", username: "admin", password: "secret"
    get "/"
    assert_equal 200, last_response.status # response to request availbe using #last_response, returns an instance with methods #status, body and [] (for accessing headers)
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    body = last_response.body
    assert_includes body, "history.txt"
    assert_includes body, "changes.txt"
    assert_includes body, "about.md"
  end

  def test_viewing_markdown_file
    create_document "about.md", "#About Bruno /n/n 'I couldn’t figure out why he was so definitive,' Bush said, 'until two days later when we heard, 'Bruno, no, no, no.''"

    post "/users/signin", username: "admin", password: "secret"
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    body = last_response.body
    assert_includes body, "Bruno, no, no, no"
  end


  def test_viewing_text_file
    create_document "history.txt", "the two childhood friends form their own software company, Microsoft"

    post "/users/signin", username: "admin", password: "secret"
    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    body = last_response.body
    assert_includes body, "the two childhood friends form their own software company, Microsoft"
  end

  def test_file_nonexistent
    post "/users/signin", username: "admin", password: "secret"
    get "/notafile.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.txt does not exist"

    get "/"
    refute_includes last_response.body, "notafile.txt does not exist"
  end

  def test_editing_document
    create_document "changes.txt"

    post "/users/signin", username: "admin", password: "secret"
    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    post "/users/signin", username: "admin", password: "secret"
    post "/changes.txt", content: "new content"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_deleting_document
    create_document("test.txt")

    post "/users/signin", username: "admin", password: "secret"
    post"/test.txt/delete"

    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "test.txt has been deleted"

    get "/"
    refute_includes last_response.body, "test.txt"
  end
end
