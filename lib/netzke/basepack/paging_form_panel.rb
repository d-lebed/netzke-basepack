module Netzke
  module Basepack
    # A FormPanel with paging toolbar. Allows browsing and editing records one-by-one.
    #
    # == Configuration
    # Besides +Netzke::Basepack::FormPanel+ config options, accepts:
    # * +scope+ - specifies how the data should be filtered.
    #   When it's a symbol, it's used as a scope name.
    #   When it's a string, it's a SQL statement (passed directly to +ActiveRecord::Relation#where+).
    #   When it's a hash, it's a conditions hash (passed directly to +ActiveRecord::Relation#where+).
    #   When it's an array, it's expanded into an SQL statement with arguments (passed directly to +ActiveRecord::Relation#where+), e.g.:
    #
    #     :scope => ["id > ?", 100])
    #
    #   When it's a Proc, it's passed the model class, and is expected to return an ActiveRecord::Relation, e.g.:
    #
    #     :scope => { |rel| rel.where(:id.gt => 100).order(:created_at) }
    #
    # == ToDo
    # * Update the number of records after form submit
    class PagingFormPanel < FormPanel

      # override
      def record
        @record ||= get_relation.first
      end

      # Pass total records amount and the first record to the JS constructor
      def js_config
        super.merge({
          :total_records => total_records
        })
      end

      endpoint :get_data do |params|
        @record = get_relation(params).offset(params[:start].to_i).limit(1).first
        record_hash = @record && js_record_data
        {:records => record_hash && [record_hash] || [], :total => total_records(params)}
      end

      action :search do
        {
          :text => I18n.t('netzke.basepack.paging_form_panel.actions.search'),
          :tooltip => I18n.t('netzke.basepack.paging_form_panel.actions.search_tooltip'),
          :icon => :find,
          :select => true
        }
      end

      def configure_bbar(c)
        super
        c[:bbar] << :search.action
      end

      js_method :on_search, <<-JS
        function(el){
          if (this.searchWindow) {
            this.searchWindow.show();
          } else {
            this.loadComponent({name: 'search_form', callback: function(win){
              this.searchWindow = win;
              var currentConditionsString = this.getStore().baseParams.extra_conditions;
              if (currentConditionsString) {
                win.items.first().getForm().setValues(Ext.decode(currentConditionsString));
              }

              win.items.first().on('apply', function(){
                win.onSearch();
                return false; // do not propagate the 'apply' event
              }, this);

              win.on('hide', function(){
                var query = win.getQuery();
                if (win.closeRes == 'search'){
                  this.getStore().baseParams.query = Ext.encode(query);
                  this.getStore().load();
                }
                el.toggle(query.length > 0); // toggle based on the state
              }, this);
            }, scope: this});
          }
        }
      JS

      js_method :get_store, <<-JS
        function(){
          return this.store;
        }
      JS

      js_method :after_render, <<-JS
        function(){
          Netzke.classes.Basepack.PagingFormPanel.superclass.afterRender.call(this);

          new Ext.LoadMask(this.bwrap, Ext.apply(this.applyMask, {store: this.store}));
        }
      JS


      js_method :init_component, <<-JS
        function(){

          // Extract field names from items recursively. We have to do it before calling superclass.initComponent,
          // because we need to build the store for PagingToolbar that cannot be created after superclass.initComponent
          // Otherwise, the things would be simpler, because this.getForm().items would already has all the fields in one place for us
          this.fieldNames = [];
          this.extractFields(this.items);

          var store = new Ext.data.DirectStore({
            directFn: Netzke.providers[this.id].getData,
            root: 'records',
            fields: this.fieldNames.concat('_meta'),
            data: {records: [this.record], total: this.totalRecords}
          });

          store.on('load', function(st, r){
            if (r.length == 0) {
              this.getForm().reset();
            } else {
              this.setFormValues(r[0].data);
            }
          }, this);

          this.bbar = new Ext.PagingToolbar({
            beforePageText: "Record",
            store: store,
            pageSize: 1,
            items: ["-"].concat(this.bbar || [])
          });

          this.store = store;

          Netzke.classes.Basepack.PagingFormPanel.superclass.initComponent.call(this);
        }
      JS

      component :search_form do
        {
          :lazy_loading => true,
          :class_name => "Netzke::Basepack::SearchWindow",
          :model => config[:model]
        }
      end

      protected

        def total_records(params = {})
          @total_records ||= get_relation(params).count
        end

    end
  end
end
