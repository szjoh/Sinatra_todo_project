require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
    enable :sessions
    set :session_secret, 'secret'
end

helpers do
    def list_complete?(list)
        todos_count(list) > 0 && todos_remaining_count(list) == 0
    end
    
    def list_class(list)
        "complete" if list_complete?(list)
    end
    
    def todos_count(list)
        list[:todos].size
    end
    
    def todos_remaining_count(list)
        list[:todos].count {|todo| !todo[:completed] }
    end
    
    def reorder_list(list)
        if list_complete?(list)
            session[:lists] << session[:lists].delete(list)
        end
    end
    
    def sort_lists(lists, &block)
        complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }
        
        incomplete_lists.each { |list| yield list, lists.index(list) }
        complete_lists.each { |list| yield list, lists.index(list) }
    end
    
    def sort_items(items, &block)
        complete_item, incomplete_item = items.partition { |todo| todo[:completed] }
        
        incomplete_item.each { |todo| yield todo, items.index(todo)}
        complete_item.each { |todo| yield todo, items.index(todo)}    
    end
end

before do 
    session[:lists] ||= []
end

get "/" do
   redirect "/lists" 
end

#View all the lists. 
get "/lists" do
    @lists = session[:lists]
  erb :lists, layout: :layout
end

# Reders the new list form
get "/lists/new" do
    erb :new_list, layout: :layout
end

def error_check(name)
    if !(1..100).cover? name.size
        "List name must be between 1 and 100 characters"
    elsif session[:lists].any? { |list| list[:name] == name }
        "List name must be unique."
    end
end

# Create a new list
post '/lists' do
    
    list_name = params[:list_name].strip
    
    error = error_check(list_name)
    if error
        session[:error] = error_check(list_name)
        erb :new_list, layout: :layout
    else
        session[:lists] << {name: list_name, todos: []}
        session[:success] = "The list has been created."
        session[:number] = session[:lists].size - 1
        redirect "/lists"
    end
    
end

get '/lists/:id' do
    @list_id = params[:id].to_i
    @list = session[:lists][@list_id]
    
    erb :list, layout: :layout
end

get '/lists/:id/edit' do
    id = params[:id].to_i
    @list = session[:lists][id]
    
    erb :edit_list, layout: :layout
end

#update an existing To do list
post '/lists/:id' do    
    id = params[:id].to_i
    @list = session[:lists][id]
    list_name = params[:list_name].strip
    
    error = error_check(list_name)
    if error
        session[:error] = error_check(list_name)
        erb :edit_list, layout: :layout
    else
        @list[:name] = list_name
        session[:success] = "The list has been edited successfully."
        session[:number] = session[:lists].size - 1
        redirect "/lists/#{id}"
    end
     
end

get '/lists/:id/destroy' do
    id = params[:id].to_i
    @list = session[:lists][id]
    erb :destroy_list, layout: :layout
end

get '/lists/:id/confirm_destroy' do
    id = params[:id].to_i
    @list = session[:lists][id]
    redirect "/lists/#{id}/destroy" if session[:lists].include?(@list)
end

post '/lists/:id/destroy' do
    id = params[:id].to_i
    session[:lists].delete_at(id)
    session[:success] = "The list has been deleted successfully."
    
    redirect "/lists"
end

def error_check_for_todo(name)
    if !(1..100).cover? name.size
        "To-do must be between 1 and 100 characters"
    end
end

# Add a new todo to a list.
post '/lists/:list_id/todos' do
    @list_id = params[:list_id].to_i
    @list = session[:lists][@list_id]
    
    text = params[:todo].strip
    
    error = error_check_for_todo(text)
    if error
        session[:error] = error
        erb :list, layout: :layout
    else
        @list[:todos] << {name: text, completed: false}
        session[:success] = "The to-do item has been added successfully."
        redirect "/lists/#{@list_id}"
    end
end

post '/lists/:list_id/todos/:index/destroy' do
    @index = params[:index].to_i
    @list_id = params[:list_id].to_i
    @list = session[:lists][@list_id]
    
    session[:success] = "The to-do item has been deleted successfully."
    @list[:todos].delete_at(@index)
    redirect "/lists/#{@list_id}"
    
end

# Update Todo status
post '/lists/:list_id/todos/:index' do
    @list_id = params[:list_id].to_i
    @list = session[:lists][@list_id]
    
    @index = params[:index].to_i
    is_completed = (params[:completed] == "true")
    @list[:todos][@index][:completed] = is_completed

    session[:success] = "The to-do task, #{@list[:todos][@index][:name]}, has been updated!" unless list_complete?(@list)
    
    if list_complete?(@list)
        session[:success] = "All the tasks are completed!" 
    end

    redirect "/lists/#{@list_id}"    
end

#mark all completed
post '/lists/:list_id/complete_all' do 
    @list_id = params[:list_id].to_i
    @list = session[:lists][@list_id]
    
    @list[:todos].each { |todo| todo[:completed] = true}
    session[:success] = "All the items on the list has been completed"
    
    #sort_lists(@list)

    redirect "/lists/#{@list_id}"
end



set :session_secret, SecureRandom.hex(32)