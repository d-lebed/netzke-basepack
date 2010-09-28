module Netzke
  class UserGrid < Component::GridPanel
    
    def config
      {
        :mode => :config,
        :model => "User",
        :title => "Users",
        :query => ["id < ?", 8],
        :columns => [:first_name, :last_name]
      }.deep_merge super
    end
  end
end