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

  def session
    last_request.env["rack.session"]
  end

  def test_initial_page
    get "/"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Sign In"
  end

  def test_sign_form
    get "/users/signin"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Username"
    assert_includes last_response.body, "Password"
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_sign_in
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_sign_in_bad_credentials
    post "/users/signin", username: "admin", password: "secret1"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid credentials"
    assert_includes last_response.body, "admin"
    assert_nil session[:username]
  end

  def test_sign_out
    get "/", {}, {"rack.session" => {username: "admin", password: "secret" } }
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal "You have been signed out.", session[:message]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"
    create_document "history.txt"

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
    create_document "history.txt", "the two childhood friends"

    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "the two childhood friends"
  end

  def test_file_nonexistent
    get "/notafile.txt"
    assert_equal 302, last_response.status
    assert_equal "notafile.txt does not exist", session[:message]

    get last_response["Location"]
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
    post "/changes.txt", content: "new content"

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_deleting_document
    create_document("test.txt")

    post"/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_create_new_document
    post "/create", filename: "test.txt"
    assert_equal 302, last_response.status
    assert_equal "test.txt has been created.", session[:message]

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_without_filename
    post "/create", filename: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end
end
