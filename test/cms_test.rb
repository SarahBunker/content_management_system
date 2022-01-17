ENV["RACK_ENV"] = "test" #code being tested, don't start server

require "minitest/autorun" # load minitest, configured to automatically run and defined tests
require "rack/test" # load helper methods, must add to gem list
require "minitest/reporters"
Minitest::Reporters.use!

require_relative "../cms" # loading the sinatra application

class CmsTest < Minitest::Test # tests defined in a class that inherits from minitest
  include Rack::Test::Methods # including helper methods in class

  def app # rack helper methods expecte a method #app that returns an instance of a rack application
    Sinatra::Application
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status # response to request availbe using #last_response, returns an instance with methods #status, body and [] (for accessing headers)
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    body = last_response.body
    assert_includes body, "history.txt"
    assert_includes body, "changes.txt"
    assert_includes body, "about.md"
  end

  def test_file_about
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    body = last_response.body
    assert_includes body, "Bruno, no, no, no"
  end

  def test_file_changes
    post "/changes.txt", content: "Macro-economic assessments of climate impacts"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    body = last_response.body
    assert_includes body, "Macro-economic assessments of climate impacts"
  end

  def test_file_history
    get "/history.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    body = last_response.body
    assert_includes body, "the two childhood friends form their own software company, Microsoft"
  end

  def test_file_nonexistent
    get "/notafile.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.txt does not exist"

    get "/"
    refute_includes last_response.body, "notafile.txt does not exist"
  end

  def test_editing_document
    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    post "/changes.txt", content: "new content"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end
end
