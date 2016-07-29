require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, :escape_html => true
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
  list = session[:lists].find { |hash| hash[:id] == list_id }
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
  halt
end

def next_element_id(element_array)
  max = element_array.map { |hash| hash[:id] }.max || 0
  max + 1
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View all lists of lists
get "/lists" do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

# Return an error message if name is invalid, or nil if it's valid.
def error_for_name(name)
  if !(1..100).cover? name.size
    "Input text must be between 1 & 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "Input name must be unique."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_element_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
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
  todo = params[:todo_name].strip
  @todo_list = @list[:todos]

  error = error_for_name(todo)
  if error
    session[:error] = error
    erb :one_list, layout: :layout
  else
    id = next_element_id(@todo_list)
    @todo_list << { id: id, name: todo, completed: false}

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
    @list[:name] = new_name
    session[:success] = "List name has been changed."
    redirect "/lists/#{id}"
  end
end

# Delete entire todo list
post "/delete/:list_id" do
  id = params[:list_id].to_i
  @lists = load_list(id)
  list_name = @lists[:name]

  session[:lists].delete_if { |list| list[:id] == id }

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

  @todo_list.delete_if { |todo| todo[:id] == todo_id }
  
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "Todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update status of one todo
post "/lists/:list_id/complete/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"

  todo = @list[:todos].find { |hash| hash[:id] == todo_id }
  todo[:completed] = is_completed
  session[:success] = "Todo updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete
post "/lists/:list_id/complete-all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos marked completed."
  redirect "/lists/#{@list_id}"
end
