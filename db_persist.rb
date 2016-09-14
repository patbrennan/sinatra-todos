require "pg"

# DATA PERSISTENCE CLASS - TODOS DB
class DatabasePersist
  def initialize(logger)
    @db = PG.connect(dbname: "todos")
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(list_id)
    sql = "SELECT * FROM lists WHERE id = $1;"
    result = query(sql, list_id)

    tuple = result.first
    {id: tuple["id"].to_i, name: tuple["name"], todos: find_todos(tuple["id"])}
  end

  def all_lists
    sql = "SELECT * FROM lists;"
    result = query(sql)

    result.map do |tuple|
      {id: tuple["id"].to_i, name: tuple["name"], todos: find_todos(tuple["id"])}
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1);"
    query(sql, list_name)
  end

  def delete_list(list_id)
    query("DELETE FROM todos WHERE list_id = $1;", list_id)
    query("DELETE FROM lists WHERE id = $1;", list_id)
  end

  def update_list_name(id, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2;"
    query(sql, new_name, id)
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (list_id, description) VALUES ($1, $2);"
    query(sql, list_id, todo_name)
  end

  def delete_todo(list_id, todo_id)
    sql = "DELETE FROM todos WHERE list_id = $1 AND id = $2;"
    query(sql, list_id, todo_id)
  end

  def change_todo_status(list_id, todo_id, is_completed)
    sql = "UPDATE todos SET completed = $1 WHERE list_id = $2 AND id = $3;"
    query(sql, is_completed, list_id, todo_id)
  end

  def mark_all_complete(list_id)
    query("UPDATE todos SET completed = 'true' WHERE list_id = $1;", list_id)
  end
  
  private
  
  def find_todos(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1;"
    result = query(sql, list_id)
    
    result.map do |tuple|
      status = tuple["completed"]

      { id: tuple["id"].to_i,
        name: tuple["description"],
        completed: status == "t" }
    end
  end
end
