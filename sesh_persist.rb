# DATA PERSISTANCE CLASS - SESSION
class SessionPersist
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(list_id)
    @session[:lists].find { |hash| hash[:id] == list_id }
  end

  def all_lists
    @session[:lists]
  end

  def create_new_list(list_name)
    id = next_element_id(@session[:lists])
    @session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def delete_list(list_id)
    @session[:lists].delete_if { |list| list[:id] == list_id }
  end

  def error_message=(message)
    @session[:error] = message
  end

  def success_message=(message)
    @session[:success] = message
  end

  def update_list_name(id, new_name)
    list = find_list(id)
    list[:name] = new_name
  end

  def create_new_todo(list_id, todo_name)
    list = find_list(list_id)
    id = next_element_id(list[:todos])
    list[:todos] << { id: id, name: todo_name, completed: false}
  end

  def delete_todo(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].delete_if { |todo| todo[:id] == todo_id }
  end

  def change_todo_status(list_id, todo_id, is_completed)
    list = find_list(list_id)
    todo = list[:todos].find { |hash| hash[:id] == todo_id }
    todo[:completed] = is_completed
  end

  def mark_all_complete(list_id)
    list = find_list(list_id)
    list[:todos].each { |todo| todo[:completed] = true }
  end

  private

  def next_element_id(element_array)
    max = element_array.map { |hash| hash[:id] }.max || 0
    max + 1
  end
end
