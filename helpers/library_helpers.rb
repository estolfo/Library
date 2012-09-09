helpers do
  def logged_in?
    return true if @user
    nil
  end

  def flash(msg)
    session[:flash] = msg
  end

  def show_flash
    if session[:flash]
      tmp = session[:flash]
      session[:flash] = false
      "<div id=\"flash-notice\">#{tmp}</div>"
    end
  end
  
  def books
    @books = BOOKS.find().sort([:title, :ascending]).to_a
    @books.map! do |book|
      author = AUTHORS.find_one(book["author"])
      book["author"] = {"_id" => author["_id"], "name" => "#{author["first_name"]} #{author["last_name"]}" }
      book
    end

    haml :books_index
  end
  
end
