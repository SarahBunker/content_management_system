# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' # if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

root = File.expand_path("..", __FILE__)

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

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

get '/' do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :index
end

def error_for_file_path(filename)
  "#{filename}: does not exist" if File.file?(filename)
end

get "/new" do
  erb :new
end

post "/create" do
  @filename = params[:filename].to_s.strip

  if @filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    @filename = "#{@filename}.txt" if File.extname(@filename) == ""
    file_path = File.join(data_path, @filename)

    File.write(file_path, "")
    session[:message] = "#{params[:filename]} was created."

    redirect "/"
  end
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
  @filename = params[:filename]
  file_path = File.join(data_path, @filename)

  File.delete(file_path)

  session[:message] = "#{params[:filename]} has been deleted."

  redirect "/"
end

post "/:filename" do
  @filename = params[:filename]
  file_path = File.join(data_path, @filename)

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end