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

get '/' do
  @files = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end

  erb :index
end

def error_for_file_path(filename)
  "#{filename}: does not exist" if File.file?(filename)
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
    render_markdown(content)
  end
end

get '/:filename' do
  file_path = root + "/data/" + params[:filename]
  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist"
    redirect "/"
  end
end

get "/:filename/edit" do
  @filename = params[:filename]
  file_path = root + "/data/" + @filename
  if File.file?(file_path)
    @content = File.read(file_path)

    erb :file_edit
  else
    session[:message] = "#{params[:filename]} does not exist"
    redirect "/"
  end
end

post "/:filename" do
  @filename = params[:filename]
  file_path = root + "/data/" + @filename

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end
