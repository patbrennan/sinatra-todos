require "sinatra"
require "tilt/erubis"
require "sinatra/content_for"

require_relative "db_persist"

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, :escape_html => true
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "db_persist.rb"
end

helpers do
  def completed_todos(list)
    todos = list[:todos]
    incomplete = todos.count { |todo| todo[:completed] == false }
    "#{incomplete} / #{todos.size}"
  end

  # Check to see if all items complete & at least 1 todo
  def list_complete?(list)
    todos = list[:todos]
    todos.size > 0 && todos.all? { |todo| todo[:completed] == true } 
  end

  # Return appropriate list class name
  def list_class(list)
    list_complete?(list) ? "complete" : "incomplete"
  end

  def sorted_lists(lists_array)
    lists_array.sort_by { |list| list_complete?(list) ? 1 : 0 }
  end

  def sorted_todos(todo_array)
    todo_array.sort_by { |todo| todo[:completed] ? 1 : 0 }
  end
end

# INTERNAL METHODS:
def load_list(list_id)
  list = @storage.find_list(list_id)
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
  halt
end

# Return an error message if name is invalid, or nil if it's valid.
def error_for_name(name)
  if !(1..100).cover? name.size
    "Input text must be between 1 & 100 characters."
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    "Input name must be unique."
  end
end

before do
  @storage = DatabasePersist.new(logger)
end

# ROUTES:
get "/" do
  redirect "/lists"
end

# View all lists of lists
get "/lists" do
  @lists = @storage.all_lists

  erb :lists, layout: :layout
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)

    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Render new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Render one individual list with todos & new todo form
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  @todo_list = @list[:todos]
  
  erb :one_list, layout: :layout
end

# Add one todo to the list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_name = params[:todo_name].strip
  @todo_list = @list[:todos]

  error = error_for_name(todo_name)
  if error
    session[:error] = error
    erb :one_list, layout: :layout
  else
    @storage.create_new_todo(@list_id, todo_name)
    session[:success] = "Todo has been added!"
    redirect "/lists/#{@list_id}"
  end
end

# Edit the name of existing list
get "/edit/:list_id" do
  id = params[:list_id].to_i
  @list = load_list(id)

  erb :edit_list, layout: :layout
end

post "/edit/:list_id" do
  id = params[:list_id].to_i
  @list = load_list(id)
  new_name = params[:new_name].strip

  error = error_for_name(new_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(id, new_name)
    session[:success] = "List name has been changed."
    redirect "/lists/#{id}"
  end
end

# Delete entire todo list
post "/delete/:list_id" do
  id = params[:list_id].to_i
  @lists = load_list(id)
  list_name = @lists[:name]

  @storage.delete_list(id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "'#{list_name}' has been deleted."
    redirect "/lists"
  end
end

# Delete an individual todo
post "/lists/:list_id/delete/:todo_id" do
  todo_id = params[:todo_id].to_i
  @list_id = params[:list_id].to_i
  @todo_list = load_list(@list_id)[:todos]

  @storage.delete_todo(@list_id, todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "Todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Change status of one todo
post "/lists/:list_id/complete/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"

  @storage.change_todo_status(@list_id, todo_id, is_completed)

  session[:success] = "Todo updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete
post "/lists/:list_id/complete-all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @storage.mark_all_complete(@list_id)
  session[:success] = "All todos marked completed."
  redirect "/lists/#{@list_id}"
end
