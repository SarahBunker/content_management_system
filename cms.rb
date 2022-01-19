# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' # if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def render_markdown(file)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(file)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

class PasswordDigester
  def self.encrypt(password)
    BCrypt::Password.create(password)
  end
  def self.check?(password, encrypted_password)
    BCrypt::Password.new(encrypted_password) == password
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file_content(credentials_path)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def signed_in?
  valid_sign_in?(session[:username], session[:password])
end

def signed_in_admin?
  signed_in? && session[:username] == "admin"
end

def valid_sign_in?(username, password)
  credentials = YAML.load(File.read("users.yml"))
  credentials[username] && PasswordDigester.check?(password, credentials[username])
end

def require_signed_in_user
  unless signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

def require_signed_in_admin
  unless signed_in_admin?
    session[:message] = "You must be signed in as admin to do that."
    redirect "/"
  end
end

def error_for_file_path(filename)
  "#{filename}: does not exist" if File.file?(filename)
end

get '/' do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :index
end

get "/new" do
  require_signed_in_user

  erb :new
end

post "/create" do
  require_signed_in_user

  @filename = params[:filename].to_s.strip

  if @filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    @filename = "#{@filename}.txt" if File.extname(@filename) == ""
    file_path = File.join(data_path, @filename)

    File.write(file_path, "")
    session[:message] = "#{params[:filename]} has been created."

    redirect "/"
  end
end

get '/users/signin' do
  erb :signin
end

post '/users/signin' do
  @username = params[:username]
  password = params[:password]


  if valid_sign_in?(@username, password)
    session[:username] = @username
    session[:password] = password
    session[:message] = "Welcome"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

post '/users/signout' do
  session.delete(:username)
  session.delete(:password)

  session[:message] = "You have been signed out."

  redirect "/"
end

get '/users/edit' do
  require_signed_in_admin

  @users = File.read("users.yml").split("\n").map {|line| line.split(": ") }
  erb :users
end

get '/:filename' do
  file_path = File.join(data_path, params[:filename])
  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist"
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user

  @filename = params[:filename]
  file_path = File.join(data_path, @filename)
  if File.file?(file_path)
    @content = File.read(file_path)

    erb :file_edit
  else
    session[:message] = "#{params[:filename]} does not exist"
    redirect "/"
  end
end

post "/:filename/delete" do
  require_signed_in_user

  @filename = params[:filename]
  file_path = File.join(data_path, @filename)

  File.delete(file_path)

  session[:message] = "#{params[:filename]} has been deleted."

  redirect "/"
end

post "/:filename" do
  require_signed_in_user

  @filename = params[:filename]
  file_path = File.join(data_path, @filename)

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end