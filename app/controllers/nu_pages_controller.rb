class NuPagesController < ApplicationController
  before_action :set_help, only: [:show, :edit, :update, :destroy]

  def about
  end

  def help
  end

end
