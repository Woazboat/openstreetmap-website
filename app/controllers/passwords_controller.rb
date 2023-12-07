class PasswordsController < ApplicationController
  include SessionMethods

  layout "site"

  before_action :authorize_web
  before_action :set_locale
  before_action :check_database_readable

  authorize_resource :class => false

  before_action :check_database_writable

  def new
    @title = t ".title"
  end

  def edit
    @title = t ".title"

    if params[:token]
      token = UserToken.find_by(:token => params[:token])

      if token
        self.current_user = token.user
      else
        flash[:error] = t ".flash token bad"
        redirect_to :action => "new"
      end
    else
      head :bad_request
    end
  end

  def create
    user = User.visible.find_by(:email => params[:email])

    if user.nil?
      users = User.visible.where("LOWER(email) = LOWER(?)", params[:email])

      user = users.first if users.count == 1
    end

    if user
      token = user.tokens.create
      UserMailer.lost_password(user, token).deliver_later
      flash[:notice] = t ".notice email on way"
      redirect_to login_path
    else
      flash.now[:error] = t ".notice email cannot find"
      render :new
    end
  end

  def update
    if params[:token]
      token = UserToken.find_by(:token => params[:token])

      if token
        self.current_user = token.user

        if params[:user]
          current_user.pass_crypt = params[:user][:pass_crypt]
          current_user.pass_crypt_confirmation = params[:user][:pass_crypt_confirmation]
          current_user.activate if current_user.may_activate?
          current_user.email_valid = true

          if current_user.save
            token.destroy
            session[:fingerprint] = current_user.fingerprint
            flash[:notice] = t ".flash changed"
            successful_login(current_user)
          else
            render :edit
          end
        end
      else
        flash[:error] = t ".flash token bad"
        redirect_to :action => "new"
      end
    else
      head :bad_request
    end
  end
end
